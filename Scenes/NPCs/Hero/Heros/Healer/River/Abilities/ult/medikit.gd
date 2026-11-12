extends Area2D
class_name MediKit

## River's Emergency Supply Drop (README): a crate falls onto the spot it was
## dropped at and, once landed, heals every hero who walks over it once.

@export var heal_amount: float = 30.0
@export var detection_radius: float = 50.0
@export var lifetime: float = 20.0
## Seconds the crate falls before it lands. Until then the kit heals no one:
## monitoring stays off (MediKit.tscn) and only the crate sprite moves, so its
## pickup area never sweeps the fall path.
@export var fall_time: float = 0.5
## How far above its landing spot the crate starts (presentation).
@export var fall_height: float = 100.0

var owner_entity: Node2D = null
## The supply drop copy that dropped it (presentation: its recipe colours the
## heal bursts).
var source_ability: AbilityBase = null
var healed_heroes: Array[Node2D] = []
## True once the crate is down (_land): from then on it heals.
var landed: bool = false
var _fading: bool = false

func _ready() -> void:
	# Everything above is set before add_child (RiverUltimateMediKit.execute),
	# so the trigger matches the drawn ring from the first frame.
	var collision_shape := $CollisionShape2D as CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = detection_radius

	# The crate, its leaf chute and their Drop animation are MediKit.tscn's;
	# _draw marks the pickup radius where it will land.
	queue_redraw()
	_play_fall()

	# area_entered / body_entered are wired in MediKit.tscn. Pausable timers:
	# nothing lands or expires under the match-result screen. A connection to a
	# freed kit is dropped with it.
	var tree := get_tree()
	tree.create_timer(fall_time, false).timeout.connect(_land)
	tree.create_timer(lifetime, false).timeout.connect(_fade_out)

## Presentation: the crate drops from fall_height onto the spot and the kit
## fades in (the chute's sway and drift are the Drop animation).
func _play_fall() -> void:
	var crate := get_node_or_null(^"Crate") as Node2D
	if crate:
		var rest: Vector2 = crate.position
		crate.position = rest + Vector2(0.0, -fall_height)
		create_tween().tween_property(crate, ^"position", rest, fall_time)
	modulate.a = 0.0
	create_tween().tween_property(self, ^"modulate:a", 1.0, minf(0.3, fall_time))

## The crate is down: heal the heroes already standing in the pickup radius,
## then every one who walks in.
func _land() -> void:
	if _fading:
		return
	landed = true
	monitoring = true
	# Presentation: the landing's dust, ring and leaves (AbilityVfx).
	EventBus.notify_ability_event(self, source_ability, FxEvents.KIT_LANDED, global_position, detection_radius)
	for entity in GameUtils.entities_in_circle(get_world_2d(), global_position, detection_radius,
			GameUtils.MASK_HEROES, false):
		_heal_hero(entity)

## The pickup radius: a dashed ink and heal ring at the telegraph alpha
## (VfxManager.TELEGRAPH_ALPHA), at most 3 px wide.
func _draw() -> void:
	var palette := UiPalette.get_default()
	var ink := Color(palette.ink, VfxManager.TELEGRAPH_ALPHA)
	var col := Color(palette.heal, VfxManager.TELEGRAPH_ALPHA)
	var dashes: int = 16
	var step: float = TAU / float(dashes)
	for i in dashes:
		var a0: float = step * float(i)
		draw_arc(Vector2.ZERO, detection_radius, a0, a0 + step * 0.55, 4, ink, 3.0)
		draw_arc(Vector2.ZERO, detection_radius, a0, a0 + step * 0.55, 4, col, 1.5)

func _on_area_entered(area: Area2D) -> void:
	_check_healing(area)

func _on_body_entered(body: Node2D) -> void:
	_check_healing(body)

func _check_healing(node: Node) -> void:
	var entity = node
	if node.has_method("get_parent"):
		entity = node.get_parent()
	if node.has_method("get_owner"):
		entity = node.get_owner()
	
	# Only heal heroes
	if entity and entity.is_in_group("Hero"):
		_heal_hero(entity)

## Heal `hero` once, after landing. Only a living HeroBase that is hurt uses
## the kit: Ted's pet (group Hero) has no HP to heal, and a hero at full HP
## walks over it without taking it from the ones who need it.
func _heal_hero(hero: Node2D) -> void:
	if not landed or _fading or not hero is HeroBase or healed_heroes.has(hero):
		return
	var hero_base := hero as HeroBase
	if not hero_base.is_alive() or hero_base.get_health() >= hero_base.get_max_health():
		return

	var before: float = hero_base.get_health()
	hero_base.heal(heal_amount)
	healed_heroes.append(hero)

	# Visual feedback
	_create_heal_effect(hero_base, hero_base.get_health() - before)

	_check_if_should_disappear()

## Presentation: the heal burst (AbilityVfx) and the "+N" (VfxManager).
func _create_heal_effect(hero: Node2D, healed: float) -> void:
	EventBus.notify_ability_event(hero, source_ability, FxEvents.KIT_PICKED, hero.global_position, healed)

## Fade once it has healed someone and no hero in its radius still needs it
## (hurt and not healed by it yet); otherwise it waits out its lifetime for
## the next hurt hero to walk over it.
func _check_if_should_disappear() -> void:
	if healed_heroes.is_empty():
		return
	for entity in GameUtils.entities_in_circle(get_world_2d(), global_position, detection_radius,
			GameUtils.MASK_HEROES, false):
		var hero := entity as HeroBase
		if hero and hero.is_alive() and not healed_heroes.has(hero) and hero.get_health() < hero.get_max_health():
			return
	_fade_out()

func _fade_out() -> void:
	if _fading:
		return
	_fading = true
	# Deferred: this can run inside an area_entered callback.
	set_deferred(&"monitoring", false)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

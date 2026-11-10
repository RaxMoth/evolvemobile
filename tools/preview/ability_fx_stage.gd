extends Node2D
## Staged ability effects of one hero for muted renders (not shipped, tools/):
## the hero, two allies and two Hogs, frozen (out of the TickScheduler), on a
## flat ground under the match's camera zoom and the match's Vfx (VfxManager,
## AbilityVfx and its ground layer, as in World.tscn). On a fixed timeline the
## hero's real ability copies fire through EventBus (the cast notifier plays
## the rig's move and the cast recipe, deal_damage the hit recipe and the
## numbers) and the moments that need a trigger (a mine going off, a heal, a
## supply drop picked up, Last Stand) are triggered by hand.
## With "monster=<id>" it stages a monster's full combo instead: the monster,
## Vlad, Irelia and two Hogs; its three abilities fire through EventBus on its
## own copies (the capstones switched on those copies: Trample, Echo Strike
## with Disorienting Dive, Brood Mother, Whirlwind, Concussive Axe, Call of the
## Herd, Unstoppable), and Rampage and Vampiric Rebirth's scatter and re-form
## are triggered by hand.
## Render muted on a copy of the project (hero = vlad | irelia | ted | river,
## monster = grount | nyxa | gorrak):
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30
##         --write-movie <dir>/f.png --quit-after 120 res://tools/preview/AbilityFxStage.tscn -- hero=vlad

const HEROES: Dictionary[String, String] = {
	"vlad": "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn",
	"irelia": "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn",
	"ted": "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn",
	"river": "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn",
}
## The allies standing by (healed, shielded, rallied).
const ALLIES: Dictionary[String, Array] = {
	"vlad": ["irelia", "ted"],
	"irelia": ["vlad", "ted"],
	"ted": ["vlad", "irelia"],
	"river": ["vlad", "irelia"],
}
const MONSTERS: Dictionary[String, String] = {
	"grount": "res://Scenes/NPCs/Monster/Grount/Grount.tscn",
	"nyxa": "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn",
	"gorrak": "res://Scenes/NPCs/Monster/Gorrak/Gorrak.tscn",
}
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
## Where the Hogs wait until everyone is frozen.
const FAR := Vector2(4000, 0)

## Which hero to stage; a "hero=<id>" user argument wins.
@export var hero_id: String = "vlad"
## Which monster to stage instead ("" = the hero); "monster=<id>" wins.
@export var monster_id: String = ""

var _hero: HeroBase = null
var _monster: MonsterBase = null
var _allies: Array[HeroBase] = []
var _foes: Array[Node2D] = []
var _t: float = 0.0
var _steps: Array[Array] = []
var _ready_to_play: bool = false

@onready var _ground: ColorRect = $Ground


func _ready() -> void:
	_ground.color = UiPalette.get_default().moss_dark
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("hero="):
			hero_id = arg.substr(5)
		elif arg.begins_with("monster="):
			monster_id = arg.substr(8)
	if not monster_id.is_empty():
		_stage_monster()
		return
	# Everyone spawns at once, the Hogs far off so nobody fights before the
	# freeze; then out of the TickScheduler, the Hogs walked into place.
	_hero = _spawn(HEROES[hero_id], Vector2(-70, 30)) as HeroBase
	_allies.append(_spawn(HEROES[ALLIES[hero_id][0]], Vector2(-130, -40)) as HeroBase)
	_allies.append(_spawn(HEROES[ALLIES[hero_id][1]], Vector2(-40, 75)) as HeroBase)
	_foes.append(_spawn(HOG, FAR))
	_foes.append(_spawn(HOG, FAR + Vector2(0, 100)))
	for _i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	var ticks := get_tree().root.get_node(^"TickScheduler")
	for e: Node2D in [_hero, _allies[0], _allies[1], _foes[0], _foes[1]]:
		ticks.unregister(e)
	_foes[0].global_position = Vector2(0, 20)
	_foes[1].global_position = Vector2(60, -40)
	_steps = _timeline()
	_ready_to_play = true


func _process(delta: float) -> void:
	if not _ready_to_play:
		return
	_t += delta
	while not _steps.is_empty() and _t >= float(_steps[0][0]):
		(_steps.pop_front()[1] as Callable).call()


## The monster, Vlad, Irelia and two Hogs, all spawned far apart (no AI
## tick sees a foe before the freeze), then walked into place.
func _stage_monster() -> void:
	_monster = _spawn(MONSTERS[monster_id], -FAR) as MonsterBase
	_hero = _spawn(HEROES["vlad"], FAR + Vector2(0, -600)) as HeroBase
	_allies.append(_spawn(HEROES["irelia"], FAR + Vector2(0, -1200)) as HeroBase)
	_foes.append(_spawn(HOG, FAR))
	_foes.append(_spawn(HOG, FAR + Vector2(0, 100)))
	for _i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	var ticks := get_tree().root.get_node(^"TickScheduler")
	for e: Node2D in [_monster, _hero, _allies[0], _foes[0], _foes[1]]:
		ticks.unregister(e)
	_monster.teleport_to(Vector2(-50, 40))
	_hero.teleport_to(Vector2(110, 20))
	_allies[0].teleport_to(Vector2(0, 110))
	_foes[0].global_position = Vector2(15, 55)
	_foes[1].global_position = Vector2(-150, -40)
	_steps = _monster_timeline()
	_ready_to_play = true


## Casts `ability` of the monster at `target` (facing it first): its gameplay
## with the monster's damage, then the notifier.
func _monster_cast(ability: AbilityBase, target: Node2D) -> void:
	if target != null:
		_monster.sprite.rotation = (target.global_position - _monster.global_position).angle()
	ability.execute(_monster, target, _monster.effective_ability_damage(ability))
	EventBus.notify_ability_cast(_monster, ability, target)


func _monster_timeline() -> Array[Array]:
	var m := _monster
	var vlad := _hero
	var irelia := _allies[0]
	var hog := _foes[0]
	match monster_id:
		"grount":
			var dash := m.ability_2 as BullRamDash
			dash.trample = true  # Trample's 70 px lane on this copy
			return [
				[0.3, _monster_cast.bind(m.ability_1, hog)],
				[0.9, _monster_cast.bind(dash, vlad)],
				[1.9, m.gain_xp.bind(200.0)],
				[2.4, _monster_cast.bind(m.ability_3, irelia)],
				[3.9, _rampage],
				[4.4, _monster_cast.bind(m.ability_1, hog)],
			]
		"nyxa":
			m.gain_xp(2000.0)
			m.gain_xp(2000.0)
			var swoop := m.ability_2 as BullRamDash
			swoop.double_pass = true  # Echo Strike on this copy
			swoop.stun_duration = 0.4  # Disorienting Dive
			var swarm := m.ability_3 as NightSwarm
			swarm.permanent_from_stage = 3  # Brood Mother
			swarm.apply_stage_stats(m.get_stage())
			return [
				[0.3, _monster_cast.bind(m.ability_1, vlad)],
				[0.8, _monster_cast.bind(swoop, vlad)],
				[2.0, _monster_cast.bind(swarm, null)],
				[3.3, _scatter],
				[4.1, _reform.bind(Vector2(-130, -60))],
			]
		"gorrak":
			var axe := m.ability_2 as ThrownAxe
			axe.stun_duration = 0.5  # Concussive Axe
			var stomp := m.ability_3 as BullGroundSlam
			stomp.recruit_radius = 250.0  # Call of the Herd
			var chop := m.ability_1 as BullFrontCleave
			return [
				[0.3, _monster_cast.bind(chop, hog)],
				[0.8, _monster_cast.bind(axe, vlad)],
				[2.1, _monster_cast.bind(stomp, irelia)],
				[3.1, _whirlwind.bind(chop, hog)],
				[3.7, _unstoppable],
				[4.4, _monster_cast.bind(chop, irelia)],
			]
	return []


## Rampage by hand: the cooldowns back and the heal it reports.
func _rampage() -> void:
	EventBus.notify_ability_event(_monster, _monster.passive_ability, FxEvents.RAMPAGE, _monster.global_position, 90.0)


## Vampiric Rebirth's scatter by hand: the faded body and the bat burst.
func _scatter() -> void:
	_monster._fade_visual(MonsterBase.SCATTER_ALPHA)
	EventBus.notify_ability_event(_monster, _monster.passive_ability, FxEvents.SCATTERED, _monster.global_position)


## The re-form by hand: she jumps to `at`, the bats fly there from her spot.
func _reform(at: Vector2) -> void:
	var from := _monster.global_position
	_monster.teleport_to(at)
	_monster._fade_visual(1.0)
	EventBus.notify_ability_event(_monster, _monster.passive_ability, FxEvents.REFORMED, from)


## Whirlwind on this copy: the chop turns into a full circle.
func _whirlwind(chop: BullFrontCleave, target: Node2D) -> void:
	chop.cone_angle = BullFrontCleave.FULL_CIRCLE
	_monster_cast(chop, target)
	chop.apply_stage_stats(_monster.get_stage())


## Unstoppable on this monster: Irelia's Monster Taunt bounces off him.
func _unstoppable() -> void:
	_monster._meta_cc_immune = true
	_system(_allies[0]).ultimate_ability.execute(_allies[0])
	EventBus.notify_ability_cast(_allies[0], _system(_allies[0]).ultimate_ability, null)


## A character at `at`; a hero never casts on its own here (the timeline does).
func _spawn(path: String, at: Vector2) -> Node2D:
	var e := (load(path) as PackedScene).instantiate() as Node2D
	e.position = at
	if e is HeroBase:
		(e as HeroBase).auto_use_active = false
		(e as HeroBase).auto_use_ultimate = false
	add_child(e)
	return e


func _system(h: HeroBase) -> AbilitySystem:
	return h.get_node(^"AbilitySystem") as AbilitySystem


## Casts `ability` of `caster` at `target`: its gameplay, then the notifier.
func _cast(caster: HeroBase, ability: AbilityBase, target: Node2D) -> void:
	ability.execute(caster, target)
	EventBus.notify_ability_cast(caster, ability, target)


## A basic attack's hit: the notifier (the rig's swing) and the packet.
func _strike(caster: HeroBase, target: Node2D) -> void:
	var basic := _system(caster).basic_attack
	EventBus.notify_ability_cast(caster, basic, target)
	EventBus.deal_damage(caster, target, 6.0, basic)


func _hurt(h: HeroBase, amount: float) -> void:
	(h.get_node(^"HeroStats") as HeroStatsComponent).take_damage(amount)


func _timeline() -> Array[Array]:
	var s := _system(_hero)
	var foe := _foes[0]
	match hero_id:
		"vlad":
			return [
				[0.3, _strike.bind(_hero, foe)],
				[0.9, _strike.bind(_hero, foe)],
				[1.3, _cast.bind(_hero, s.active_ability, null)],
				[2.0, _blow_mines],
				[2.6, _cast.bind(_hero, s.ultimate_ability, null)],
			]
		"irelia":
			return [
				[0.3, _strike.bind(_hero, foe)],
				[0.9, _cast.bind(_hero, s.active_ability, null)],
				[1.5, EventBus.deal_damage.bind(foe, _allies[0], 6.0, null, 0)],
				[2.0, _cast.bind(_hero, s.ultimate_ability, null)],
				[2.8, _last_stand],
			]
		"ted":
			(s.active_ability as TedActiveRally).aura_radius = 200.0  # War Cry on this copy
			return [
				[0.3, _strike.bind(_hero, foe)],
				[0.9, _cast.bind(_hero, s.active_ability, null)],
				[1.7, _cast.bind(_hero, s.ultimate_ability, foe)],
			]
		"river":
			(s.basic_attack as RiverBasicAttack).extra_heal_targets = 1  # Chain Heal on this copy
			return [
				[0.3, _strike.bind(_hero, foe)],
				[0.6, _hurt.bind(_allies[0], 40.0)],
				[0.6, _hurt.bind(_allies[1], 40.0)],
				[0.9, _cast.bind(_hero, s.active_ability, null)],
				[1.4, _cast.bind(_hero, s.basic_attack, _allies[0])],
				[2.2, _cast.bind(_hero, s.ultimate_ability, null)],
				[3.0, _pick_kits],
			]
	return []


func _blow_mines() -> void:
	for n in get_children():
		if n is Mine:
			(n as Mine)._explode()


func _last_stand() -> void:
	var regen := _system(_hero).passive_ability
	EventBus.notify_ability_event(_hero, regen, FxEvents.LAST_STAND, _hero.global_position, 2.0)


func _pick_kits() -> void:
	for n in get_children():
		if n is MediKit:
			(n as MediKit)._heal_hero(_allies[0])

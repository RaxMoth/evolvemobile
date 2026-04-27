extends PanelContainer
class_name HeroPanel

## HeroPanel - one click-able UI card representing a single hero.
##
## Bound to a specific hero via `bind_to_hero()`. Owns:
##  - portrait, name, HP bar, 4 ability icons + cooldown shaders
##  - click-to-select interaction (emits `selected` signal)
##  - active/hover visual states
##
## HeroContainer instantiates one HeroPanel per hero in the scene, replacing
## the old pattern of 4 hardcoded panel duplicates.

signal selected(hero: Node)

@onready var name_label: Label = $VBoxContainer/HeroName
@onready var portrait: TextureRect = $VBoxContainer/HeroPortrait
@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var ability_container: HBoxContainer = $VBoxContainer/AbilityContainer
@onready var passive_icon: TextureRect = $VBoxContainer/AbilityContainer/Passive
@onready var active_icon: TextureRect = $VBoxContainer/AbilityContainer/Active
@onready var basic_icon: TextureRect = $VBoxContainer/AbilityContainer/BasicAttack
@onready var ult_icon: TextureRect = $VBoxContainer/AbilityContainer/Ultimate

var hero: Node = null
var _is_active: bool = false
var _is_hovered: bool = false

# Per-ability cooldown trackers keyed by ability_type.
var _cooldown_trackers: Dictionary = {}

# How fast the hover/active visual fades. Higher = snappier.
const VISUAL_LERP_SPEED: float = 12.0


func _ready() -> void:
	# PanelContainer needs `mouse_filter = MOUSE_FILTER_STOP` to receive clicks.
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_visual_state(true)  # start in idle state


# ============================================
# Public API
# ============================================

func bind_to_hero(new_hero: Node) -> void:
	"""Wire this panel to a hero. Pulls portrait/name/HP/abilities and hooks
	the relevant signals so the panel updates live."""
	hero = new_hero
	if not is_instance_valid(hero):
		return

	var stats = hero.get_node_or_null("HeroStats") as HeroStatsComponent
	if not stats or not stats.base_stats:
		push_warning("HeroPanel: %s has no HeroStats / base_stats" % hero.name)
		return

	if name_label:
		name_label.text = stats.base_stats.hero_name
	if portrait and stats.base_stats.portrait:
		portrait.texture = stats.base_stats.portrait
	if health_bar:
		health_bar.max_value = stats.get_max_health()
		health_bar.value = stats.get_current_health()
		_update_health_color(stats.get_current_health(), stats.get_max_health())

	# Live-update HP on damage / heal.
	if not stats.health_changed.is_connected(_on_health_changed):
		stats.health_changed.connect(_on_health_changed)

	_setup_abilities()


func set_active(active: bool) -> void:
	"""Mark this panel as the camera's current focus. Triggers a visual
	highlight (modulate brighten + slight scale). Idempotent."""
	if _is_active == active:
		return
	_is_active = active


# ============================================
# Visual state
# ============================================

func _process(delta: float) -> void:
	# Lerp the visual response toward the desired state. Cheap, smooth.
	_update_visual_state(false, delta)


func _update_visual_state(snap: bool, delta: float = 0.0) -> void:
	# Combine active + hover into a single brightness/scale target.
	var target_brightness: float = 0.7  # idle is dimmed
	var target_scale: float = 1.0
	if _is_active:
		target_brightness = 1.0
		target_scale = 1.05
	elif _is_hovered:
		target_brightness = 0.9
		target_scale = 1.02

	if snap or delta == 0.0:
		modulate = Color(target_brightness, target_brightness, target_brightness)
		scale = Vector2(target_scale, target_scale)
		return

	var t: float = clamp(VISUAL_LERP_SPEED * delta, 0.0, 1.0)
	modulate = modulate.lerp(Color(target_brightness, target_brightness, target_brightness), t)
	scale = scale.lerp(Vector2(target_scale, target_scale), t)


# ============================================
# Input
# ============================================

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(hero):
				selected.emit(hero)


func _on_mouse_entered() -> void:
	_is_hovered = true


func _on_mouse_exited() -> void:
	_is_hovered = false


# ============================================
# Hero data wiring
# ============================================

func _on_health_changed(current: float, max_hp: float) -> void:
	if not is_instance_valid(health_bar):
		return
	health_bar.max_value = max_hp
	health_bar.value = current
	_update_health_color(current, max_hp)


func _update_health_color(current: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		return
	var pct: float = current / max_hp
	if pct > 0.5:
		health_bar.modulate = Color.GREEN
	elif pct > 0.25:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.RED


func _setup_abilities() -> void:
	var ability_system = hero.get_node_or_null("AbilitySystem") as AbilitySystem
	if not ability_system:
		return

	if passive_icon and ability_system.passive_ability:
		passive_icon.texture = ability_system.passive_ability.icon
	if active_icon and ability_system.active_ability:
		active_icon.texture = ability_system.active_ability.icon
		_setup_cooldown_shader(active_icon)
	if basic_icon and ability_system.basic_attack:
		basic_icon.texture = ability_system.basic_attack.icon
		_setup_cooldown_shader(basic_icon)
	if ult_icon and ability_system.ultimate_ability:
		ult_icon.texture = ability_system.ultimate_ability.icon
		_setup_cooldown_shader(ult_icon)

	if not ability_system.ability_used.is_connected(_on_ability_used):
		ability_system.ability_used.connect(_on_ability_used)


func _setup_cooldown_shader(icon_node: TextureRect) -> void:
	var shader = load("res://Scenes/UI/HeroContainer/ability_cooldown.gdshader")
	if not shader:
		return
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("progress", 1.0)
	shader_material.set_shader_parameter("overlay_color", Color(0, 0, 0, 0.7))
	icon_node.material = shader_material


func _on_ability_used(used_ability: AbilityBase) -> void:
	if used_ability.ability_type == AbilityBase.AbilityType.PASSIVE:
		return
	var icon: TextureRect = _icon_for_type(used_ability.ability_type)
	if icon:
		_animate_cooldown(icon, used_ability.cooldown)


func _icon_for_type(t: AbilityBase.AbilityType) -> TextureRect:
	match t:
		AbilityBase.AbilityType.ACTIVE: return active_icon
		AbilityBase.AbilityType.BASIC_ATTACK: return basic_icon
		AbilityBase.AbilityType.ULTIMATE: return ult_icon
	return null


func _animate_cooldown(icon_node: TextureRect, cooldown_duration: float) -> void:
	if not icon_node.material or cooldown_duration <= 0.0:
		return
	var tracker_id := icon_node.get_instance_id()
	_cooldown_trackers[tracker_id] = true

	var elapsed: float = 0.0
	while elapsed < cooldown_duration:
		if not is_instance_valid(icon_node) or not _cooldown_trackers.get(tracker_id, false):
			break
		elapsed += get_process_delta_time()
		var progress: float = elapsed / cooldown_duration
		icon_node.material.set_shader_parameter("progress", progress)
		await get_tree().process_frame

	if is_instance_valid(icon_node):
		icon_node.material.set_shader_parameter("progress", 1.0)
	_cooldown_trackers.erase(tracker_id)

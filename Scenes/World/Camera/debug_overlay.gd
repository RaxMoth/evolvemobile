extends Node2D
class_name DebugOverlay

## DebugOverlay — visual replacement for print() debugging.
##
## Toggled by F3. When active, draws over the world:
##   • Active hero ring (cyan)
##   • Each entity's target line (yellow)
##   • Each entity's HP bar mini-icon (red/green) above the head
##   • Each entity's name + state-chart state label
##   • Top-3 threat sources for each ally on the heroes team
##
## Designed to be cheap when off: when invisible, _draw and _process bail
## immediately. When active, redraws at a throttled rate (default 10 Hz)
## rather than every frame.
##
## Place this as a child of the camera's CanvasLayer so it stays at a
## consistent screen-space position, but its `_draw` uses world coords by
## reading the camera transform. (Actually we keep this as a Node2D inside
## the CanvasLayer-free world tree so transforms are simple.)

# ============================================
# Tunables
# ============================================

@export var entity_label_color: Color = Color(0.9, 0.9, 0.9, 0.95)
@export var target_line_color: Color = Color(1.0, 1.0, 0.3, 0.7)
@export var active_hero_ring_color: Color = Color(0.2, 0.9, 1.0, 0.9)
@export var aabb_color: Color = Color(0.4, 0.8, 1.0, 0.5)
@export var threat_color: Color = Color(1.0, 0.4, 0.4, 0.9)
@export_range(1.0, 60.0) var refresh_rate_hz: float = 10.0

# ============================================
# State
# ============================================

var _active: bool = false
var _refresh_timer: float = 0.0
var _font: Font = null
var _hud_label: Label = null

# Cached snapshots for cheap _draw — refreshed at refresh_rate_hz.
class EntitySnapshot:
	var entity: WeakRef
	var pos: Vector2
	var name_str: String
	var state_str: String
	var hp_pct: float
	var target_pos: Vector2
	var has_target: bool
	var is_active_hero: bool
	var top_threats: Array  # Array of {enemy: Node, score: float}

var _snapshots: Array[EntitySnapshot] = []


func _ready() -> void:
	_font = ThemeDB.fallback_font
	visible = false
	# Lightweight HUD: a screen-space label hosted on a CanvasLayer so it
	# follows the viewport rather than the world. The Label is created on
	# demand to avoid forcing scene-tree edits.
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "DebugHUDLayer"
	hud_layer.layer = 50  # above world, below regular UI
	add_child(hud_layer)
	_hud_label = Label.new()
	_hud_label.text = ""
	_hud_label.position = Vector2(8, 8)
	_hud_label.add_theme_color_override("font_color", Color.WHITE)
	_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_label.add_theme_constant_override("outline_size", 4)
	hud_layer.add_child(_hud_label)


func set_active(active: bool) -> void:
	_active = active
	if not active:
		_snapshots.clear()
		queue_redraw()
		if _hud_label:
			_hud_label.text = ""


func _process(delta: float) -> void:
	if not _active:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 1.0 / max(1.0, refresh_rate_hz)
		_collect_snapshots()
		queue_redraw()


# ============================================
# Snapshot collection (read once per refresh, draw cheaply many times)
# ============================================

func _collect_snapshots() -> void:
	_snapshots.clear()

	var active_hero: Node = _get_active_hero_from_camera()
	var heroes_team: TeamBlackboard = TeamRegistry.get_team(TeamRegistry.HEROES)

	# Walk both teams' members. We don't iterate scene groups — the team
	# blackboard is the canonical source of "live entities" and is much
	# cheaper than a scene-tree walk.
	var all: Array = []
	if heroes_team:
		all.append_array(heroes_team.members)
	var enemies_team := TeamRegistry.get_team(TeamRegistry.ENEMIES)
	if enemies_team:
		all.append_array(enemies_team.members)

	for entity in all:
		if not is_instance_valid(entity) or not (entity is Node2D):
			continue
		var snap := EntitySnapshot.new()
		snap.entity = weakref(entity)
		snap.pos = (entity as Node2D).global_position
		snap.name_str = String(entity.name)
		snap.state_str = _state_name_of(entity)
		snap.hp_pct = _hp_pct_of(entity)
		snap.is_active_hero = (entity == active_hero)

		# Target line (only for entities with a "target_entity" property).
		if "target_entity" in entity:
			var t = entity.get("target_entity")
			if is_instance_valid(t) and t is Node2D:
				snap.has_target = true
				snap.target_pos = (t as Node2D).global_position

		# Top 3 threats — only for the active hero, to keep the screen clean.
		if snap.is_active_hero and heroes_team:
			snap.top_threats = _top_threats_for(heroes_team, entity, 3)

		_snapshots.append(snap)

	# Update HUD label (top-left status).
	_update_hud_label(active_hero, heroes_team, enemies_team)


func _state_name_of(entity: Node) -> String:
	# Read the active state name from the godot_state_charts addon.
	# Each entity has a StateChart node accessible via %StateChart.
	var chart: Node = entity.get_node_or_null("%StateChart")
	if chart == null:
		return ""
	var compound := chart.get_child(0) if chart.get_child_count() > 0 else null
	if compound == null:
		return ""
	# Walk the compound state's children to find the active atomic state.
	for child in compound.get_children():
		if "active" in child and child.get("active"):
			return String(child.name)
	return ""


func _hp_pct_of(entity: Node) -> float:
	if not entity.has_method("get_health"):
		return -1.0
	var current: float = entity.call("get_health")
	var max_hp: float = 100.0
	if "max_health" in entity:
		var v = entity.get("max_health")
		if v is float or v is int:
			max_hp = float(v)
	if max_hp <= 0.0:
		return -1.0
	return clamp(current / max_hp, 0.0, 1.0)


func _top_threats_for(team: TeamBlackboard, ally: Node, k: int) -> Array:
	var threats: Dictionary = team.get_threat_on(ally)
	var entries: Array = []
	for enemy in threats.keys():
		if is_instance_valid(enemy):
			entries.append({"enemy": enemy, "score": float(threats[enemy])})
	entries.sort_custom(func(a, b): return a.score > b.score)
	if entries.size() > k:
		entries.resize(k)
	return entries


func _get_active_hero_from_camera() -> Node:
	# The camera owns the hero UI; ask it which hero is selected.
	var cam: Node = get_parent()
	while cam and not (cam is GameCamera):
		cam = cam.get_parent()
	if cam == null:
		return null
	var ui: HeroContainer = (cam as GameCamera).hero_ui
	return ui.active_hero if ui else null


# ============================================
# Drawing
# ============================================

func _draw() -> void:
	if not _active:
		return
	for snap in _snapshots:
		_draw_entity(snap)


func _draw_entity(snap: EntitySnapshot) -> void:
	# Local-space conversion: this Node2D is at the world origin (no transform
	# of its own), so global positions are the right local coords for _draw.
	# (As long as we don't move the DebugOverlay node in the scene.)
	var p: Vector2 = snap.pos

	# Active-hero ring.
	if snap.is_active_hero:
		draw_arc(p, 32.0, 0.0, TAU, 32, active_hero_ring_color, 2.5)

	# Name + state label, slightly above the entity.
	if _font:
		var label: String = snap.name_str
		if not snap.state_str.is_empty():
			label += " : " + snap.state_str
		draw_string(_font, p + Vector2(-30, -36), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, entity_label_color)

	# Mini HP bar above the entity (only when we know HP).
	if snap.hp_pct >= 0.0:
		var bar_w: float = 28.0
		var bar_h: float = 3.0
		var bar_origin: Vector2 = p + Vector2(-bar_w * 0.5, -22)
		draw_rect(Rect2(bar_origin, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.5))
		var fill_color: Color = Color.GREEN.lerp(Color.RED, 1.0 - snap.hp_pct)
		draw_rect(Rect2(bar_origin, Vector2(bar_w * snap.hp_pct, bar_h)), fill_color)

	# Target line.
	if snap.has_target:
		draw_line(p, snap.target_pos, target_line_color, 1.5)
		draw_circle(snap.target_pos, 4.0, target_line_color)

	# Threat tags — only on active hero (avoids visual noise).
	if snap.is_active_hero and snap.top_threats.size() > 0 and _font:
		for i in snap.top_threats.size():
			var entry: Dictionary = snap.top_threats[i]
			var enemy = entry["enemy"]
			if not is_instance_valid(enemy) or not (enemy is Node2D):
				continue
			var ep: Vector2 = (enemy as Node2D).global_position
			# Connector line + threat score.
			draw_line(p, ep, threat_color, 1.0)
			draw_string(_font, ep + Vector2(8, -4), "T:%d" % int(entry["score"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, threat_color)


# ============================================
# HUD label (top-left counters)
# ============================================

func _update_hud_label(active_hero: Node, heroes_team: TeamBlackboard, enemies_team: TeamBlackboard) -> void:
	if not _hud_label:
		return
	var lines: Array[String] = []
	lines.append("[F3] Debug Overlay  ON")
	if heroes_team:
		lines.append("Heroes alive: %d" % heroes_team.members.size())
	if enemies_team:
		lines.append("Enemies live: %d" % enemies_team.members.size())
	if active_hero and is_instance_valid(active_hero):
		lines.append("Camera focus: %s" % active_hero.name)
		if "target_entity" in active_hero:
			var t = active_hero.get("target_entity")
			if is_instance_valid(t):
				lines.append("  → targeting: %s" % t.name)
	_hud_label.text = "\n".join(lines)

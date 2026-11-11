class_name EntityHud
extends Node2D

## The in-world HUD group of one character: the "Hud" node of
## NPCBaseClass.tscn (the HP bar and, on heroes and the monster, the level
## pill) and of TedsPet.tscn (the fox's bar). EntityBase counter-scales it, so
## it keeps its pixel size on a grown monster. It draws one z step above the
## bodies (z_index 1, scene-side): a bar is never hidden behind a character
## standing in front of its owner.
##
## It keeps stacked characters readable. Four heroes and the fox on one spot
## used to draw their bars and pills on top of each other. A hud with `stacks`
## on (HeroBaseClass.tscn, monster_base_class.tscn, TedsPet.tscn; mobs leave
## it off and never process) rises above every hud it would overlap that
## ranks before it, a row at a time, and eases back down once it is clear. The
## rank is `stack_priority` (the monster's 1: its bar, the one the fight is
## about, never moves for a hero's) and then the order the huds came on
## screen, which is fixed while they stay there, so the bars never swap places
## while the characters mill around. VfxManager starts a character's damage
## numbers above this node, so they spread with the bars.
##
## Awake only while the character's ScreenNotifier reports it on screen (wired
## scene-side, like the Rig). Presentation only: it writes its own position.y
## and nothing else, and reads only the other huds.

## World px left between two stacked huds.
const GAP := 2.0
## World px a second a hud rises or sinks.
const SPEED := 160.0

## Bar and pill in this node's space (px): the area kept clear of other huds.
@export var footprint: Rect2 = Rect2(-25, -6, 75, 18)
## Rise above the huds this one would overlap (heroes, the fox, the monster).
@export var stacks: bool = false
## A hud only rises above huds of a higher priority and above the ones of its
## own that came on screen before it.
@export var stack_priority: int = 0

## The stacking huds on screen, in the order they came on.
static var _stack: Array[EntityHud] = []

## The scene's position.y: where the hud sits when nothing is in its way.
var _rest_y := 0.0
## World px the hud is raised above its rest position right now.
var _lift := 0.0


func _ready() -> void:
	_rest_y = position.y
	# Asleep until the notifier reports the character on screen.
	set_process(false)


func _exit_tree() -> void:
	_on_screen_exited()


func _on_screen_entered() -> void:
	if not stacks or _stack.has(self):
		return
	_stack.append(self)
	set_process(true)


func _on_screen_exited() -> void:
	_stack.erase(self)
	set_process(false)
	if _lift != 0.0:
		_lift = 0.0
		position.y = _rest_y


func _process(delta: float) -> void:
	_lift = move_toward(_lift, wanted_lift(), SPEED * delta)
	# In the parent's units: the character's scale is counter-scaled out of
	# this node, not out of its position (a grown monster mid-tween).
	var y := _rest_y - _lift / maxf(absf(_parent_scale_y()), 0.01)
	if y != position.y:
		position.y = y


## World px this hud is raised right now.
func lift() -> float:
	return _lift


## The area this hud covers right now, in world px.
func world_rect() -> Rect2:
	return Rect2(global_position + footprint.position, footprint.size)


## The lift that clears every hud that ranks before this one: each pass only
## raises it, so it ends after at most one pass per hud.
func wanted_lift() -> float:
	var rest := Rect2(global_position + Vector2(0.0, _lift) + footprint.position, footprint.size)
	var up := 0.0
	var moved := true
	while moved:
		moved = false
		var came_first := true
		for other in _stack:
			if other == self:
				came_first = false
				continue
			if other.stack_priority < stack_priority or (other.stack_priority == stack_priority and not came_first):
				continue
			var theirs := other.world_rect().grow(GAP)
			if not theirs.intersects(Rect2(rest.position - Vector2(0.0, up), rest.size)):
				continue
			var clear := rest.end.y - theirs.position.y
			if clear > up + 0.01:
				up = clear
				moved = true
	return up


func _parent_scale_y() -> float:
	var parent := get_parent() as Node2D
	return parent.global_scale.y if parent != null else 1.0

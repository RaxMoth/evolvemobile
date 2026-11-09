class_name MonsterSlot
extends Node

## Spawns this match's monster (GameManager.selected_monster_id, resolved
## through the roster) as its only child.
##
## It does so in _enter_tree on purpose: World.tscn used to instance Grount at
## this very index, so the monster entered the tree (EntityRegistry,
## TickScheduler.register -> one global randf()) during the scene's enter pass,
## BEFORE Spawns._ready shuffled the camps. Adding the child here keeps that
## order exactly (its _ready still runs in the normal bottom-up pass, because
## this node is not ready yet), so swapping the hard-wired instance for the
## slot leaves tools/sim_trace.sh byte-identical. Spawning from World._ready
## instead would move the draw behind the camp shuffle and change every match.
##
## A plain Node (like "Heros"): the monster's position is its global position.

@export var roster: Roster
## Scene position of the old Grount instance; world.gd moves the monster to a
## random reachable point of monster_spawn_zone once navigation is ready.
@export var spawn_position: Vector2 = Vector2(4509, 1794)

var monster: MonsterBase = null


func _enter_tree() -> void:
	if monster != null or roster == null:
		return
	var def := roster.resolve_monster(GameManager.selected_monster_id)
	var scene: PackedScene = def.scene() if def != null else null
	if scene == null:
		push_error("MonsterSlot: no monster scene for '%s'" % GameManager.selected_monster_id)
		return
	monster = scene.instantiate() as MonsterBase
	monster.position = spawn_position
	add_child(monster)

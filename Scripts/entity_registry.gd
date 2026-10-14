extends Node

## EntityRegistry — cached faction lists so hot paths never call
## get_tree().get_nodes_in_group() (a full scene-tree walk) per frame.
##
## Entities register from _enter_tree and unregister from _exit_tree
## (EntityBase and TedsPet), so anything removed from the tree — including a
## pooled mob — drops out of every list automatically. Classification mirrors
## TeamRegistry.team_name_of / GameUtils.can_entity_target:
##   heroes    — HeroBase only (HUD, match census, LOD anchors)
##   hero_side — everything in group "Hero" (heroes + pets). This is the set
##               the old group scans returned: spawn activation, boids, fog.
##   mobs      — "Enemy" but not "Monster" (MobBase)
##   monsters  — "Monster"
##   enemies   — mobs + monsters ("Enemy")
## Lists are plain arrays; callers iterate them directly and must still
## is_instance_valid() each element (a node can be freed mid-frame before its
## _exit_tree ran for the iterating caller).

var heroes: Array[Node2D] = []
var hero_side: Array[Node2D] = []
var mobs: Array[Node2D] = []
var monsters: Array[Node2D] = []
var enemies: Array[Node2D] = []

## Cached get_first_node_in_group() results (FogOfWar, HeroExplorationController…).
## Re-fetched when the cached node was freed or left the tree (scene reload).
var _singletons: Dictionary = {}


# ============================================
# Registration
# ============================================

func register(e: Node2D) -> void:
	if e == null:
		return
	if e.is_in_group("Hero"):
		_add(hero_side, e)
		if e is HeroBase:
			_add(heroes, e)
	elif e.is_in_group("Monster"):
		_add(monsters, e)
		_add(enemies, e)
	elif e.is_in_group("Enemy"):
		_add(mobs, e)
		_add(enemies, e)


func unregister(e: Node2D) -> void:
	heroes.erase(e)
	hero_side.erase(e)
	mobs.erase(e)
	monsters.erase(e)
	enemies.erase(e)


static func _add(list: Array[Node2D], e: Node2D) -> void:
	if not list.has(e):
		list.append(e)


# ============================================
# Queries (all distance math is squared — no sqrt)
# ============================================

## Lists this attacker may target. Mirrors GameUtils.can_entity_target.
## Returns a NEW array; prefer the raw lists in per-frame code.
func targets_for(attacker: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if attacker.is_in_group("Monster"):
		out.append_array(hero_side)
		out.append_array(mobs)
	elif attacker.is_in_group("Enemy"):
		out.append_array(hero_side)
		out.append_array(monsters)
	elif attacker.is_in_group("Hero"):
		out.append_array(enemies)
	return out


func is_entity_alive(e: Node) -> bool:
	if e is EntityBase:
		return (e as EntityBase).is_alive()
	if e.has_method("is_alive"):
		return bool(e.call("is_alive"))
	return true


func nearest(list: Array[Node2D], pos: Vector2, max_dist: float = INF, alive_only: bool = true) -> Node2D:
	var best: Node2D = null
	var best_sq: float = INF if max_dist == INF else max_dist * max_dist
	for e in list:
		if not is_instance_valid(e):
			continue
		if alive_only and not is_entity_alive(e):
			continue
		var d_sq := pos.distance_squared_to(e.global_position)
		if d_sq < best_sq:
			best_sq = d_sq
			best = e
	return best


## Count members of `list` within `radius` of `pos`. `stop_at` > 0 returns
## early once that many were found (cheap "at least N" checks).
func count_within(list: Array[Node2D], pos: Vector2, radius: float, stop_at: int = -1, alive_only: bool = true) -> int:
	var r_sq := radius * radius
	var n := 0
	for e in list:
		if not is_instance_valid(e):
			continue
		if alive_only and not is_entity_alive(e):
			continue
		if pos.distance_squared_to(e.global_position) <= r_sq:
			n += 1
			if stop_at > 0 and n >= stop_at:
				return n
	return n


## Squared distance from `pos` to the closest "action anchor" (any hero-side
## entity or monster). TickScheduler buckets AI LOD by this, not by camera
## distance, so mobs fighting an off-screen hero keep a high tick rate.
func nearest_anchor_dist_sq(pos: Vector2) -> float:
	var best := INF
	for e in hero_side:
		if is_instance_valid(e):
			best = minf(best, pos.distance_squared_to(e.global_position))
	for e in monsters:
		if is_instance_valid(e):
			best = minf(best, pos.distance_squared_to(e.global_position))
	return best


func first_monster() -> Node2D:
	for m in monsters:
		if is_instance_valid(m):
			return m
	return null


## Cached get_first_node_in_group(). Use for true singletons such as
## &"FogOfWar" and &"HeroExplorationController".
func singleton(group: StringName) -> Node:
	var cached: Node = _singletons.get(group, null)
	if is_instance_valid(cached) and cached.is_inside_tree():
		return cached
	var found := get_tree().get_first_node_in_group(group)
	if found:
		_singletons[group] = found
	else:
		_singletons.erase(group)
	return found

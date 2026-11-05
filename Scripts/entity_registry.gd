extends Node

## EntityRegistry — cached faction lists so hot paths never call
## get_tree().get_nodes_in_group() (a full scene-tree walk) per frame.
##
## Entities register from _enter_tree and unregister from _exit_tree
## (EntityBase and TedsPet), so anything removed from the tree — including a
## pooled mob — drops out of every list automatically. Classification is the
## GameUtils.Faction the caller passes (EntityBase.faction, cached in its
## _enter_tree; the pet passes GameUtils.faction_of(self)):
##   heroes    — HeroBase only (HUD, match census, LOD anchors)
##   hero_side — every HERO (heroes + pets). This is the set the old group
##               scans returned: spawn activation, boids, fog.
##   mobs      — MOB (MobBase)
##   monsters  — MONSTER
##   enemies   — mobs + monsters, in registration order
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

func register(e: Node2D, faction: GameUtils.Faction) -> void:
	if e == null:
		return
	match faction:
		GameUtils.Faction.HERO:
			_add(hero_side, e)
			if e is HeroBase:
				_add(heroes, e)
		GameUtils.Faction.MONSTER:
			_add(monsters, e)
			_add(enemies, e)
		GameUtils.Faction.MOB:
			_add(mobs, e)
			_add(enemies, e)


## `faction` must be the value register() got, so only its lists are scanned.
func unregister(e: Node2D, faction: GameUtils.Faction) -> void:
	match faction:
		GameUtils.Faction.HERO:
			hero_side.erase(e)
			if e is HeroBase:
				heroes.erase(e)
		GameUtils.Faction.MONSTER:
			monsters.erase(e)
			enemies.erase(e)
		GameUtils.Faction.MOB:
			mobs.erase(e)
			enemies.erase(e)


static func _add(list: Array[Node2D], e: Node2D) -> void:
	if not list.has(e):
		list.append(e)


# ============================================
# Queries (all distance math is squared — no sqrt)
# ============================================

## Lists this attacker may target. Mirrors GameUtils.CAN_HIT.
## Returns a NEW array; prefer the raw lists in per-frame code.
func targets_for(attacker: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	match GameUtils.cached_faction_of(attacker):
		GameUtils.Faction.MONSTER:
			out.append_array(hero_side)
			out.append_array(mobs)
		GameUtils.Faction.MOB:
			out.append_array(hero_side)
			out.append_array(monsters)
		GameUtils.Faction.HERO:
			out.append_array(enemies)
	return out


func is_entity_alive(e: Node) -> bool:
	if e is EntityBase:
		return (e as EntityBase).is_alive()
	# Ted's pet: in hero_side but not an EntityBase (teds_pet.gd has no class_name).
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
	# Read as Variant first: a typed assignment of a freed instance (scene reload)
	# raises and would abort before the cache could refresh.
	var cached: Variant = _singletons.get(group)
	if is_instance_valid(cached) and (cached as Node).is_inside_tree():
		return cached as Node
	var found := get_tree().get_first_node_in_group(group)
	if found:
		_singletons[group] = found
	else:
		_singletons.erase(group)
	return found

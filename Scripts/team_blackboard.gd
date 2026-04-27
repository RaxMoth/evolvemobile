class_name TeamBlackboard
extends RefCounted

## TeamBlackboard - shared knowledge for one faction (e.g. heroes, enemies).
##
## Holds:
##   - Live members of the team
##   - Threat table: per ally, who has been hitting them
##   - Optional focus_target (the team's "kill this" call)
##
## Brains read this to make coordinated decisions instead of each entity
## scoring targets in isolation. Owned by TeamRegistry.

var team_name: StringName = &""
var members: Array[Node] = []

# Threat: members[i] -> Dictionary { enemy: Node -> score: float }
# Bumped on EventBus.damage_applied via TeamRegistry; decays over time.
var threat: Dictionary = {}

# Optional team-wide focus target. When set, brains may prefer this over
# their own local scoring. Cleared when target dies / leaves combat.
var focus_target: Node = null


# ============================================
# Membership
# ============================================

func add_member(entity: Node) -> void:
	if entity == null or members.has(entity):
		return
	members.append(entity)
	threat[entity] = {}

func remove_member(entity: Node) -> void:
	members.erase(entity)
	threat.erase(entity)
	# Drop any stale references to this entity in other allies' threat tables.
	for ally in threat.keys():
		threat[ally].erase(entity)
	if focus_target == entity:
		focus_target = null

# ============================================
# Threat
# ============================================

func bump_threat(ally: Node, enemy: Node, amount: float) -> void:
	## Add `amount` of threat from `enemy` toward `ally`.
	if amount <= 0.0 or ally == null or enemy == null:
		return
	if not threat.has(ally):
		threat[ally] = {}
	var t: Dictionary = threat[ally]
	t[enemy] = t.get(enemy, 0.0) + amount

func get_threat_on(ally: Node) -> Dictionary:
	## Returns dict of enemy -> threat score (or empty dict).
	return threat.get(ally, {})

func get_threat_against(ally: Node, enemy: Node) -> float:
	if not threat.has(ally):
		return 0.0
	return float(threat[ally].get(enemy, 0.0))

func highest_threat_target_for(ally: Node) -> Node:
	## Returns the enemy currently threatening `ally` the most, or null.
	var t: Dictionary = threat.get(ally, {})
	var best: Node = null
	var best_score: float = 0.0
	for enemy in t.keys():
		if not is_instance_valid(enemy):
			continue
		var s: float = t[enemy]
		if s > best_score:
			best_score = s
			best = enemy
	return best

func decay_threat(decay_per_second: float, delta: float) -> void:
	## Multiplicative decay on all threat values. Call from a low-frequency tick.
	var factor: float = max(0.0, 1.0 - decay_per_second * delta)
	for ally in threat.keys():
		var t: Dictionary = threat[ally]
		for enemy in t.keys():
			t[enemy] = t[enemy] * factor

# ============================================
# Queries useful for healers / supports
# ============================================

func find_lowest_hp_ally(below_pct: float = 1.0, exclude: Node = null) -> Node:
	## Find the live ally with the lowest HP %, below `below_pct` (0..1).
	## Returns null if nobody qualifies.
	var best: Node = null
	var best_pct: float = below_pct
	for ally in members:
		if not is_instance_valid(ally) or ally == exclude:
			continue
		if not ally.has_method("get_health"):
			continue
		if not ally.has_method("is_alive") or not ally.call("is_alive"):
			continue
		var max_hp: float = _max_health_of(ally)
		if max_hp <= 0.0:
			continue
		var pct: float = ally.call("get_health") / max_hp
		if pct < best_pct:
			best_pct = pct
			best = ally
	return best

func find_most_threatened_ally(min_threat: float = 1.0, exclude: Node = null) -> Node:
	## Find the live ally with the most total threat against them.
	var best: Node = null
	var best_score: float = min_threat
	for ally in members:
		if not is_instance_valid(ally) or ally == exclude:
			continue
		var t: Dictionary = threat.get(ally, {})
		var total: float = 0.0
		for enemy in t.keys():
			if is_instance_valid(enemy):
				total += t[enemy]
		if total > best_score:
			best_score = total
			best = ally
	return best

# ============================================
# Helpers
# ============================================

func _max_health_of(ally: Node) -> float:
	if "max_health" in ally:
		var v = ally.get("max_health")
		if v is float or v is int:
			return float(v)
	if ally.has_method("get_max_health"):
		return ally.call("get_max_health")
	return 100.0

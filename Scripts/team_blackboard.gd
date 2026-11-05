class_name TeamBlackboard
extends RefCounted

## TeamBlackboard - shared knowledge for one faction (e.g. heroes, enemies).
##
## Holds:
##   - Live members of the team
##   - Threat table: per ally, who has been hitting them
##
## Brains read this to make coordinated decisions instead of each entity
## scoring targets in isolation. Owned by TeamRegistry.

var team_name: StringName = &""
var members: Array[EntityBase] = []

# Threat: members[i] -> Dictionary { enemy: Node -> score: float }
# Bumped on EventBus.damage_applied via TeamRegistry; decays over time.
var threat: Dictionary = {}


# ============================================
# Membership
# ============================================

func add_member(entity: EntityBase) -> void:
	if entity == null or members.has(entity):
		return
	members.append(entity)
	threat[entity] = {}

## Drop `entity` as an ATTACKER from every row (it may belong to another team).
## Pooled mobs leave the tree without being freed, so is_instance_valid
## pruning never catches them — a reused node would inherit old threat.
func forget_attacker(entity: Node) -> void:
	for ally in threat.keys():
		(threat[ally] as Dictionary).erase(entity)

## Drop `entity`'s own row. Its only caller, TeamRegistry.unregister, then
## runs forget_attacker on every team (this one included).
func remove_member(entity: EntityBase) -> void:
	members.erase(entity)
	threat.erase(entity)

# ============================================
# Threat
# ============================================

## Add `amount` of threat from `enemy` toward `ally`.
func bump_threat(ally: Node, enemy: Node, amount: float) -> void:
	if amount <= 0.0 or ally == null or enemy == null:
		return
	# Only members own a threat row. Ted's pet is in group "Hero" but never
	# registers, so without this guard it leaked a threat[pet] row forever.
	if not threat.has(ally):
		return
	var t: Dictionary = threat[ally]
	t[enemy] = t.get(enemy, 0.0) + amount

## Returns dict of enemy -> threat score (or empty dict).
func get_threat_on(ally: Node) -> Dictionary:
	return threat.get(ally, {})

func get_threat_against(ally: Node, enemy: Node) -> float:
	var row: Dictionary = threat.get(ally, {})
	return float(row.get(enemy, 0.0))

## Returns the enemy currently threatening `ally` the most, or null.
func highest_threat_target_for(ally: Node) -> Node:
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

## Multiplicative decay on all threat values. Call from a low-frequency tick.
func decay_threat(decay_per_second: float, delta: float) -> void:
	var factor: float = maxf(0.0, 1.0 - decay_per_second * delta)
	for ally in threat.keys():
		var t: Dictionary = threat[ally]
		for enemy in t.keys():
			# Prune freed attackers (non-members such as the pet are never
			# unregistered) and values that decayed to nothing.
			if not is_instance_valid(enemy):
				t.erase(enemy)
				continue
			var v: float = t[enemy] * factor
			if v < 0.05:
				t.erase(enemy)
			else:
				t[enemy] = v

# ============================================
# Queries useful for healers / supports
# ============================================

## Find the live ally with the lowest HP %, below `below_pct` (0..1).
## Returns null if nobody qualifies.
func find_lowest_hp_ally(below_pct: float = 1.0, exclude: Node = null) -> Node:
	var best: Node = null
	var best_pct: float = below_pct
	for ally in members:
		if not is_instance_valid(ally) or ally == exclude:
			continue
		if not ally.is_alive():
			continue
		var max_hp: float = ally.get_max_health()
		if max_hp <= 0.0:
			continue
		var pct: float = ally.get_health() / max_hp
		if pct < best_pct:
			best_pct = pct
			best = ally
	return best

## Find the live ally with the most total threat against them.
func find_most_threatened_ally(min_threat: float = 1.0, exclude: Node = null) -> Node:
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

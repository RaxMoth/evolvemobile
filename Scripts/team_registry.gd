extends Node

## TeamRegistry - autoload that owns one TeamBlackboard per faction.
##
## Two teams exist by default: HEROES and ENEMIES. Mobs and the Monster
## both register into ENEMIES (they share the same threat table — that's
## fine, since "who's hitting me" doesn't care about sub-faction).
##
## Threat is updated automatically: every EventBus.damage_applied bumps
## threat on the target's team, scaled by the source's `taunt_strength`
## (so a tank registers more aggro per point of damage than a DPS).
##
## Threat decays at THREAT_DECAY_PER_SEC (multiplicatively) so old aggro
## fades. The decay tick fires from _process at a low frequency.

const HEROES: StringName = &"heroes"
const ENEMIES: StringName = &"enemies"

const THREAT_DECAY_PER_SEC: float = 0.1   # 10% reduction per second
const DECAY_TICK_INTERVAL: float = 0.5    # decay every 0.5s, not every frame

var teams: Dictionary = {}
var _decay_timer: float = 0.0


func _ready() -> void:
	teams[HEROES] = _make_team(HEROES)
	teams[ENEMIES] = _make_team(ENEMIES)
	# One global subscription routes every damage event into the right team.
	EventBus.damage_applied.connect(_on_damage_applied)

func _make_team(name: StringName) -> TeamBlackboard:
	var t: TeamBlackboard = TeamBlackboard.new()
	t.team_name = name
	return t

func _process(delta: float) -> void:
	_decay_timer -= delta
	if _decay_timer <= 0.0:
		_decay_timer = DECAY_TICK_INTERVAL
		for team in teams.values():
			(team as TeamBlackboard).decay_threat(THREAT_DECAY_PER_SEC, DECAY_TICK_INTERVAL)


# ============================================
# Public API
# ============================================

func get_team(team_name: StringName) -> TeamBlackboard:
	return teams.get(team_name, null)

func register(entity: Node, team_name: StringName) -> void:
	var t: TeamBlackboard = get_team(team_name)
	if t:
		t.add_member(entity)

func unregister(entity: Node, team_name: StringName) -> void:
	var t: TeamBlackboard = get_team(team_name)
	if t:
		t.remove_member(entity)

## Resolve which team an entity belongs to from its scene groups.
## Returns &"" if not on any known team.
func team_name_of(entity: Node) -> StringName:
	if entity == null:
		return &""
	if entity.is_in_group("Hero"):
		return HEROES
	if entity.is_in_group("Enemy") or entity.is_in_group("Monster"):
		return ENEMIES
	return &""

func team_of(entity: Node) -> TeamBlackboard:
	return get_team(team_name_of(entity))


# ============================================
# Damage routing → threat
# ============================================

func _on_damage_applied(packet: DamagePacket) -> void:
	if packet == null or not is_instance_valid(packet.target):
		return
	if not is_instance_valid(packet.source):
		return

	# Threat is recorded against the TARGET's team (i.e. "enemies hitting me").
	var target_team: TeamBlackboard = team_of(packet.target)
	if target_team == null:
		return

	# Tank multiplier: source's taunt_strength scales how much threat each
	# damage point generates. Default 1.0; tanks set 2.0–3.0.
	var taunt: float = 1.0
	if "taunt_strength" in packet.source:
		var v = packet.source.get("taunt_strength")
		if v is float or v is int:
			taunt = float(v)

	target_team.bump_threat(packet.target, packet.source, packet.amount * taunt)

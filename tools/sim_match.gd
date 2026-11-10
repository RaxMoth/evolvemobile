extends SceneTree

## Headless auto-play match: loads World.tscn with both sides AI-controlled,
## runs it at a fixed 60 Hz step as fast as the CPU allows, and prints ONE
## JSON line describing the result. Use through tools/sim.sh (temp copies,
## isolated user://, many seeds in parallel). Never run against the real
## project directory with a newer editor binary.
##
##   godot --headless --fixed-fps 60 --max-fps 0 --path <copy> \
##         -s res://tools/sim_match.gd -- <seed> [heroes|monster] [cap_seconds] [trace] [rigs_awake] [monster=<id>] [threat=<0-4>]
##
## "monster=<id>" picks the roster monster (GameManager.select_monster, not
## persisted); without it the roster default plays, so old command lines replay
## the same matches. The result JSON names it ("monster", "monster_name").
##
## "threat=<N>" is the Opponent Threat parity check: both sides hold their
## threat-N AI build. MetaSkillManager.threat_override puts the AI opponent at
## threat N, and the played side's save gets its own side's AI build at N
## (MetaSkillManager.side_ai_build: 3N entries of each played character tree's
## ai_build_order, 2N of its base tree's). Without it the save decides (a
## fresh one: threat 0). The result JSON has the match's "threat" and the
## played side's power ranks ("power").
##
## "rigs_awake" makes every CharacterRig animate as if on screen (headless, no
## notifier ever fires): presentation must never feed gameplay, so the trace
## stays byte-identical (tools/sim_trace.sh RIGS_AWAKE=1).
##
## With "trace" it also prints a determinism fingerprint of the match state
## every TRACE_EVERY frames (`SIM_TRACE <frame> <hash>`) and once at the end
## (`SIM_TRACE_END <frame> <reason> <winner> <hash>`). tools/sim_trace.sh
## compares those lines between two trees to prove a refactor changed nothing.

const WORLD := "res://Scenes/World/World.tscn"
const FPS := 60.0
const TRACE_EVERY := 60
## EntityRegistry lists hashed by the trace, walked in list order.
const TRACE_LISTS: Array[String] = ["hero_side", "monsters", "mobs"]

var _seed: int = 1
var _side: String = "heroes"
var _cap_s: float = 660.0
var _trace: bool = false
## Roster id from "monster=<id>"; empty = the selection GameManager loaded.
var _monster_id: String = ""
## Threat from "threat=<N>" (the parity check); -1 = the rule on the save.
var _threat: int = -1
## Node name of the spawned monster: the "by" of the hero deaths it caused.
var _monster_name: String = ""
var _frames: int = 0
var _done: bool = false

var _first_contact_s: float = -1.0
var _hero_dmg_to_monster: float = 0.0
var _monster_dmg_to_heroes: float = 0.0
var _hero_deaths: Array = []
var _monster_stage_times: Array = []
var _mob_kills_by_monster: int = 0
var _mob_kills_by_heroes: int = 0
var _hero_damage: Dictionary = {}      # hero name -> damage dealt
var _hero_state_s: Dictionary = {}     # hero name -> {state: seconds}
var _hero_attack_casts: Dictionary = {} # hero name -> basic attacks executed
var _monster_dmg_taken: Dictionary = {"heroes": 0.0, "mobs": 0.0, "other": 0.0}
var _monster_killer: String = ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seed = int(args[0])
	if args.size() > 1:
		_side = String(args[1])
	if args.size() > 2:
		_cap_s = float(args[2])
	if args.size() > 3:
		_trace = String(args[3]) == "trace"
	for arg: String in args:
		if arg.begins_with("monster="):
			_monster_id = arg.trim_prefix("monster=")
		elif arg.begins_with("threat="):
			_threat = int(arg.trim_prefix("threat="))
	if args.has("rigs_awake"):
		# By path: a -s script must not name project classes.
		load("res://Scripts/Rig/character_rig.gd").set("force_awake", true)
	# Autoload globals are not compile-time identifiers inside a -s script;
	# go through the root and start on the first frame (root is in the tree).
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	seed(_seed)
	var gm := root.get_node("GameManager")
	gm.set("chosen_side", 1 if _side == "monster" else 0)
	if _monster_id != "":
		gm.call("select_monster", StringName(_monster_id), false)
	if _threat >= 0:
		_start_parity_check()
	gm.connect("match_ended", _on_match_ended)
	var bus := root.get_node("EventBus")
	bus.connect("damage_applied", _on_damage_applied)
	bus.connect("entity_died", _on_entity_died)
	bus.connect("monster_evolved", _on_monster_evolved)
	bus.connect("ability_cast", _on_ability_cast)
	var world := (load(WORLD) as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	var m := _monster()
	_monster_name = String(m.name) if m else ""
	process_frame.connect(_tick)


## "threat=<N>": the AI opponent plays its threat-N build and the played side
## owns its own (written into this run's save before World loads;
## tools/sim.sh refuses THREAT with SAVE).
func _start_parity_check() -> void:
	var gm := root.get_node("GameManager")
	var skills := root.get_node("MetaSkillManager")
	skills.set("threat_override", _threat)
	var build: Dictionary = skills.call("side_ai_build", gm.get("chosen_side"), gm.get("selected_monster_id"), _threat)
	var data := root.get_node("PersistedData")
	for tree_id: StringName in build:
		var ranks: Dictionary = build[tree_id]
		for node_id: StringName in ranks:
			data.call("set_skill_rank", tree_id, node_id, int(ranks[node_id]))


func _t() -> float:
	return _frames / FPS


func _tick() -> void:
	_frames += 1
	if _frames % 6 == 0:  # sample hero states at 10 Hz
		for h in root.get_node("EntityRegistry").get("heroes"):
			if is_instance_valid(h):
				var n := String((h as Node).name)
				var st := _state_of(h as Node)
				var d: Dictionary = _hero_state_s.get_or_add(n, {})
				d[st] = float(d.get(st, 0.0)) + 0.1
	if _trace and not _done and _frames % TRACE_EVERY == 0:
		print("SIM_TRACE %d %d" % [_frames, _trace_hash("")])
	if not _done and _t() >= _cap_s:
		_finish("cap", "none")


func _on_damage_applied(packet: Object) -> void:
	var src: Object = packet.get("source")
	var dst: Object = packet.get("target")
	var amount: float = float(packet.get("amount"))
	if dst != null and is_instance_valid(dst) and _is(dst, "MonsterBase"):
		_monster_dmg_taken[_faction(src)] = float(_monster_dmg_taken[_faction(src)]) + amount
	if src == null or dst == null or not is_instance_valid(src) or not is_instance_valid(dst):
		return
	# Ted's pet fights for the heroes (group "Hero", not a HeroBase).
	var src_hero := _is(src, "HeroBase") or (src is Node and (src as Node).is_in_group("Hero"))
	if src_hero:
		var hn := String((src as Node).name)
		_hero_damage[hn] = float(_hero_damage.get(hn, 0.0)) + amount
	var dst_hero := _is(dst, "HeroBase") or (dst is Node and (dst as Node).is_in_group("Hero"))
	var src_mon := _is(src, "MonsterBase")
	var dst_mon := _is(dst, "MonsterBase")
	if (src_hero and dst_mon) or (src_mon and dst_hero):
		if _first_contact_s < 0.0:
			_first_contact_s = _t()
	if src_hero and dst_mon:
		_hero_dmg_to_monster += amount
	elif src_mon and dst_hero:
		_monster_dmg_to_heroes += amount


func _on_entity_died(entity: Object, killer: Object) -> void:
	if _is(entity, "MonsterBase"):
		_monster_killer = _faction(killer)
		return
	if _is(entity, "MobBase"):
		if killer != null and is_instance_valid(killer):
			if _is(killer, "MonsterBase"):
				_mob_kills_by_monster += 1
			elif _is(killer, "HeroBase") or _is(killer, "Node2D"):
				_mob_kills_by_heroes += 1
		return
	if _is(entity, "HeroBase"):
		var m := _monster()
		var pos: Vector2 = (entity as Node2D).global_position
		var allies_500 := 0
		var allies_fighting := 0
		for h in root.get_node("EntityRegistry").get("heroes"):
			if h == entity or not is_instance_valid(h):
				continue
			if (h as Node2D).global_position.distance_to(pos) <= 500.0:
				allies_500 += 1
				if h.call("is_target_valid"):
					allies_fighting += 1
		var attackers := 0
		for e in root.get_node("EntityRegistry").get("enemies"):
			if is_instance_valid(e) and e.get("target_entity") == entity:
				attackers += 1
		_hero_deaths.append({
			"hero": String((entity as Node).name),
			"t": snappedf(_t(), 0.1),
			"stage": int(m.get("current_stage")) if m else -1,
			"by": String((killer as Node).name) if killer != null and is_instance_valid(killer) else "",
			"level": int((entity as Node).get_node("HeroStats").get("level")),
			"allies_500": allies_500,
			"allies_fighting": allies_fighting,
			"attackers": attackers,
			"state": _state_of(entity as Node),
		})


func _on_ability_cast(caster: Object, ability: Object, _target: Object) -> void:
	if _is(caster, "HeroBase") and ability != null and int(ability.get("ability_type")) == 2:
		var n := String((caster as Node).name)
		_hero_attack_casts[n] = int(_hero_attack_casts.get(n, 0)) + 1


func _on_monster_evolved(_m: Object, stage: int) -> void:
	_monster_stage_times.append({"stage": stage, "t": snappedf(_t(), 0.1)})


func _on_match_ended(winner: String, _game_time: float) -> void:
	_finish("end", winner)


func _finish(reason: String, winner: String) -> void:
	if _done:
		return
	_done = true
	var m := _monster()
	if _monster_killer == "" and m and not m.call("is_alive"):
		# GameManager ends the match from the same entity_died emission, often
		# before our handler runs: fall back to the monster's last attacker.
		_monster_killer = _faction(m.get("last_attacker"))
	var gm := root.get_node("GameManager")
	var reg := root.get_node("EntityRegistry")
	var out := {
		"seed": _seed,
		"side": _side,
		"monster": String(gm.get("selected_monster_id")),
		"monster_name": _monster_name,
		"threat": int(gm.get("match_threat")),
		"power": int(root.get_node("MetaSkillManager").call("power_ranks", gm.get("chosen_side"), gm.get("selected_monster_id"))),
		"reason": reason,
		"winner": winner,
		"t": snappedf(_t(), 0.1),
		"game_clock": snappedf(float(gm.call("get_match_elapsed")), 0.1),
		"monster_stage": int(gm.get("monster_stage_reached")),
		"monster_hp_pct": snappedf(float(m.call("get_health")) / maxf(1.0, float(m.call("get_max_health"))), 0.01) if m else 0.0,
		"monster_xp": snappedf(float(m.get("current_xp")), 1.0) if m else -1.0,
		"heroes_alive": (reg.get("heroes") as Array).size(),
		"hero_deaths": _hero_deaths,
		"evolutions": _monster_stage_times,
		"first_contact": snappedf(_first_contact_s, 0.1),
		"hero_dmg_to_monster": roundi(_hero_dmg_to_monster),
		"monster_dmg_to_heroes": roundi(_monster_dmg_to_heroes),
		"mob_kills_monster": _mob_kills_by_monster,
		"mob_kills_heroes": _mob_kills_by_heroes,
		"hero_damage": _hero_damage,
		"hero_states": _hero_state_s,
		"hero_basic_casts": _hero_attack_casts,
		"monster_dmg_taken": _monster_dmg_taken,
		"monster_killer": _monster_killer,
	}
	if _trace:
		var tail := "%s %s" % [reason, winner]
		print("SIM_TRACE_END %d %s %d" % [_frames, tail, _trace_hash(tail)])
	print("SIM_RESULT " + JSON.stringify(out))
	quit()


func _state_of(entity: Node) -> String:
	var chart: Node = entity.get_node_or_null("%StateChart")
	if chart == null or chart.get_child_count() == 0:
		return ""
	for child in chart.get_child(0).get_children():
		if "active" in child and child.get("active"):
			return String(child.name)
	return ""


## Determinism fingerprint: per entity its class, position (1 px), health and
## active state; monster stage and XP; the match's mob kill count. Never hash
## node names: pooled mobs and VFX get auto-names (@Bat@N) from a global
## counter, so adding an unrelated node anywhere would rename later mobs.
func _trace_hash(tail: String) -> int:
	var reg := root.get_node("EntityRegistry")
	var parts := PackedStringArray()
	for list_name in TRACE_LISTS:
		parts.append(list_name)
		for e in reg.get(list_name):
			if is_instance_valid(e):
				parts.append(_trace_entity(e as Node2D, list_name == "monsters"))
	parts.append(str(root.get_node("GameManager").get("mob_kills")))
	parts.append(tail)
	return "|".join(parts).hash()


func _trace_entity(e: Node2D, is_monster: bool) -> String:
	var scr: Script = e.get_script()
	var hp := 0.0
	if e.has_method("get_health"):
		hp = float(e.call("get_health"))
	elif "current_health" in e:  # Ted's pet
		hp = float(e.get("current_health"))
	var s := "%s %d %d %d %s" % [
		String(scr.get_global_name()) if scr else "",
		int(snappedf(e.global_position.x, 1.0)),
		int(snappedf(e.global_position.y, 1.0)),
		roundi(hp),
		_state_of(e),
	]
	if is_monster:
		s += " %d %d" % [int(e.get("current_stage")), roundi(float(e.get("current_xp")))]
	return s


func _monster() -> Node2D:
	return root.get_node("EntityRegistry").call("first_monster") as Node2D


## "heroes" (heroes and Ted's pet), "mobs", or "other" (no / freed source).
func _faction(o: Object) -> String:
	if o == null or not is_instance_valid(o):
		return "other"
	if _is(o, "HeroBase") or (o is Node and (o as Node).is_in_group("Hero")):
		return "heroes"
	if _is(o, "MobBase"):
		return "mobs"
	return "other"


func _is(o: Object, cls: String) -> bool:
	if o == null:
		return false
	var s: Script = o.get_script()
	while s != null:
		if s.get_global_name() == cls:
			return true
		s = s.get_base_script()
	return o.is_class(cls)

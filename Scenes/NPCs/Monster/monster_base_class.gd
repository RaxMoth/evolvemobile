extends EntityBase
class_name MonsterBase

## Presentation: the rig shows the new stage's parts (scene-wired to Rig.set_stage).
signal evolved(stage: int)

@export_group("Monster Configuration")
@export var monster_stats: MonsterStats
@export var visual_config: MonsterVisualConfig
## true (the tuned build): evolving refills HP. false: the README rule
## "Healing on Evolution: gains (new max HP - old max HP)". The Grount node
## Second Wind (+200 on the Stage 2 heal, capped at max) only shows with false.
@export var heal_to_full_on_evolution: bool = true

@export_group("Monster Abilities")
@export var ability_1: AbilityBase
@export var ability_2: AbilityBase
@export var ability_3: AbilityBase
@export var passive_ability: AbilityBase

@export_group("Monster Strategy")
## Behaviour profile (hide & farm → ambush → hunt, retreat when hurt, combos).
## null or enabled=false keeps the legacy "hunt the nearest hero" behaviour.
@export var strategy_profile: MonsterStrategy

@export_group("Skill Tree Behaviours")
## Numbers of the Grount tree's behaviour nodes (README "Grount Tree"). They
## only act while the matching node is unlocked (_meta_enrage / _meta_titan).
## Enrage: below this fraction of max HP, move speed and all damage go up.
@export_range(0.0, 1.0) var enrage_hp_pct: float = 0.2
@export var enrage_speed_mult: float = 1.3
@export var enrage_damage_mult: float = 1.5
## Titan Form: from this stage on, bigger (scale on top of the stage scale),
## tougher (flat max HP after the % nodes) and longer reach (flat range).
@export var titan_stage: int = 3
@export var titan_scale_mult: float = 1.5
@export var titan_bonus_health: float = 500.0
@export var titan_bonus_range: float = 20.0

## README attack range before skill nodes (80 flat at every stage).
const BASE_ATTACK_RANGE: float = 80.0
## The last evolution stage (Stage III, "Apex Predator").
const FINAL_STAGE: int = 3
## Fight hands back to Approach beyond this distance (+ get_range_bonus()).
const FIGHT_LEAVE_DISTANCE: float = 100.0

## Current strategy. A pure function of stage, health and nearby heroes,
## recomputed every strategy_eval_interval (see _compute_strategy). It only
## biases target scoring, idle destinations and ability choice — the state
## chart remains the one state machine.
enum Strategy { FARM, AMBUSH, HUNT, RETREAT }
var strategy: Strategy = Strategy.HUNT
var _strategy_timer: float = 0.0
var _heroes_near: int = 0
var _had_heroes_near: bool = false
## Mobs above this stage's farming gate that are attacking us (refreshed with
## the strategy): we flee from them instead of farming next to them.
var _mob_threats: Array[Node2D] = []
var _cast_lock: float = 0.0
var _resting: bool = false
## Seconds since the last damage packet (rest regeneration waits regen_delay).
var _since_damage: float = 0.0
var _camp_goal: MobSpawnArea = null
## The running stage scale tween (_update_stage_scale), killed by the next one.
var _stage_tween: Tween


var current_stage: int = 1
var current_health: float
var current_xp: float = 0.0
var damage_multiplier: float = 1.0

# Permanent meta-skill multipliers (from MetaSkillManager.collect_monster_modifiers).
# 1.0 = no upgrade purchased. Loaded once in _ready before stage config so the
# Monster Base skill tree actually affects gameplay (was previously seeded +
# purchasable but never consumed).
var _meta_health_mult: float = 1.0
var _meta_damage_mult: float = 1.0
var _meta_speed_mult: float = 1.0
var _meta_xp_mult: float = 1.0
var _meta_evo_threshold_mult: float = 1.0
var _meta_range_mult: float = 1.0
# Generic keys (README "Generic stat keys"), one apply site each, neutral when
# not owned: incoming hits (_receive_damage), rest regeneration (_update_rest),
# cast cooldowns (_cast), damage at the final stage (effective_ability_damage)
# and the XP banked at spawn (_ready; additive, 0 = none).
var _meta_damage_taken_mult: float = 1.0
var _meta_regen_mult: float = 1.0
var _meta_cooldown_mult: float = 1.0
var _meta_final_stage_damage_mult: float = 1.0
var _meta_start_xp: float = 0.0
# Behaviour nodes (additive keys from the same collect_monster_modifiers call;
# 0 = not unlocked). Enrage and Titan Form are flags, Second Wind an amount.
var _meta_enrage: bool = false
var _meta_titan: bool = false
var _meta_stage_2_evo_heal: float = 0.0

var ability_cooldowns := {
	"ability_1": 0.0,
	"ability_2": 0.0,
	"ability_3": 0.0,
}
## The cooldown each slot started at on its last cast, so the HUD can draw
## remaining / total (get_cooldown_progress). Written by _cast only, never
## read by gameplay.
var _cooldown_totals: Dictionary[String, float] = {}

func _ready() -> void:
	if not monster_stats:
		push_error(name + " missing MonsterStats resource!")
		return
	# Load permanent upgrades BEFORE stage config so stage-1 health/damage
	# already reflect any purchased Monster Base skills.
	_load_meta_modifiers()
	# Head Start (monster_start_xp): XP banked before the first kill. Set, not
	# gained, so Bloodhound's XP bonus does not scale it; the next XP gain
	# checks evolution as usual.
	current_xp = _meta_start_xp
	_enter_stage()
	super._ready()

func _process(delta: float) -> void:
	_cast_lock = maxf(_cast_lock - delta, 0.0)
	for key in ability_cooldowns.keys():
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] -= delta

	if passive_ability:
		passive_ability.on_passive_update(self, delta)
	

## Applies everything that depends on current_stage: HP, damage, XP value,
## ability stats, size, aggro radius, strafing and the Fight leave distance.
## Idempotent, so re-entering a stage never stacks anything. The values that
## never change per stage live on the monster_base_class.tscn root: spacing
## (preferred 45 / min 20) and taunt_strength 1.5 (more threat per damage
## point than a mob, so a hero Tank has to work harder to peel the monster).
func _enter_stage() -> void:
	var stage: int = current_stage
	var new_health: float = _max_health_for_stage(stage)

	if stage == 1 or heal_to_full_on_evolution:
		current_health = new_health
	else:
		# README "Healing on Evolution": gain (new max HP - old max HP).
		current_health = minf(current_health + new_health - _max_health_for_stage(stage - 1), new_health)

	damage_multiplier = monster_stats.get_damage_mult_for_stage(stage) * _meta_damage_mult
	xp_value = monster_stats.get_xp_value_for_stage(stage)
	
	_configure_abilities_for_stage(stage)
	
	set_hp_display(current_health, new_health)
	
	_update_stage_scale(stage)
	# Titan Form's extra size must not widen the aggro circle (see
	# _get_detection_shape_radius; the scale tween keeps it in step).
	_update_detection_radius()

	strafe_speed = monster_stats.get_strafe_speed_for_stage(stage)
	strafe_change_interval = monster_stats.get_strafe_interval_for_stage(stage)
	# Approach enters Fight at attack_range and Fight leaves past max_distance:
	# Titan Form's flat reach moves both by the same amount, so the hysteresis
	# stays what it was (no Approach/Fight ping-pong at the longer range).
	max_distance = FIGHT_LEAVE_DISTANCE + get_range_bonus()

func _get_entity_level() -> int:
	return current_stage

	
func _configure_abilities_for_stage(stage: int) -> void:
	if ability_1:
		ability_1.apply_stage_stats(stage)

	if ability_2:
		ability_2.apply_stage_stats(stage)

	if ability_3:
		# Locked below its unlock_stage (Ground Slam: 2, or 1 with "Early Slam").
		ability_3.apply_stage_stats(stage)

func _update_stage_scale(stage: int) -> void:
	# Absolute per stage (Titan Form included), so re-applying never compounds.
	var target_scale: Vector2 = _scale_for_stage(stage)
	# A newer evolution takes over from a running one (one scale writer).
	if _stage_tween and _stage_tween.is_valid():
		_stage_tween.kill()
	_stage_tween = create_tween()
	_stage_tween.tween_method(_set_stage_scale, scale, target_scale, 0.5) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


## One step of the stage scale tween. The Hud is re-pinned on every step, so
## the HP bar and level label keep their pixel size through the growth and its
## overshoot. The aggro radius follows the growing root scale step by step (see
## _get_detection_shape_radius): writing the Titan-sized radius before the body
## had grown shrank the circle and dropped the chase target. Without Titan Form
## the radius is constant and _update_detection_radius skips the write.
func _set_stage_scale(s: Vector2) -> void:
	scale = s
	_apply_ui_counter_scale()
	_update_detection_radius()

func _is_attack_ready() -> bool:
	if not _strategy_enabled():
		return ability_cooldowns.get("ability_1", 0.0) <= 0.0
	return not _is_busy() and (is_ability_ready("ability_1") or _slam_ready())


# ============================================
# EntityBase Virtual Method Overrides
# ============================================

func _get_move_speed() -> float:
	return monster_stats.get_speed_for_stage(current_stage) * _meta_speed_mult * _enrage_factor(enrage_speed_mult)

func _get_attack_range() -> float:
	return BASE_ATTACK_RANGE * _meta_range_mult + get_range_bonus()

## The aggro circle is a child of the root, so it scales with the monster. With
## Titan Form its world radius follows the live root scale up to the stage's
## own size and holds there: the extra size never widens it (the node buys size,
## HP and reach, not wider senses), and mid-evolution, while the body is still
## growing, it never drops below the radius it had before.
func _get_detection_shape_radius() -> float:
	if not is_titan() or scale.x <= 0.0:
		return detection_radius
	return detection_radius * minf(1.0, monster_stats.get_scale_for_stage(current_stage).x / scale.x)

func _get_idle_retarget_time() -> float:
	return 2.0

func _get_idle_wander_radius() -> float:
	# Roam freely across the map like heroes!
	return 300.0 # Larger radius for exploration

func _get_keep_distance() -> float:
	return 50.0

func _is_always_full_rate() -> bool:
	return true  # camera anchor: never LOD-throttled

func is_alive() -> bool:
	return current_health > 0.0

func get_health() -> float:
	return current_health

func get_max_health() -> float:
	return _max_health_for_stage(current_stage) if monster_stats else current_health

func _receive_damage(packet: DamagePacket) -> void:
	if not is_alive():
		return

	last_attacker = packet.source if packet.source is Node2D else null
	_since_damage = 0.0
	# Scarred Hide / Thick Hide (monster_damage_taken_mult): the hit's final
	# amount, so the damage_applied listeners see what landed.
	packet.amount *= _meta_damage_taken_mult
	current_health -= packet.amount
	set_hp_display(current_health, get_max_health())

	if current_health <= 0.0:
		current_health = 0.0
		state_chart.send_event(CombatEvents.SELF_DEAD)


# ============================================
# XP & Evolution System (Resource-Driven)
# ============================================

func gain_xp(amount: float) -> void:
	current_xp += amount * _meta_xp_mult
	_check_evolution()

func _check_evolution() -> void:
	var next_threshold = _get_next_evolution_threshold()
	
	if current_xp >= next_threshold:
		var new_stage = current_stage + 1
		
		if new_stage <= FINAL_STAGE:
			_evolve_to_stage(new_stage)

func _evolve_to_stage(new_stage: int) -> void:
	current_stage = new_stage

	# Reset cooldowns on evolution
	for key in ability_cooldowns.keys():
		ability_cooldowns[key] = 0.0
		
	if lv_label:
		lv_label.text = str(current_stage)
	# Visual update
	_update_stage_visuals(current_stage)
	
	# Stage stats from the resource (HP, damage, size, spacing).
	_enter_stage()
	# Grount "Second Wind" tops the evolution heal up.
	_apply_evolution_bonus_heal(current_stage)

	evolved.emit(current_stage)
	EventBus.notify_monster_evolved(self, current_stage)

func _get_next_evolution_threshold() -> int:
	if not monster_stats:
		return 999999

	# Lower threshold = faster evolution (Quick Evolution skill = 0.90).
	return int(monster_stats.get_xp_threshold_for_stage(current_stage + 1) * _meta_evo_threshold_mult)


func _load_meta_modifiers() -> void:
	## Pull the player's purchased Monster Base upgrades from MetaSkillManager.
	## Keys default to 1.0 when no matching skill is unlocked, so an un-upgraded
	## monster behaves exactly as before.
	# Monster Base tree merged with this monster's own tree (monster_<id>).
	var monster_id: StringName = monster_stats.monster_id if monster_stats else &""
	var mods: Dictionary = MetaSkillManager.collect_monster_modifiers(monster_id)
	_meta_health_mult = float(mods.get("monster_health_mult", 1.0))
	_meta_damage_mult = float(mods.get("monster_damage_mult", 1.0))
	_meta_speed_mult = float(mods.get("monster_speed_mult", 1.0))
	_meta_xp_mult = float(mods.get("monster_xp_mult", 1.0))
	_meta_evo_threshold_mult = float(mods.get("monster_evo_threshold", 1.0))
	_meta_range_mult = float(mods.get("monster_range_mult", 1.0))
	_meta_damage_taken_mult = float(mods.get("monster_damage_taken_mult", 1.0))
	_meta_regen_mult = float(mods.get("monster_regen_mult", 1.0))
	_meta_cooldown_mult = float(mods.get("monster_cooldown_mult", 1.0))
	_meta_final_stage_damage_mult = float(mods.get("monster_s3_damage_mult", 1.0))
	# Additive keys: missing = 0.0 = none / off (Head Start, behaviour nodes).
	_meta_start_xp = float(mods.get("monster_start_xp", 0.0))
	_meta_enrage = float(mods.get("monster_enrage", 0.0)) > 0.5
	_meta_titan = float(mods.get("monster_titan_form", 0.0)) > 0.5
	_meta_stage_2_evo_heal = float(mods.get("monster_stage_2_evo_heal", 0.0))
	# Per-entity ability copies, then the tree's ability nodes (cooldown, dash
	# distance, …). apply_stage_stats re-applies them on every evolution.
	_make_abilities_unique()
	MetaSkillManager.apply_ability_nodes_to_monster(monster_id, _all_abilities())

func _make_abilities_unique() -> void:
	if ability_1 and not ability_1.resource_path.is_empty():
		ability_1 = ability_1.duplicate()
	if ability_2 and not ability_2.resource_path.is_empty():
		ability_2 = ability_2.duplicate()
	if ability_3 and not ability_3.resource_path.is_empty():
		ability_3 = ability_3.duplicate()
	if passive_ability and not passive_ability.resource_path.is_empty():
		passive_ability = passive_ability.duplicate()


func _all_abilities() -> Array[AbilityBase]:
	var out: Array[AbilityBase] = []
	for a in [ability_1, ability_2, ability_3, passive_ability]:
		if a != null:
			out.append(a)
	return out


# ============================================
# Skill-tree behaviour nodes (Grount tree)
# ============================================

## Max HP of a stage: README table x the % HP nodes, plus Titan Form's flat
## bonus. The single source for get_max_health and the evolution heal.
func _max_health_for_stage(stage: int) -> float:
	var hp: float = monster_stats.get_health_for_stage(stage) * _meta_health_mult
	if _titan_at(stage):
		hp += titan_bonus_health
	return hp


func _scale_for_stage(stage: int) -> Vector2:
	var s: Vector2 = monster_stats.get_scale_for_stage(stage)
	return s * titan_scale_mult if _titan_at(stage) else s


## Grount "Enrage": below enrage_hp_pct of the current max HP. A pure function
## of HP (no stored flag), so it can neither stick nor stack, and every HP
## change — a hit, rest regeneration, the evolution heal — toggles it at once.
func is_enraged() -> bool:
	return _meta_enrage and is_alive() and current_health < get_max_health() * enrage_hp_pct


func _enrage_factor(mult: float) -> float:
	return mult if is_enraged() else 1.0


## Grount "Titan Form": active from titan_stage on. Every effect is derived
## from the stage (max HP, scale, reach), so re-entering a stage never stacks it.
func is_titan() -> bool:
	return _titan_at(current_stage)


func _titan_at(stage: int) -> bool:
	return _meta_titan and stage >= titan_stage


## Flat reach on top of the % range nodes (Titan Form). The attack range,
## Front Cleave's hit radius and the Fight leave distance all grow by it.
func get_range_bonus() -> float:
	return titan_bonus_range if is_titan() else 0.0


## Grount "Second Wind": extra HP when evolving into Stage 2, never above max.
func _apply_evolution_bonus_heal(stage: int) -> void:
	if stage != 2 or _meta_stage_2_evo_heal <= 0.0:
		return
	var max_hp: float = get_max_health()
	current_health = minf(current_health + _meta_stage_2_evo_heal, max_hp)
	set_hp_display(current_health, max_hp)


## One F3 HUD line: stage, HP and the behaviour nodes this monster carries
## ("!" = active right now; Gravity Slam shows how many the last slam pulled).
func debug_meta_line() -> String:
	var tags: Array[String] = []
	if ability_3 != null and "pull_radius" in ability_3 and float(ability_3.get("pull_radius")) > 0.0:
		var pulled: int = int(ability_3.get("last_pull_count")) if "last_pull_count" in ability_3 else 0
		tags.append("pull(last %d)" % pulled)
	if _meta_enrage:
		tags.append("enrage!" if is_enraged() else "enrage")
	if _meta_stage_2_evo_heal > 0.0:
		tags.append("evoheal +%d" % roundi(_meta_stage_2_evo_heal))
	if _meta_titan:
		tags.append("titan!" if is_titan() else "titan")
	var listed: String = " ".join(tags) if not tags.is_empty() else "-"
	return "%s S%d HP %d/%d nodes: %s" % [name, current_stage, roundi(current_health), roundi(get_max_health()), listed]


## The F3 line under debug_meta_line: the generic tree keys this monster
## carries ("!" = Apex Predator active now; "-" on a fresh save).
func debug_keys_line() -> String:
	var tags: Array[String] = []
	if _meta_damage_taken_mult != 1.0:
		tags.append("dmg taken x%.2f" % _meta_damage_taken_mult)
	if _meta_regen_mult != 1.0:
		tags.append("regen x%.2f" % _meta_regen_mult)
	if _meta_cooldown_mult != 1.0:
		tags.append("cd x%.2f" % _meta_cooldown_mult)
	if _meta_final_stage_damage_mult != 1.0:
		var apex: String = "apex x%.2f" % _meta_final_stage_damage_mult
		tags.append(apex + "!" if current_stage >= FINAL_STAGE else apex)
	if _meta_start_xp > 0.0:
		tags.append("xp +%d" % roundi(_meta_start_xp))
	return "tree keys: " + (" ".join(tags) if not tags.is_empty() else "-")


# ============================================
# Stage Visuals
# ============================================


func _update_stage_visuals(stage: int) -> void:
	if visual_root() != animated_sprite:
		# A CharacterRig shows the stage's parts and flashes on `evolved`.
		if visual_config and visual_config.enable_stage_effects:
			_play_stage_effect(stage)
		return
	if not animated_sprite or not visual_config:
		return

	var sprite_frames = visual_config.get_sprite_frames_for_stage(stage)
	var animation_name = visual_config.get_animation_name_for_stage(stage)
	if sprite_frames:
		animated_sprite.sprite_frames = sprite_frames

	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	else:
		if animated_sprite.sprite_frames == null:
			push_warning(name + " has no SpriteFrames!")
			return
		var available_anims = animated_sprite.sprite_frames.get_animation_names()
		if available_anims.size() > 0:
			animated_sprite.play(available_anims[0])
		else:
			push_warning(name + " has no animations available!")
	
	if visual_config.enable_stage_effects:
		_play_stage_effect(stage)

func _play_stage_effect(stage: int) -> void:
	# Flash sprite (a CharacterRig flashes itself on set_stage)
	if animated_sprite and visual_root() == animated_sprite:
		var flash_color = Color.WHITE
		match stage:
			2: flash_color = Color(1.5, 1.2, 0.8) # Orange
			3: flash_color = Color(1.8, 0.8, 0.8) # Red
		
		GameUtils.flash_modulate(animated_sprite, flash_color, 0.2, 0.3)
	
	# Expanding ring effect
	var ring_color: Color = Color.YELLOW
	match stage:
		2: ring_color = Color.ORANGE
		3: ring_color = Color.RED
	RingPulse.spawn(get_parent(), global_position, ring_color, 50.0, 5.0, 5.0, 0.8, 10)

# ============================================
# Combat & AI
# ============================================

func _on_fight_logic(_delta: float) -> void:
	if not is_target_valid():
		return
	
	_choose_and_use_ability()

func _choose_and_use_ability() -> void:
	if _strategy_enabled():
		_choose_and_use_ability_combo()
		return
	match current_stage:
		1:
			_cast("ability_1", ability_1, target_entity)
		2:
			if ability_cooldowns["ability_2"] <= 0.0 and ability_2:
				_cast("ability_2", ability_2, target_entity)
			else:
				_cast("ability_1", ability_1, target_entity)
		_:
			# Stage 3: Prioritize abilities
			if ability_cooldowns["ability_3"] <= 0.0 and ability_3:
				_cast("ability_3", ability_3, target_entity)
			elif ability_cooldowns["ability_2"] <= 0.0 and ability_2:
				_cast("ability_2", ability_2, target_entity)
			else:
				_cast("ability_1", ability_1, target_entity)


## Damage one cast of `ability` deals. README per-stage tables already include
## the stage multiplier (Front Cleave 12/17/24 = 12 x 1.0/1.4/2.0, Ram Dash
## 18/25/36), so a tabled ability only gets the permanent skill-tree bonus;
## applying the stage multiplier again made a stage-3 cleave hit for 48.
## Apex Predator (monster_s3_damage_mult) multiplies at the final stage, and
## Enrage on top of everything at cast time (Grount has no separate basic
## attack: Front Cleave, Ram Dash and Ground Slam all come through here).
func effective_ability_damage(ability: AbilityBase) -> float:
	var dmg: float = ability.damage * _meta_damage_mult
	if ability.damage_per_stage.is_empty():
		dmg = ability.damage * damage_multiplier
	return dmg * _final_stage_damage_factor() * _enrage_factor(enrage_damage_mult)


func _final_stage_damage_factor() -> float:
	return _meta_final_stage_damage_mult if current_stage >= FINAL_STAGE else 1.0


## Cast with an explicit target (null = facing-direction cast, e.g. an escape
## dash). Starts the shared cast lock so abilities never fire on consecutive
## frames while another one is still moving the monster.
func _cast(ability_name: String, ability: AbilityBase, cast_target: Node2D) -> bool:
	if not ability or ability_cooldowns.get(ability_name, 0.0) > 0.0:
		return false
	if not ability.is_unlocked_at(current_stage) or not ability.can_use(self):
		return false
	ability.execute(self, cast_target, effective_ability_damage(ability))
	# Primal Rhythm (monster_cooldown_mult) shortens every cast's cooldown.
	var cooldown: float = ability.cooldown * _meta_cooldown_mult
	ability_cooldowns[ability_name] = cooldown
	_cooldown_totals[ability_name] = cooldown
	if strategy_profile:
		_cast_lock = strategy_profile.cast_lock_time
	EventBus.notify_ability_cast(self, ability, cast_target)
	return true


# ============================================
# Strategy layer (README "Monster AI — planned")
# ============================================

func _strategy_enabled() -> bool:
	return strategy_profile != null and strategy_profile.enabled


## Pure decision from the current situation (no transitions are stored):
## hurt early-stage monster with heroes close → RETREAT; then by stage.
func _compute_strategy() -> Strategy:
	var p := strategy_profile
	var hp_ratio: float = current_health / maxf(get_max_health(), 1.0)
	if current_stage <= p.retreat_max_stage and hp_ratio < p.retreat_hp_pct and _heroes_near >= p.retreat_min_heroes:
		return Strategy.RETREAT
	if current_stage >= p.hunt_from_stage:
		return Strategy.HUNT
	if current_stage >= p.ambush_from_stage:
		return Strategy.AMBUSH
	return Strategy.FARM


func _pre_tick(delta: float) -> void:
	super._pre_tick(delta)
	if not _strategy_enabled() or not is_alive():
		return
	_since_damage += delta
	_update_rest(delta)
	_strategy_timer -= delta
	if _strategy_timer <= 0.0:
		_strategy_timer = strategy_profile.strategy_eval_interval
		_update_strategy()


func _update_strategy() -> void:
	var p := strategy_profile
	_heroes_near = EntityRegistry.count_within(EntityRegistry.heroes, global_position, p.hero_awareness_radius)
	var next: Strategy = _compute_strategy()
	var heroes_close: bool = _heroes_near > 0
	var was_threatened: bool = not _mob_threats.is_empty()
	_mob_threats = _find_mob_threats(next)
	if next != strategy or heroes_close != _had_heroes_near or was_threatened != not _mob_threats.is_empty():
		strategy = next
		_camp_goal = null
		_idle_timer = 0.0  # Idle re-picks its destination on this step
		if is_target_valid():
			# May drop a hero we are no longer allowed to fight (ENEMY_EXITED;
			# Fight then sends TARGET_LOST on its next step).
			_reevaluate_current_target(0.0)
	_had_heroes_near = heroes_close
	if _get_taunter() != null and is_target_valid():
		state_chart.send_event(CombatEvents.ENEMY_ENTERED)
	elif not is_target_valid():
		# Picks up a cornering hero or a strategy flip while areas already
		# overlap (no new area_entered would fire).
		_check_for_nearby_enemies()
	_try_escape_dash()


## Low-HP rest mode with hysteresis (rest_hp_pct .. resume_hp_pct). Resting
## drops mob targets, keeps away from camps and regenerates out of combat.
func _update_rest(delta: float) -> void:
	var p := strategy_profile
	var max_hp: float = maxf(get_max_health(), 1.0)
	var hp_ratio: float = current_health / max_hp
	var was_resting: bool = _resting
	if strategy == Strategy.HUNT:
		_resting = false
	elif not _resting and hp_ratio < p.rest_hp_pct:
		_resting = true
	elif _resting and hp_ratio >= p.resume_hp_pct:
		_resting = false
	if _resting != was_resting:
		_camp_goal = null
		_idle_timer = 0.0
		if _resting and is_target_valid():
			_reevaluate_current_target(0.0)
	if _resting and _since_damage >= p.regen_delay and p.rest_regen_pct_per_sec > 0.0 and current_health < max_hp:
		# Primal Regeneration (monster_regen_mult) speeds the rest regeneration.
		current_health = minf(current_health + max_hp * p.rest_regen_pct_per_sec * _meta_regen_mult * delta, max_hp)
		set_hp_display(current_health, max_hp)


func is_resting() -> bool:
	return _resting


func _score_target(target_node: Node2D) -> float:
	if not _strategy_enabled():
		return super._score_target(target_node)
	var taunter := _get_taunter()
	if taunter != null:
		return 10000.0 if target_node == taunter else -1000.0
	var is_hero: bool = target_node.is_in_group("Hero")
	if _resting and not is_hero and not _is_attacking_me(target_node):
		return -1000.0
	if not is_hero and not _mob_threats.is_empty():
		return -1000.0  # a mob we cannot beat is on us: leave, don't farm beside it
	if not is_hero and strategy != Strategy.HUNT and target_node is EntityBase \
			and (target_node as EntityBase).get_max_health() > strategy_profile.max_mob_health_for_stage(current_stage):
		return -1000.0  # too tough to farm at this stage: walk on, it leashes home
	if is_hero and not _may_engage_hero(target_node):
		return -1000.0
	var score: float = super._score_target(target_node)
	match strategy:
		Strategy.FARM, Strategy.RETREAT:
			if not is_hero:
				score += 60.0 if _heroes_near == 0 else -200.0
		Strategy.HUNT:
			score += 50.0 if is_hero else -40.0
	return score


## Resting skips mob fights, but not mobs that are already going for us: a
## resting monster that only walked away could be pecked to death by Bats.
## Mobs above the farming gate still get walked away from (they leash home).
func _is_attacking_me(node: Node2D) -> bool:
	return node is EntityBase and (node as EntityBase).target_entity == self


## Mobs above the farming gate that are going for us. A stage-1 Grount cannot
## beat Hogs (fighting back lost more HP in the sim), and while it kept farming
## the Bats next to them, the Hogs killed it (~1 match in 8).
func _find_mob_threats(for_strategy: Strategy) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if for_strategy == Strategy.HUNT:
		return out
	var gate: float = strategy_profile.max_mob_health_for_stage(current_stage)
	for m in EntityRegistry.mobs:
		if is_instance_valid(m) and _is_attacking_me(m) and (m as EntityBase).get_max_health() > gate:
			out.append(m)
	return out


func _may_engage_hero(hero: Node2D) -> bool:
	var p := strategy_profile
	if global_position.distance_squared_to(hero.global_position) <= p.cornered_radius * p.cornered_radius:
		return true  # README "Desperation": cornered, fight back
	match strategy:
		Strategy.HUNT:
			return true
		Strategy.AMBUSH:
			if _resting:
				return false  # recover first; a cornered fight is handled above
			if EntityRegistry.count_within(EntityRegistry.heroes, hero.global_position, p.isolation_radius) <= p.ambush_max_heroes:
				return true
			if hero is EntityBase:
				var e := hero as EntityBase
				return e.get_max_health() > 0.0 and e.get_health() / e.get_max_health() < 0.3
			return false
		_:
			return false


func _get_smart_idle_destination() -> Vector2:
	if not _strategy_enabled():
		return super._get_smart_idle_destination()
	if ((strategy == Strategy.FARM or strategy == Strategy.RETREAT or _resting) and _heroes_near > 0) \
			or not _mob_threats.is_empty():
		return _get_flee_destination()
	if strategy == Strategy.HUNT:
		var prey: Node2D = EntityRegistry.nearest(EntityRegistry.heroes, global_position, strategy_profile.hunt_sense_radius)
		if prey:
			return prey.global_position
	elif _resting:
		return _get_rest_destination()
	else:
		var camp := _pick_camp()
		if camp:
			return camp.global_position
	return super._get_smart_idle_destination()


## Best world-eligible camp with mobs left and no hero close to it: more mobs
## and less distance score higher; the current goal is sticky.
func _pick_camp() -> MobSpawnArea:
	var mgr := EntityRegistry.singleton(&"SpawnManager") as SpawnManager
	if mgr == null:
		return null
	var p := strategy_profile
	var best: MobSpawnArea = null
	var best_score: float = -INF
	for camp in mgr.get_active_spawns():
		if not is_instance_valid(camp):
			continue
		var available: int = camp.spawned_mobs.size() + camp.virtual_count
		if available <= 0:
			continue
		if _camp_mob_health(camp) > p.max_mob_health_for_stage(current_stage):
			continue
		if EntityRegistry.count_within(EntityRegistry.heroes, camp.global_position, p.camp_hero_avoid_radius, 1) > 0:
			continue
		var score: float = available * 100.0 - global_position.distance_to(camp.global_position)
		if camp == _camp_goal:
			score += 150.0
		if score > best_score:
			best_score = score
			best = camp
	_camp_goal = best
	return best


## Stay put once clear of every camp with mobs left; otherwise step away from
## all camps within rest_camp_clearance at once (stepping away from only the
## nearest one ping-ponged between two camps).
func _get_rest_destination() -> Vector2:
	var mgr := EntityRegistry.singleton(&"SpawnManager") as SpawnManager
	if mgr == null:
		return global_position
	var clearance: float = strategy_profile.rest_camp_clearance
	var push := Vector2.ZERO
	for camp in mgr.get_active_spawns():
		if not is_instance_valid(camp) or camp.spawned_mobs.size() + camp.virtual_count <= 0:
			continue
		var off: Vector2 = global_position - camp.global_position
		var d: float = off.length()
		if d < clearance:
			push += off.normalized() * (clearance - d) if d > 0.001 else Vector2.from_angle(_facing_angle + PI)
	if push.length_squared() < 0.0001:
		return global_position
	var dest: Vector2 = global_position + push.normalized() * idle_wander_radius
	if not _is_on_nav_mesh(dest):
		return super._get_smart_idle_destination()
	return dest


## Max HP of the mobs a camp spawns (cached per mob scene; read from an
## instance that never enters the tree, so nothing registers).
static var _scene_mob_health: Dictionary = {}

func _camp_mob_health(camp: MobSpawnArea) -> float:
	if not camp.spawned_mobs.is_empty() and is_instance_valid(camp.spawned_mobs[0]):
		return camp.spawned_mobs[0].get_max_health()
	if camp.mob_scene == null:
		return 0.0
	var key: String = camp.mob_scene.resource_path
	if not _scene_mob_health.has(key):
		var probe := camp.mob_scene.instantiate() as MobBase
		_scene_mob_health[key] = probe.max_health if probe else 0.0
		if probe:
			probe.free()
	return float(_scene_mob_health[key])


## Flee candidates: headings off the straight-away direction, straight first,
## then alternating sides, tried at each fraction of idle_wander_radius in turn.
const FLEE_ANGLES_DEG: Array[float] = [0.0, -30.0, 30.0, -60.0, 60.0, -90.0, 90.0, -120.0, 120.0, -150.0, 150.0]
const FLEE_RADIUS_FACTORS: Array[float] = [1.0, 0.5]

## A reachable point away from the heroes close by (heroes outrun a stage-1
## monster, so hiding relies on breaking awareness early + the escape dash).
func _get_flee_destination() -> Vector2:
	var centroid := Vector2.ZERO
	var n: int = 0
	var r_sq: float = strategy_profile.hero_awareness_radius * strategy_profile.hero_awareness_radius
	for h in EntityRegistry.heroes:
		if is_instance_valid(h) and h.global_position.distance_squared_to(global_position) <= r_sq:
			centroid += h.global_position
			n += 1
	for m in _mob_threats:
		if is_instance_valid(m):
			centroid += m.global_position
			n += 1
	if n == 0:
		return super._get_smart_idle_destination()
	centroid /= float(n)
	var away: Vector2 = global_position - centroid
	away = away.normalized() if away.length_squared() > 0.0001 else Vector2.from_angle(_facing_angle + PI)
	# Widen the fan and shorten the step before giving up: against a wall the
	# straight-away candidates are all off the mesh, and returning our own
	# position froze the monster there while ranged heroes shot it.
	var best: Vector2 = global_position
	var best_d: float = -1.0
	var wander: float = idle_wander_radius
	for factor: float in FLEE_RADIUS_FACTORS:
		var radius: float = wander * factor
		for deg: float in FLEE_ANGLES_DEG:
			var p2: Vector2 = global_position + away.rotated(deg_to_rad(deg)) * radius
			if not _is_on_nav_mesh(p2):
				continue
			var d: float = p2.distance_squared_to(centroid)
			if d > best_d:
				best_d = d
				best = p2
		if best_d >= 0.0:
			return best
	return super._get_smart_idle_destination()


## Irelia's taunt marks us with a TauntEffect child carrying the taunter.
func _get_taunter() -> Node2D:
	var fx: Node = get_node_or_null(^"TauntEffect")
	if fx == null:
		return null
	var t: Variant = fx.get_meta(&"taunter", null)
	if is_instance_valid(t) and t is Node2D:
		return t as Node2D
	return null


# ---------- combos ----------

func _is_busy() -> bool:
	if _cast_lock > 0.0:
		return true
	for a in [ability_1, ability_2, ability_3]:
		if a != null and (a as AbilityBase).is_channeling():
			return true
	return false


func _slam_ready() -> bool:
	return ability_3 != null and ability_3.is_unlocked_at(current_stage) and is_ability_ready("ability_3")


## Fight: Ground Slam when it would hit enough targets, else Front Cleave
## (aimed first: the cleave reads the sprite's facing).
func _choose_and_use_ability_combo() -> void:
	if _is_busy() or not is_target_valid():
		return
	if _slam_ready() and _count_slam_targets() >= strategy_profile.slam_min_targets:
		if _cast("ability_3", ability_3, target_entity):
			return
	if is_ability_ready("ability_1"):
		_aim_at_target()
		_cast("ability_1", ability_1, target_entity)


func _count_slam_targets() -> int:
	var reach: float = ability_3.get_reach()
	var center: Vector2 = target_entity.global_position  # the leap lands on the target
	var n: int = EntityRegistry.count_within(EntityRegistry.hero_side, center, reach)
	if strategy != Strategy.HUNT:
		n += EntityRegistry.count_within(EntityRegistry.mobs, center, reach)
	return n


func _aim_at_target() -> void:
	if not is_target_valid():
		return
	var dir: Vector2 = target.global_position - global_position
	if dir.length_squared() < 0.0001:
		return
	_facing_angle = dir.angle()
	if sprite:
		sprite.rotation = _facing_angle


## Approach: Ram Dash as a gap closer (lands in Cleave range with Cleave about
## to be ready). FARM keeps the dash for escapes.
func _try_gap_close() -> bool:
	var p := strategy_profile
	if ability_2 == null or not is_ability_ready("ability_2") or not is_target_valid():
		return false
	if strategy != Strategy.AMBUSH and strategy != Strategy.HUNT:
		return false
	if not target_entity.is_in_group("Hero") and not p.dash_on_mobs:
		return false
	# Cheap gates before the full score (this runs every Approach tick).
	var d: float = distance_to_target()
	if d < p.dash_min_range or d > ability_2.get_reach():
		return false
	if get_ability_cooldown("ability_1") > p.dash_cleave_window:
		return false
	# The target may have become off-limits since the last re-evaluation (a
	# second hero joined an ambushed one); the dash would land inside the
	# cornered radius and force the fight the strategy refused.
	if _score_target(target_entity) <= 0.0:
		return false
	_aim_at_target()
	return _cast("ability_2", ability_2, target_entity)


func _try_escape_dash() -> void:
	var p := strategy_profile
	if ability_2 == null or not is_ability_ready("ability_2") or _is_busy() or _get_taunter() != null:
		return
	if not (strategy == Strategy.RETREAT or (strategy == Strategy.FARM and _heroes_near >= p.retreat_min_heroes)):
		return
	var h: Node2D = EntityRegistry.nearest(EntityRegistry.heroes, global_position, p.escape_dash_radius)
	if h == null:
		return
	var away: Vector2 = global_position - h.global_position
	away = away.normalized() if away.length_squared() > 0.0001 else Vector2.RIGHT
	if not _is_on_nav_mesh(global_position + away * ability_2.get_reach()):
		return
	_facing_angle = away.angle()
	if sprite:
		sprite.rotation = _facing_angle
	_cast("ability_2", ability_2, null)


func _on_approach_state_processing(delta: float) -> void:
	if _strategy_enabled():
		if _is_busy():
			return  # a dash / leap is moving us
		if _try_gap_close():
			return
	super._on_approach_state_processing(delta)


func _on_fight_state_processing(delta: float) -> void:
	if _strategy_enabled() and _is_busy():
		return
	super._on_fight_state_processing(delta)

# ============================================
# Helper Methods
# ============================================

func get_stage() -> int:
	return current_stage

## Total XP (current_xp) at which the monster evolves next, meta upgrades
## included (999999 past the last stage). Read by the monster HUD.
func get_evolution_threshold() -> int:
	return _get_next_evolution_threshold()

func get_ability_cooldown(ability_name: String) -> float:
	return ability_cooldowns.get(ability_name, 0.0)

## 0.0 right after a cast, 1.0 when ready. Polled by the monster HUD
## (CooldownSource.Monster), like AbilitySystem.get_cooldown_progress.
func get_cooldown_progress(ability_name: String) -> float:
	var remaining: float = ability_cooldowns.get(ability_name, 0.0)
	var total: float = _cooldown_totals.get(ability_name, 0.0)
	if remaining <= 0.0 or total <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / total, 0.0, 1.0)

func is_ability_ready(ability_name: String) -> bool:
	return ability_cooldowns.get(ability_name, 0.0) <= 0.0

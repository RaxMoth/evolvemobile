extends TestCase

## The generic stat keys (README "Generic stat keys"): one apply site per key,
## neutral when no node is owned. Each test seeds a save with the node(s) that
## carry a key, spawns the entity frozen and checks the effect at its site:
##   damage_taken_mult          HeroBase._receive_damage
##   cooldown_mult              AbilitySystem (active and ultimate only)
##   start_level                HeroBase._ready
##   monster_damage_taken_mult  MonsterBase._receive_damage
##   monster_regen_mult         MonsterBase._update_rest
##   monster_cooldown_mult      MonsterBase._cast
##   monster_s3_damage_mult     MonsterBase.effective_ability_damage (Stage 3)
##   monster_start_xp           MonsterBase._ready (not scaled by Bloodhound)

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"

## The nodes this batch brought into the game: [tree, id, key, multiplicative].
const NODES: Array = [
	[&"hero_base", &"hb_armor", "damage_taken_mult", true],
	[&"hero_base", &"hb_cdr", "cooldown_mult", true],
	[&"hero_base", &"hb_startlvl", "start_level", false],
	[&"hero_irelia", &"ir_armor", "damage_taken_mult", true],
	[&"monster_base", &"mb_bark", "monster_damage_taken_mult", true],
	[&"monster_base", &"mb_regen", "monster_regen_mult", true],
	[&"monster_base", &"mb_cdr", "monster_cooldown_mult", true],
	[&"monster_base", &"mb_apex", "monster_s3_damage_mult", true],
	[&"monster_base", &"mb_headstart", "monster_start_xp", false],
	[&"monster_grount", &"g1_hide", "monster_damage_taken_mult", true],
]


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


## Purchases must never leak into later files: they spawn heroes and Grount
## and assert the stock numbers.
func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _own(tree_id: StringName, node_id: StringName, rank: int) -> void:
	PersistedData.set_skill_rank(tree_id, node_id, rank)


func _vlad(pos: Vector2 = Vector2.ZERO) -> HeroBase:
	return (await spawn_frozen(VLAD, pos)) as HeroBase


func _grount(pos: Vector2 = Vector2(2000, 0)) -> MonsterBase:
	return (await spawn_frozen(GROUNT, pos)) as MonsterBase


# ---------------------------------------------------------------- the data

func test_the_nodes_are_shown_and_carry_their_keys() -> void:
	for spec: Array in NODES:
		var t := MetaSkillManager.get_tree_def(spec[0])
		var n: MetaSkillNode = t.find_node(spec[1]) if t != null else null
		assert_true(n != null, "%s/%s exists" % [spec[0], spec[1]])
		if n == null:
			continue
		assert_false(n.hidden, "%s is part of the game" % n.id)
		assert_false(n.is_ability_node(), "%s is a stat key" % n.id)
		assert_eq(n.stat_name, spec[2], "%s's key" % n.id)
		assert_eq(n.stat_multiplicative, spec[3], "%s stacks %s" % [n.id, "multiplicatively" if spec[3] else "additively"])
		assert_false(n.effect_text(1).contains("{v}"), "%s: %s" % [n.id, n.effect_text(1)])
	# Nyxa's and Gorrak's copies of the keys have their code too.
	for spec: Array in [["monster_nyxa", &"ny_regen"], ["monster_gorrak", &"gk_bark"], ["monster_gorrak", &"gk_regen"]]:
		var t := load("res://Data/SkillTrees/%s.tres" % spec[0]) as MetaSkillTree
		assert_false(t.find_node(spec[1]).hidden, "%s/%s" % spec)


## Tempered Mail is bought like any node now: 4 ranks open tier 2 of the base
## tree, Iron Skin is its parent.
func test_tempered_mail_can_be_bought() -> void:
	if not require_isolated():
		return
	var tree := MetaSkillManager.TREE_HERO_BASE
	PersistedData.add_currency(PersistedData.GOLD, 5000)
	assert_eq(MetaSkillManager.node_state(tree, &"hb_armor"), MetaSkillManager.NodeState.TIER_GATED, "0 pts")
	for id: StringName in [&"t1_dmg", &"t1_dmg", &"t1_speed", &"t1_speed"]:
		assert_true(MetaSkillManager.rank_up(tree, id))
	assert_eq(MetaSkillManager.node_state(tree, &"hb_armor"), MetaSkillManager.NodeState.REQUIRES_MISSING, "needs Iron Skin")
	assert_true(MetaSkillManager.rank_up(tree, &"t1_hp"))
	assert_true(MetaSkillManager.rank_up(tree, &"hb_armor"))
	assert_eq(MetaSkillManager.next_rank_cost(tree, &"hb_armor"), 160, "rank 2 of G2x3")
	assert_eq(MetaSkillManager.applied_ranks(tree).get(&"hb_armor", 0), 1)


# ---------------------------------------------------------------- fresh save

func test_every_key_is_neutral_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var vlad := await _vlad()
	var g := await _grount()
	assert_eq(vlad.stats.get_damage_taken_multiplier(), 1.0)
	assert_eq(vlad.stats.get_cooldown_multiplier(), 1.0)
	assert_eq(vlad.stats.get_start_level(), 1)
	assert_eq(vlad.stats.level, 1)
	assert_eq(vlad.debug_keys_line(), "tree keys: -")
	assert_eq(g.debug_keys_line(), "tree keys: -")
	assert_eq(g._meta_damage_taken_mult, 1.0)
	assert_eq(g._meta_regen_mult, 1.0)
	assert_eq(g._meta_cooldown_mult, 1.0)
	assert_eq(g._meta_final_stage_damage_mult, 1.0)
	assert_eq(g._meta_start_xp, 0.0)
	assert_eq(g.current_xp, 0.0)
	assert_true(g.debug_meta_line().ends_with("nodes: -"), g.debug_meta_line())
	var hp: float = vlad.get_health()
	assert_eq(EventBus.deal_damage(null, vlad, 10.0), 10.0, "a hit lands whole")
	assert_eq(vlad.get_health(), hp - 10.0)
	vlad.queue_free()
	g.queue_free()


# ---------------------------------------------------------------- hero keys

## Tempered Mail -10% (rank 3) and Irelia's Plated -5% (rank 1) multiply; the
## pipeline returns, and its listeners see, the reduced amount.
func test_damage_taken_mult_scales_every_hit_on_a_hero() -> void:
	if not require_isolated():
		return
	_own(&"hero_base", &"hb_armor", 3)
	_own(&"hero_irelia", &"ir_armor", 1)
	var vlad := await _vlad()
	var irelia := (await spawn_frozen(IRELIA, Vector2(0, 600))) as HeroBase
	assert_near(vlad.stats.get_damage_taken_multiplier(), 0.90, 0.0001, "base tree only")
	assert_near(irelia.stats.get_damage_taken_multiplier(), 0.90 * 0.95, 0.0001, "base tree x her own")
	var seen: Array[float] = []
	var listener := func(p: DamagePacket) -> void: seen.append(p.amount)
	EventBus.damage_applied.connect(listener)
	var hp: float = vlad.get_health()
	assert_near(EventBus.deal_damage(null, vlad, 100.0), 90.0, 0.0001, "the amount that landed")
	assert_near(vlad.get_health(), hp - 90.0, 0.0001)
	hp = irelia.get_health()
	EventBus.deal_damage(null, irelia, 100.0)
	assert_near(irelia.get_health(), hp - 85.5, 0.0001)
	EventBus.damage_applied.disconnect(listener)
	assert_eq(seen.size(), 2)
	if seen.size() == 2:
		assert_near(seen[0], 90.0, 0.0001, "damage_applied carries the final amount")
	assert_true(vlad.debug_keys_line().contains("dmg taken x0.90"), vlad.debug_keys_line())
	vlad.queue_free()
	irelia.queue_free()


## Battle Drills -15% (rank 2): the active and the ultimate start shorter (and
## the HUD's total with them); the basic attack keeps its cooldown.
func test_cooldown_mult_shortens_the_active_and_the_ultimate() -> void:
	if not require_isolated():
		return
	_own(&"hero_base", &"hb_cdr", 2)
	var vlad := await _vlad()
	var asys := vlad.ability_system
	var active := AbilityBase.AbilityType.ACTIVE
	var ult := AbilityBase.AbilityType.ULTIMATE
	var basic := AbilityBase.AbilityType.BASIC_ATTACK
	assert_true(asys.use_active(null), "mine")
	assert_near(asys.cooldowns[active], asys.active_ability.cooldown * 0.85, 0.0001)
	assert_near(asys.get_cooldown_progress(active), 0.0, 0.0001, "total = the shortened cooldown")
	assert_true(asys.use_ultimate(null), "Blood Bomb")
	assert_near(asys.cooldowns[ult], asys.ultimate_ability.cooldown * 0.85, 0.0001)
	assert_true(asys.use_basic_attack(null), "a swing at nothing still starts the cooldown")
	assert_near(asys.cooldowns[basic], asys.basic_attack.cooldown, 0.0001, "attack speed covers the basic attack")
	assert_near(asys.active_ability.cooldown, (load("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Abilities/active/active_mine.tres") as AbilityBase).cooldown,
		0.0001, "the ability's own number is untouched")
	# The F3 overlay shows the followed hero's keys above its abilities.
	var overlay := DebugOverlay.new()
	add_child(overlay)
	await wait_frames(1)
	overlay._update_hud_label(vlad, null, null)
	assert_true(overlay._hud_label.text.contains("  tree keys: cd x0.85"), overlay._hud_label.text)
	overlay.queue_free()
	vlad.queue_free()


## Veteran Squad: Level 2 at spawn with its growth on top of the % nodes, full
## HP, the label showing it; in-round XP starts from zero.
func test_start_level_starts_heroes_at_level_2() -> void:
	if not require_isolated():
		return
	_own(&"hero_base", &"hb_startlvl", 1)
	_own(&"hero_base", &"t1_hp", 1)
	var vlad := await _vlad()
	var base := vlad.stats.base_stats
	assert_eq(vlad.stats.level, 2)
	assert_eq(vlad.stats.current_xp, 0.0)
	assert_near(vlad.get_max_health(), (base.base_max_health + base.health_per_level) * 1.05, 0.001, "Lv 2 growth, then Iron Skin")
	assert_eq(vlad.get_health(), vlad.get_max_health(), "full HP")
	assert_near(vlad.stats.get_attack_damage(), base.base_attack_damage + base.damage_per_level, 0.001)
	assert_eq(vlad.lv_label.text, "2")
	assert_eq(vlad.debug_keys_line(), "tree keys: start Lv 2")
	vlad.gain_xp(HeroStatsComponent.XP_PER_LEVEL)
	assert_eq(vlad.stats.level, 3, "leveling goes on from there")
	vlad.queue_free()


# ---------------------------------------------------------------- monster keys

## Scarred Hide -10% (rank 3) and Grount's Thick Hide -10% (rank 5) multiply.
func test_monster_damage_taken_mult_scales_every_hit() -> void:
	if not require_isolated():
		return
	_own(&"monster_base", &"mb_bark", 3)
	_own(&"monster_grount", &"g1_hide", 5)
	var mods: Dictionary = MetaSkillManager.collect_monster_modifiers(&"grount")
	assert_near(float(mods.get("monster_damage_taken_mult", 1.0)), 0.81, 0.0001)
	var g := await _grount()
	var hp: float = g.get_health()
	assert_near(EventBus.deal_damage(null, g, 100.0), 81.0, 0.0001, "the amount that landed")
	assert_near(g.get_health(), hp - 81.0, 0.0001)
	assert_eq(g.debug_keys_line(), "tree keys: dmg taken x0.81")
	g.queue_free()


## Primal Regeneration: resting regenerates twice as fast.
func test_monster_regen_mult_speeds_rest_regeneration() -> void:
	if not require_isolated():
		return
	_own(&"monster_base", &"mb_regen", 1)
	var g := await _grount()
	var max_hp: float = g.get_max_health()
	g.strategy = MonsterBase.Strategy.FARM
	g.current_health = max_hp * 0.1
	g._since_damage = 100.0
	g._update_rest(1.0)
	assert_true(g.is_resting(), "low HP, out of combat")
	assert_near(g.get_health() - max_hp * 0.1, max_hp * g.strategy_profile.rest_regen_pct_per_sec * 2.0, 0.0001)
	assert_eq(g.debug_keys_line(), "tree keys: regen x2.00")
	g.queue_free()


## Primal Rhythm -10% (rank 2): every cast starts its cooldown shorter, on
## top of the stage's own cooldown.
func test_monster_cooldown_mult_shortens_every_cast() -> void:
	if not require_isolated():
		return
	_own(&"monster_base", &"mb_cdr", 2)
	var g := await _grount()
	var cleave: AbilityBase = g.ability_1
	assert_true(g._cast("ability_1", cleave, null))
	assert_near(g.get_ability_cooldown("ability_1"), cleave.cooldown_per_stage[0] * 0.90, 0.0001)
	assert_near(g.get_cooldown_progress("ability_1"), 0.0, 0.0001, "total = the shortened cooldown")
	g.gain_xp(g.get_evolution_threshold())
	assert_eq(g.current_stage, 2, "evolving resets the cooldowns")
	assert_true(g._cast("ability_1", cleave, null))
	assert_near(g.get_ability_cooldown("ability_1"), cleave.cooldown_per_stage[1] * 0.90, 0.0001)
	assert_eq(g.debug_keys_line(), "tree keys: cd x0.90")
	g.queue_free()


## Apex Predator +15%: only at the final stage, under Enrage's multiplier.
func test_monster_s3_damage_mult_applies_at_stage_3() -> void:
	if not require_isolated():
		return
	_own(&"monster_base", &"mb_apex", 1)
	var g := await _grount()
	assert_near(g.effective_ability_damage(g.ability_1), g.ability_1.damage, 0.0001, "Stage 1: Front Cleave's table value")
	g.gain_xp(1000.0)
	g.gain_xp(0.0)
	assert_eq(g.current_stage, MonsterBase.FINAL_STAGE)
	assert_eq(g.debug_keys_line(), "tree keys: apex x1.15!")
	var with_apex: Array[float] = []
	for a: AbilityBase in [g.ability_1, g.ability_2, g.ability_3]:
		with_apex.append(g.effective_ability_damage(a))
	# The same casts without the node (an instance field, not shared data).
	g._meta_final_stage_damage_mult = 1.0
	var abilities: Array[AbilityBase] = [g.ability_1, g.ability_2, g.ability_3]
	for i in abilities.size():
		assert_near(with_apex[i], g.effective_ability_damage(abilities[i]) * 1.15, 0.0001, abilities[i].ability_name)
	assert_near(g.effective_ability_damage(g.ability_1), g.ability_1.damage, 0.0001, "Stage 3: the table value alone")
	g.queue_free()


## Head Start: 60 XP at spawn, not scaled by Bloodhound (+10%), which still
## scales what is gained afterwards.
func test_monster_start_xp_is_banked_at_spawn() -> void:
	if not require_isolated():
		return
	_own(&"monster_base", &"mb_headstart", 1)
	_own(&"monster_base", &"mt1_xp", 1)
	var g := await _grount()
	assert_eq(g.current_xp, 60.0)
	assert_eq(g.current_stage, 1)
	g.gain_xp(10.0)
	assert_near(g.current_xp, 71.0, 0.0001, "60 + 10 x 1.10")
	assert_eq(g.debug_keys_line(), "tree keys: xp +60")
	g.gain_xp(g.get_evolution_threshold())
	assert_eq(g.current_stage, 2, "the next gain checks evolution")
	g.queue_free()

extends TestCase

## The hero behaviour and capstone nodes (README "Hero capstones and behaviour
## nodes"): every new ability export is off on a fresh save and does its job on
## a seeded save, on the hero's own ability copy (the shared .tres is never
## touched). Only a tree's equipped capstone applies.

const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const IRELIA_TREE := &"hero_irelia"
const VLAD_TREE := &"hero_vlad"

## [tree, node, ability, export, the export's off value] of every node that
## reaches a hero's ability through an export of its own.
const NODES: Array = [
	[&"hero_irelia", &"ir_laststand", "Regeneration", "last_stand", false],
	[&"hero_irelia", &"ir_guardian", "Divine Shield", "cleanse_stuns", false],
	[&"hero_irelia", &"ir_banner", "Monster Taunt", "rally_radius", 0.0],
	[&"hero_vlad", &"vl_execute", "Blood Strike", "execute_threshold", 0.0],
	[&"hero_vlad", &"vl_leech", "Blood Strike", "lifesteal_pct", 0.0],
	[&"hero_vlad", &"vl_cluster", "Land Mine", "mine_count", 1],
]


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


## Purchases must never leak into later files: they spawn heroes and assert
## the stock numbers.
func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _own(tree_id: StringName, node_id: StringName, rank: int = 1) -> void:
	PersistedData.set_skill_rank(tree_id, node_id, rank)


func _hero(path: String, pos: Vector2) -> HeroBase:
	return (await spawn_frozen(path, pos)) as HeroBase


func _abilities(hero: Node) -> AbilitySystem:
	return hero.get_node("AbilitySystem") as AbilitySystem


func _hog(pos: Vector2) -> MobBase:
	return (await spawn_frozen(HOG, pos)) as MobBase


## The Mine nodes a cast added under the test (Vlad's parent), in cast order.
func _new_mines(before: Array[Node]) -> Array[Mine]:
	var out: Array[Mine] = []
	for n in get_children():
		if n is Mine and not before.has(n):
			out.append(n as Mine)
	return out


func _free(nodes: Array) -> void:
	for n: Variant in nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()


# ---------------------------------------------------------------- the data

func test_the_nodes_are_shown_and_reach_an_export() -> void:
	for spec: Array in NODES:
		var t := MetaSkillManager.get_tree_def(spec[0])
		var n: MetaSkillNode = t.find_node(spec[1]) if t != null else null
		assert_true(n != null, "%s/%s exists" % [spec[0], spec[1]])
		if n == null:
			continue
		assert_false(n.hidden, "%s is part of the game" % n.id)
		assert_eq(n.ability_name, String(spec[2]), "%s's ability" % n.id)
		assert_eq(n.stat_name, String(spec[3]), "%s's export" % n.id)
		assert_false(n.effect_text(1).contains("{v}"), "%s: %s" % [n.id, n.effect_text(1)])
		var kit: AbilityBase = null
		for d in GameManager.ROSTER.all():
			for a in d.abilities():
				if a.ability_name == n.ability_name:
					kit = a
		assert_true(kit != null and n.stat_name in kit, "%s: %s has %s" % [n.id, n.ability_name, n.stat_name])
		if kit != null and n.stat_name in kit:
			assert_eq(kit.get(n.stat_name), spec[4], "%s: the shared resource keeps it off" % n.id)


# ---------------------------------------------------------------- Irelia

## A fresh save: a lethal hit kills, the shield leaves stuns alone and the
## taunt hastes no one.
func test_irelias_exports_are_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var irelia := await _hero(IRELIA, Vector2.ZERO)
	var vlad := await _hero(VLAD, Vector2(100, 0))
	var kit := _abilities(irelia)
	assert_false((kit.passive_ability as IreliaPassiveRegeneration).last_stand)
	assert_false((kit.active_ability as IreliaActiveShield).cleanse_stuns)
	assert_eq((kit.ultimate_ability as IreliaUltimateTaunt).rally_radius, 0.0)
	vlad.apply_stun(3.0)
	kit.active_ability.execute(irelia)
	assert_true(vlad.is_stunned(), "the shield does not break stuns")
	kit.ultimate_ability.execute(irelia)
	assert_eq(vlad.get_attack_speed_boost(), 1.0, "the taunt hastes no one")
	EventBus.deal_damage(null, irelia, irelia.get_health() + 50.0)
	assert_false(irelia.is_alive(), "a lethal hit kills")
	_free([irelia, vlad])


## Last Stand: the lethal hit leaves 1 HP, every hit in the next 2 s is
## canceled (nothing lands, no damage_applied), and it works once per match.
func test_last_stand_saves_irelia_once_per_match() -> void:
	if not require_isolated():
		return
	_own(IRELIA_TREE, &"ir_laststand")
	var irelia := await _hero(IRELIA, Vector2.ZERO)
	var regen := _abilities(irelia).passive_ability as IreliaPassiveRegeneration
	assert_true(regen.last_stand, "on her own copy")
	var hp: float = irelia.get_health()
	assert_near(EventBus.deal_damage(null, irelia, hp + 50.0), hp - 1.0, 0.0001, "the hit lands down to 1 HP")
	assert_near(irelia.get_health(), 1.0, 0.0001)
	assert_true(irelia.is_alive())
	assert_true(irelia.is_invulnerable())
	assert_eq(active_state_of(irelia), "Idle", "no Dead state")
	var landed: Array[float] = []
	var listener := func(p: DamagePacket) -> void:
		if p.target == irelia:
			landed.append(p.amount)
	EventBus.damage_applied.connect(listener)
	assert_eq(EventBus.deal_damage(null, irelia, 500.0), 0.0, "canceled while invulnerable")
	assert_true(irelia.get_health() >= 1.0 and irelia.get_health() < 2.0, "only her regen moves HP: %s" % irelia.get_health())
	assert_eq(landed, [] as Array[float], "a canceled hit reaches no damage_applied listener")
	assert_true(regen.debug_line().ends_with("last stand spent"), regen.debug_line())
	await wait_seconds(regen.last_stand_duration + 0.1)
	assert_false(irelia.is_invulnerable(), "2 s later she can be hurt again")
	irelia.heal(irelia.get_max_health())
	assert_near(EventBus.deal_damage(null, irelia, 30.0), 30.0, 0.0001, "hits land again")
	assert_eq(landed.size(), 1)
	EventBus.damage_applied.disconnect(listener)
	EventBus.deal_damage(null, irelia, 9999.0)
	assert_false(irelia.is_alive(), "once per match: the next lethal hit kills")
	_free([irelia])


## Guardian Angel: Divine Shield ends the stun of every hero it shields.
func test_guardian_angel_breaks_every_stun() -> void:
	if not require_isolated():
		return
	_own(IRELIA_TREE, &"ir_guardian")
	var irelia := await _hero(IRELIA, Vector2.ZERO)
	var vlad := await _hero(VLAD, Vector2(900, 0))
	var shield := _abilities(irelia).active_ability as IreliaActiveShield
	assert_true(shield.cleanse_stuns)
	irelia.apply_stun(3.0)
	vlad.apply_stun(3.0)
	shield.execute(irelia)
	assert_false(vlad.is_stunned(), "an ally's stun ends")
	assert_false(irelia.is_stunned(), "and hers")
	assert_true(vlad.has_node(^"Shield"), "the shield still lands")
	_free([irelia, vlad])


## Rallying Taunt: heroes within 250 px of Irelia (herself included) attack
## 25% faster while the taunt lasts; a hero further out does not.
func test_rallying_taunt_hastes_the_heroes_around_irelia() -> void:
	if not require_isolated():
		return
	_own(IRELIA_TREE, &"ir_banner")
	var irelia := await _hero(IRELIA, Vector2.ZERO)
	var vlad := await _hero(VLAD, Vector2(200, 0))
	var river := await _hero(RIVER, Vector2(0, 400))
	var taunt := _abilities(irelia).ultimate_ability as IreliaUltimateTaunt
	assert_eq(taunt.rally_radius, 250.0)
	var base_speed: float = _abilities(vlad).get_attack_speed_multiplier()
	taunt.execute(irelia)
	assert_near(irelia.get_attack_speed_boost(), 1.25, 0.0001)
	assert_near(vlad.get_attack_speed_boost(), 1.25, 0.0001)
	assert_near(_abilities(vlad).get_attack_speed_multiplier(), base_speed * 1.25, 0.0001, "reaches the basic attack")
	assert_eq(river.get_attack_speed_boost(), 1.0, "400 px away")
	await wait_seconds(taunt.duration + 0.1)
	assert_eq(vlad.get_attack_speed_boost(), 1.0, "ends with the taunt")
	_free([irelia, vlad, river])


## A weaker haste never cuts a stronger one short (Rally Cry 1.5 over a
## Rallying Taunt 1.25); an equal or stronger one restarts it.
func test_a_weaker_haste_never_replaces_a_stronger_one() -> void:
	var vlad := await _hero(VLAD, Vector2.ZERO)
	vlad.apply_attack_speed_boost(1.5, 1.0)
	vlad.apply_attack_speed_boost(1.25, 5.0)
	assert_eq(vlad.get_attack_speed_boost(), 1.5)
	await wait_seconds(1.1)
	assert_eq(vlad.get_attack_speed_boost(), 1.0, "the stronger one ran out on its own timer")
	vlad.apply_attack_speed_boost(1.25, 1.0)
	vlad.apply_attack_speed_boost(1.5, 1.0)
	assert_eq(vlad.get_attack_speed_boost(), 1.5, "a stronger one takes over")
	_free([vlad])


## Several capstones owned: only the equipped one reaches her copies.
func test_only_the_equipped_capstone_applies() -> void:
	if not require_isolated():
		return
	_own(IRELIA_TREE, &"ir_laststand")
	_own(IRELIA_TREE, &"ir_banner")
	PersistedData.set_equipped_capstone(IRELIA_TREE, &"ir_banner")
	var irelia := await _hero(IRELIA, Vector2.ZERO)
	var kit := _abilities(irelia)
	assert_false((kit.passive_ability as IreliaPassiveRegeneration).last_stand, "owned, not equipped")
	assert_eq((kit.ultimate_ability as IreliaUltimateTaunt).rally_radius, 250.0)
	_free([irelia])


# ---------------------------------------------------------------- Vlad

## A fresh save: one mine under Vlad, no execute bonus, no lifesteal.
func test_vlads_exports_are_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var vlad := await _hero(VLAD, Vector2.ZERO)
	var hog := await _hog(Vector2(3000, 0))
	var kit := _abilities(vlad)
	var strike := kit.basic_attack as BasicStrike
	var mine_ability := kit.active_ability as VladActiveMine
	assert_eq(strike.execute_threshold, 0.0)
	assert_eq(strike.lifesteal_pct, 0.0)
	assert_eq(mine_ability.mine_count, 1)
	var before: Array[Node] = get_children()
	mine_ability.execute(vlad)
	var mines := _new_mines(before)
	assert_eq(mines.size(), 1, "one mine")
	if mines.size() == 1:
		assert_eq(mines[0].global_position, vlad.global_position, "under Vlad")
	_free(mines)
	await wait_frames(1)
	hog.global_position = Vector2(30, 0)
	hog.current_health = hog.max_health * 0.2
	vlad.stats.take_damage(40.0)
	var vlad_hp: float = vlad.get_health()
	var hog_hp: float = hog.get_health()
	strike.execute(vlad, hog)
	assert_near(hog_hp - hog.get_health(), strike.damage * kit.get_damage_multiplier(), 0.0001, "no execute bonus")
	assert_eq(vlad.get_health(), vlad_hp, "no lifesteal")
	_free([vlad, hog])


## Executioner's Mark: Blood Strike deals x2 to a target below 25% HP.
func test_executioners_mark_doubles_blood_strike_on_a_wounded_target() -> void:
	if not require_isolated():
		return
	_own(VLAD_TREE, &"vl_execute")
	var vlad := await _hero(VLAD, Vector2.ZERO)
	var hog := await _hog(Vector2(30, 0))
	var kit := _abilities(vlad)
	var strike := kit.basic_attack as BasicStrike
	assert_near(strike.execute_threshold, 0.25, 0.0001)
	var shared := load("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Abilities/basic_attack/basic_attack.tres") as BasicStrike
	assert_eq(shared.execute_threshold, 0.0, "the shared resource is untouched")
	var hit: float = strike.damage * kit.get_damage_multiplier()
	var hits: Array[float] = []
	var listener := func(p: DamagePacket) -> void:
		if p.source == vlad:
			hits.append(p.amount)
	EventBus.damage_applied.connect(listener)
	strike.execute(vlad, hog)
	hog.current_health = hog.max_health * 0.26
	strike.execute(vlad, hog)
	hog.current_health = hog.max_health * 0.2
	strike.execute(vlad, hog)
	EventBus.damage_applied.disconnect(listener)
	assert_eq(hits.size(), 3)
	if hits.size() == 3:
		assert_near(hits[0], hit, 0.0001, "full HP")
		assert_near(hits[1], hit, 0.0001, "26% HP")
		assert_near(hits[2], hit * 2.0, 0.0001, "20% HP: x2")
	_free([vlad, hog])


## Sanguine Feast: Blood Strike heals Vlad for 20% of the damage that landed
## (AbilityBase.deal -> HeroBase.heal_self); a dead hero is never healed.
func test_sanguine_feast_heals_vlad_for_a_fifth_of_blood_strike() -> void:
	if not require_isolated():
		return
	_own(VLAD_TREE, &"vl_leech")
	var vlad := await _hero(VLAD, Vector2.ZERO)
	var hog := await _hog(Vector2(30, 0))
	var kit := _abilities(vlad)
	var strike := kit.basic_attack as BasicStrike
	assert_near(strike.lifesteal_pct, 0.2, 0.0001)
	vlad.stats.take_damage(40.0)
	var hp: float = vlad.get_health()
	var hit: float = strike.damage * kit.get_damage_multiplier()
	strike.execute(vlad, hog)
	assert_near(vlad.get_health(), hp + hit * 0.2, 0.0001, "healed for 20% of the hit")
	assert_near(strike.deal(vlad, hog, 0.0), 0.0, 0.0001, "nothing landed, nothing healed")
	assert_near(vlad.get_health(), hp + hit * 0.2, 0.0001)
	vlad.stats.take_damage(9999.0)
	vlad.heal_self(50.0)
	assert_eq(vlad.get_health(), 0.0, "no lifesteal back from the dead")
	_free([vlad, hog])


## Cluster Mines: three mines in a triangle around Vlad, 40 px apart, each
## a full Land Mine.
func test_cluster_mines_places_three_mines_40_px_apart() -> void:
	if not require_isolated():
		return
	_own(VLAD_TREE, &"vl_cluster")
	var vlad := await _hero(VLAD, Vector2(100, 100))
	var mine_ability := _abilities(vlad).active_ability as VladActiveMine
	assert_eq(mine_ability.mine_count, 3, "1 x 3")
	var before: Array[Node] = get_children()
	mine_ability.execute(vlad)
	var mines := _new_mines(before)
	assert_eq(mines.size(), 3)
	if mines.size() == 3:
		var centre := Vector2.ZERO
		for i in 3:
			centre += mines[i].global_position / 3.0
			assert_near(mines[i].global_position.distance_to(mines[(i + 1) % 3].global_position), 40.0, 0.01, "neighbours 40 px apart")
			assert_eq(mines[i].damage, mine_ability.damage)
			assert_eq(mines[i].owner_entity, vlad)
		assert_true(centre.distance_to(vlad.global_position) < 0.01, "around Vlad")
	_free(mines)
	_free([vlad])

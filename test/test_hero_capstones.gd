extends TestCase

## The hero behaviour and capstone nodes (README "Hero capstones and behaviour
## nodes"): every new ability export is off on a fresh save and does its job on
## a seeded save, on the hero's own ability copy (the shared .tres is never
## touched). Only a tree's equipped capstone applies.

const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const IRELIA_TREE := &"hero_irelia"
const VLAD_TREE := &"hero_vlad"
const TED_TREE := &"hero_ted"
const RIVER_TREE := &"hero_river"

## [tree, node, ability, export, the export's off value] of every node that
## reaches a hero's ability through an export of its own.
const NODES: Array = [
	[&"hero_irelia", &"ir_laststand", "Regeneration", "last_stand", false],
	[&"hero_irelia", &"ir_guardian", "Divine Shield", "cleanse_stuns", false],
	[&"hero_irelia", &"ir_banner", "Monster Taunt", "rally_radius", 0.0],
	[&"hero_vlad", &"vl_execute", "Blood Strike", "execute_threshold", 0.0],
	[&"hero_vlad", &"vl_leech", "Blood Strike", "lifesteal_pct", 0.0],
	[&"hero_vlad", &"vl_cluster", "Land Mine", "mine_count", 1],
	[&"hero_ted", &"td_warcry", "Rally Cry", "aura_radius", 0.0],
	[&"hero_ted", &"td_petvit", "Loyal Companion", "pet_health_mult", 1.0],
	[&"hero_ted", &"td_petdmg", "Loyal Companion", "pet_damage_mult", 1.0],
	[&"hero_ted", &"td_respawn", "Loyal Companion", "respawn_time", 10.0],
	[&"hero_ted", &"td_twin", "Loyal Companion", "pet_count", 1],
	[&"hero_ted", &"td_spikes", "Trap Cage", "cage_dps", 0.0],
	[&"hero_river", &"rv_deadeye", "Adaptive Weapon", "crit_every", 0],
	[&"hero_river", &"rv_chain", "Adaptive Weapon", "extra_heal_targets", 0],
	[&"hero_river", &"rv_pathfinder", "Adaptive Movement", "team_speed_aura", 1.0],
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


## The TrapCage a cast added under the test (Ted's parent), or null.
func _new_cage(before: Array[Node]) -> TrapCage:
	for n in get_children():
		if n is TrapCage and not before.has(n):
			return n as TrapCage
	return null


func _pet_passive(ted: Node) -> TedPassivePet:
	return _abilities(ted).passive_ability as TedPassivePet


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


# ---------------------------------------------------------------- Ted

## A fresh save: one stock pet back after 10 s, Rally Cry hastes only Ted
## and his pet, the cage lasts the ability's 6 s and has no spikes.
func test_teds_exports_are_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var ted := await _hero(TED, Vector2.ZERO)
	var vlad := await _hero(VLAD, Vector2(200, 0))
	var passive := _pet_passive(ted)
	assert_eq(passive.pet_count, 1)
	assert_eq(passive.respawn_time, 10.0)
	assert_eq(passive.pets.size(), 1)
	var pets := (ted as Ted).get_pets()
	assert_eq(pets.size(), 1, "one pet")
	if pets.size() == 1:
		assert_eq(pets[0].max_health, 50.0)
		assert_eq(pets[0].attack_damage, 9.0)
	assert_eq(passive.pet_offset(0), Vector2(30, 0), "where the one pet always appeared")
	var kit := _abilities(ted)
	kit.active_ability.execute(ted)
	assert_near(ted.get_attack_speed_boost(), 1.5, 0.0001)
	if pets.size() == 1:
		assert_near(pets[0]._boost_mult, 1.5, 0.0001, "and his pet")
	assert_eq(vlad.get_attack_speed_boost(), 1.0, "nobody else")
	var ult := kit.ultimate_ability as TedUltimateTrapCage
	assert_eq(ult.duration, 6.0, "the cage's own 6 s, now in the data")
	assert_eq(ult.cage_dps, 0.0)
	var before: Array[Node] = get_children()
	ult.execute(ted, vlad)
	var cage := _new_cage(before)
	assert_true(cage != null)
	if cage != null:
		assert_eq(cage.duration, 6.0)
		assert_eq(cage.cage_dps, 0.0)
	_free([ted, vlad, cage])


## War Cry: Rally Cry hastes every other hero within 300 px too.
func test_war_cry_hastes_the_heroes_around_ted() -> void:
	if not require_isolated():
		return
	_own(TED_TREE, &"td_warcry")
	var ted := await _hero(TED, Vector2.ZERO)
	var vlad := await _hero(VLAD, Vector2(250, 0))
	var river := await _hero(RIVER, Vector2(0, 400))
	var rally := _abilities(ted).active_ability as TedActiveRally
	assert_eq(rally.aura_radius, 300.0)
	rally.execute(ted)
	assert_near(ted.get_attack_speed_boost(), 1.5, 0.0001)
	assert_near(vlad.get_attack_speed_boost(), 1.5, 0.0001, "250 px away")
	assert_eq(river.get_attack_speed_boost(), 1.0, "400 px away")
	await wait_seconds(rally.boost_duration + 0.1)
	assert_eq(vlad.get_attack_speed_boost(), 1.0, "for Rally Cry's 5 s")
	_free([ted, vlad, river])


## Loyal Bond, Sharp Fangs and Never Alone scale the pet Ted spawns (on his
## own passive copy) and its respawn.
func test_beastmaster_nodes_scale_the_pet() -> void:
	if not require_isolated():
		return
	_own(TED_TREE, &"td_petvit", 3)
	_own(TED_TREE, &"td_petdmg", 2)
	_own(TED_TREE, &"td_respawn", 1)
	var ted := await _hero(TED, Vector2.ZERO)
	var passive := _pet_passive(ted)
	assert_near(passive.pet_health_mult, 1.6, 0.0001)
	assert_near(passive.pet_damage_mult, 1.4, 0.0001)
	assert_near(passive.respawn_time, 7.0, 0.0001, "30% faster")
	var shared := load("res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/ted_passive.tres") as TedPassivePet
	assert_eq(shared.respawn_time, 10.0, "the shared resource is untouched")
	var pets := (ted as Ted).get_pets()
	assert_eq(pets.size(), 1)
	if pets.size() == 1:
		assert_near(pets[0].max_health, 80.0, 0.0001)
		assert_near(pets[0].current_health, 80.0, 0.0001, "spawns at full HP")
		assert_near(pets[0].attack_damage, 12.6, 0.0001)
		EventBus.deal_damage(null, pets[0], 9999.0)
	await wait_frames(1)
	assert_near(passive.respawn_timers[0], 7.0, 0.05, "back in 7 s")
	_free([ted])


## Pack of Two: two pets on opposite sides of Ted; each slot has its own
## respawn timer, so one death leaves the other pet alone.
func test_pack_of_two_keeps_two_pets_with_a_timer_each() -> void:
	if not require_isolated():
		return
	_own(TED_TREE, &"td_twin")
	_own(TED_TREE, &"td_respawn", 3)
	var ted := await _hero(TED, Vector2.ZERO)
	var passive := _pet_passive(ted)
	assert_eq(passive.pet_count, 2, "1 x 2")
	assert_eq(passive.pets.size(), 2)
	assert_eq((ted as Ted).get_pets().size(), 2, "both spawned at once")
	assert_true(passive.pet_offset(1).is_equal_approx(Vector2(-30, 0)), "the second on Ted's other side")
	var first: TedPassivePet.PetScript = passive.pets[0]
	var second: TedPassivePet.PetScript = passive.pets[1]
	EventBus.deal_damage(null, first, 9999.0)
	await wait_frames(2)
	assert_false(is_instance_valid(first))
	assert_true(passive.pets[0] == null, "slot 0 waits")
	assert_true(is_instance_valid(second) and passive.pets[1] == second, "slot 1 keeps its pet")
	assert_true(passive.respawn_timers[0] > 0.0)
	assert_true(passive.respawn_timers[1] <= 0.0, "only the dead pet's timer runs")
	assert_true(passive.debug_line().contains("pets 1/2"), passive.debug_line())
	await wait_seconds(passive.respawn_time + 0.2)
	assert_eq((ted as Ted).get_pets().size(), 2, "back after respawn_time")
	assert_true(passive.pets[1] == second, "the same second pet")
	_free([ted])
	for pet in passive.pets:
		_free([pet])


## Spiked Cage: once a second every enemy inside the cage takes 6 damage
## from Ted's Trap Cage; heroes inside are left alone.
func test_spiked_cage_hurts_the_enemies_inside() -> void:
	if not require_isolated():
		return
	_own(TED_TREE, &"td_spikes")
	var ted := await _hero(TED, Vector2.ZERO)
	var hog := await _hog(Vector2(2000, 0))
	var vlad := await _hero(VLAD, Vector2(2040, 0))
	var ult := _abilities(ted).ultimate_ability as TedUltimateTrapCage
	assert_eq(ult.cage_dps, 6.0)
	ult.ability_range = 3000.0  # Ted's own copy: a throw across the test bed
	var spikes: Array[DamagePacket] = []
	var listener := func(p: DamagePacket) -> void:
		if p.ability == ult:
			spikes.append(p)
	EventBus.damage_applied.connect(listener)
	var before: Array[Node] = get_children()
	ult.execute(ted, hog)
	var cage := _new_cage(before)
	assert_true(cage != null and cage.cage_dps == 6.0 and cage.source == ted)
	await wait_seconds(0.9)
	assert_eq(spikes.size(), 0, "the first tick comes after 1 s")
	await wait_seconds(0.2)
	assert_eq(spikes.size(), 1, "one tick")
	await wait_seconds(1.0)
	EventBus.damage_applied.disconnect(listener)
	assert_eq(spikes.size(), 2, "one a second")
	for p in spikes:
		assert_eq(p.target, hog, "only the enemy")
		assert_eq(p.amount, 6.0)
		assert_eq(p.source, ted)
	_free([ted, hog, vlad, cage])


## Sturdy Cage: the cage takes the ability's longer duration (it reaches the
## cage before its _ready starts the timer).
func test_sturdy_cage_makes_the_cage_last_longer() -> void:
	if not require_isolated():
		return
	_own(TED_TREE, &"t3_trapdur", 1)
	var ted := await _hero(TED, Vector2.ZERO)
	var ult := _abilities(ted).ultimate_ability as TedUltimateTrapCage
	assert_near(ult.duration, 9.0, 0.0001, "6 s x 1.5")
	var before: Array[Node] = get_children()
	ult.execute(ted, null)
	var cage := _new_cage(before)
	assert_true(cage != null)
	if cage == null:
		_free([ted])
		return
	assert_near(cage.duration, 9.0, 0.0001)
	await wait_seconds(6.5)
	assert_true(is_instance_valid(cage) and cage.cage_active, "still closed after the stock 6 s")
	await wait_seconds(2.8)
	assert_false(is_instance_valid(cage) and cage.cage_active, "open after 9 s")
	_free([ted, cage])


# ---------------------------------------------------------------- River

func _river_kit(river: Node) -> RiverBasicAttack:
	return _abilities(river).basic_attack as RiverBasicAttack


## Sets `hero` to `fraction` of its max HP.
func _hurt_to(hero: HeroBase, fraction: float) -> void:
	hero.stats.take_damage(hero.get_health() - hero.get_max_health() * fraction)


## A fresh save: every sniper shot alike, a staff heal heals one hero, and
## River changes nobody's move speed.
func test_rivers_exports_are_off_on_a_fresh_save() -> void:
	if not require_isolated():
		return
	var river := await _hero(RIVER, Vector2.ZERO)
	var vlad := await _hero(VLAD, Vector2(100, 0))
	var irelia := await _hero(IRELIA, Vector2(200, 0))
	var hog := await _hog(Vector2(0, 200))
	var shot := _river_kit(river)
	assert_eq(shot.crit_every, 0)
	assert_eq(shot.extra_heal_targets, 0)
	assert_eq((_abilities(river).passive_ability as RiverPassiveAdaptive).team_speed_aura, 1.0)
	assert_eq(vlad.move_speed, vlad.stats.get_move_speed(), "no aura")
	assert_eq(vlad.team_move_speed_aura(), 1.0)
	var hits: Array[float] = []
	var listener := func(p: DamagePacket) -> void:
		if p.source == river:
			hits.append(p.amount)
	EventBus.damage_applied.connect(listener)
	for i in 4:
		shot.execute(river, hog)
	EventBus.damage_applied.disconnect(listener)
	assert_eq(hits, [12.0, 12.0, 12.0, 12.0] as Array[float], "no Deadeye")
	_hurt_to(vlad, 0.5)
	_hurt_to(irelia, 0.3)
	var irelia_hp: float = irelia.get_health()
	_abilities(river).active_ability.execute(river)
	shot.execute(river, vlad)
	assert_near(vlad.get_health(), vlad.get_max_health() * 0.5 + shot.heal_amount, 0.0001, "the staff heals Vlad")
	assert_near(irelia.get_health(), irelia_hp, 0.05, "and nobody else (only her own regen)")
	_free([river, vlad, irelia, hog])


## Deadeye: every 4th sniper shot deals x2.5, Triple Shot's extra targets
## included; the count lives on River's own copy.
func test_deadeye_makes_every_4th_sniper_shot_deal_2_5x() -> void:
	if not require_isolated():
		return
	_own(RIVER_TREE, &"rv_deadeye")
	var river := await _hero(RIVER, Vector2.ZERO)
	var hog := await _hog(Vector2(0, 200))
	var shot := _river_kit(river)
	assert_eq(shot.crit_every, 4)
	var hits: Array[float] = []
	var listener := func(p: DamagePacket) -> void:
		if p.source == river:
			hits.append(p.amount)
	EventBus.damage_applied.connect(listener)
	for i in 5:
		shot.execute(river, hog)
	EventBus.damage_applied.disconnect(listener)
	assert_eq(hits, [12.0, 12.0, 12.0, 30.0, 12.0] as Array[float])
	assert_true(shot.debug_line().ends_with("deadeye 1/4"), shot.debug_line())
	_free([river, hog])


## Chain Heal: a staff heal also heals the most hurt other hero within
## 160 px of the healed one; never River, never one further out.
func test_chain_heal_also_heals_the_most_hurt_ally_nearby() -> void:
	if not require_isolated():
		return
	_own(RIVER_TREE, &"rv_chain")
	var river := await _hero(RIVER, Vector2.ZERO)
	var vlad := await _hero(VLAD, Vector2(100, 0))
	var irelia := await _hero(IRELIA, Vector2(200, 0))
	var ted := await _hero(TED, Vector2(100, 120))
	var far := await _hero(VLAD, Vector2(100, 400))
	var shot := _river_kit(river)
	assert_eq(shot.extra_heal_targets, 1)
	_hurt_to(river, 0.2)
	_hurt_to(vlad, 0.5)
	_hurt_to(irelia, 0.3)
	_hurt_to(ted, 0.8)
	_hurt_to(far, 0.1)
	var before: Dictionary = {}
	for h: HeroBase in [river, irelia, ted, far]:
		before[h] = h.get_health()
	_abilities(river).active_ability.execute(river)
	shot.execute(river, vlad)
	var heal: float = shot.heal_amount
	assert_near(vlad.get_health(), vlad.get_max_health() * 0.5 + heal, 0.0001, "the target")
	assert_near(irelia.get_health(), float(before[irelia]) + heal, 0.05, "the most hurt ally within 160 px")
	assert_near(ted.get_health(), float(before[ted]), 0.0001, "less hurt: not chained")
	assert_near(far.get_health(), float(before[far]), 0.0001, "300 px away")
	assert_near(river.get_health(), float(before[river]), 0.0001, "never River herself")
	_free([river, vlad, irelia, ted, far])


## Pathfinder: while River lives every hero moves 12% faster (River too);
## it ends when she dies.
func test_pathfinder_speeds_up_every_hero_while_river_lives() -> void:
	if not require_isolated():
		return
	_own(RIVER_TREE, &"rv_pathfinder")
	var river := await _hero(RIVER, Vector2.ZERO)
	var vlad := await _hero(VLAD, Vector2(3000, 0))
	var adaptive := _abilities(river).passive_ability as RiverPassiveAdaptive
	assert_near(adaptive.team_speed_aura, 1.12, 0.0001)
	assert_near(vlad.team_move_speed_aura(), 1.12, 0.0001, "far away too: the whole team")
	assert_near(vlad.move_speed, vlad.stats.get_move_speed() * 1.12, 0.0001)
	assert_near(river.move_speed, river.stats.get_move_speed() * 1.12, 0.0001, "River herself")
	assert_true(vlad.debug_keys_line().contains("team speed x1.12"), vlad.debug_keys_line())
	EventBus.deal_damage(null, river, 9999.0)
	assert_false(river.is_alive())
	assert_eq(vlad.team_move_speed_aura(), 1.0, "a dead River's aura is gone at once")
	await wait_frames(2)
	assert_false(is_instance_valid(river))
	assert_eq(vlad.move_speed, vlad.stats.get_move_speed())
	_free([vlad])

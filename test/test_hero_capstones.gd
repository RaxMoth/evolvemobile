extends TestCase

## The hero behaviour and capstone nodes (README "Hero capstones and behaviour
## nodes"): every new ability export is off on a fresh save and does its job on
## a seeded save, on the hero's own ability copy (the shared .tres is never
## touched). Only a tree's equipped capstone applies.

const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const IRELIA_TREE := &"hero_irelia"

## [tree, node, ability, export, the export's off value] of every node that
## reaches a hero's ability through an export of its own.
const NODES: Array = [
	[&"hero_irelia", &"ir_laststand", "Regeneration", "last_stand", false],
	[&"hero_irelia", &"ir_guardian", "Divine Shield", "cleanse_stuns", false],
	[&"hero_irelia", &"ir_banner", "Monster Taunt", "rally_radius", 0.0],
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

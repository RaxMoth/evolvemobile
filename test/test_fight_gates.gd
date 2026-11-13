extends TestCase

## The fight gates of the entity AI (EntityBase, README "Fight gates"):
## Approach enters Fight at fight_enter_range, Fight leaves past
## fight_leave_range, and the basic attack fires inside min_distance ..
## attack_range. Each test runs the entity's own chart (spawn_entity), not the
## rule helpers. Fix batch R1, review findings heroes-2, heroes-12, meta-1 and
## meta-2: River's staff never healed (its gate could not open), and range
## upgrades pushed the enter range past a fixed leave distance, so the entity
## flipped between Approach and Fight every tick and stood still.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"

## Tree keys that move a Fight gate: the heroes' attack_range, the monsters'
## range multiplier and Titan Form's flat reach.
const RANGE_KEYS: Array[String] = ["attack_range", "monster_range_mult", "monster_titan_form"]


func before_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


func _free(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	await wait_frames(2)


## Send `entity` after `target` the way a teammate's call does
## (EntityBase._broadcast_aggro): the target pair, then ENEMY_ENTERED.
func _call_onto(entity: EntityBase, target: Node2D) -> void:
	entity.set_target(target)
	entity.state_chart.send_event(CombatEvents.ENEMY_ENTERED)


## Counts River's staff heals on `patient` (FxEvents.HEAL_SHOT of her basic).
func _heal_counter(river: River, patient: Node) -> Array:
	var count := [0]
	var basic: AbilityBase = (river.get_node("AbilitySystem") as AbilitySystem).basic_attack
	var cb := func(source: Node, ability: AbilityBase, event: StringName, _pos: Vector2, _value: float) -> void:
		if event == FxEvents.HEAL_SHOT and source == patient and ability == basic:
			count[0] += 1
	EventBus.ability_event.connect(cb)
	return [count, cb]


func _hurt_to(hero: HeroBase, fraction: float) -> void:
	hero.stats.take_damage(hero.get_health() - hero.get_max_health() * fraction)


# ---------------------------------------------------------------- River's staff

## heroes-2: an ally at 40 % stands 90 px from River (out of the kit's 60, so
## only the staff can heal him) while her target, a Hog, stands 195 px away.
## Her own AI swaps to the staff and heals him, again after the staff's 4 s.
## The staff used to make its 150 px the Fight gate under a min_distance of
## 180: 0 heals in 12 s.
func test_river_heals_a_wounded_ally_in_a_fight() -> void:
	var nav := await bake_nav_rect(Rect2(-600, -600, 1200, 1200))
	var river := (await spawn_entity(RIVER, Vector2(0, 0))) as River
	var vlad := (await spawn_frozen(VLAD, Vector2(90, 0))) as HeroBase
	var hog := await spawn_frozen(HOG, Vector2(0, 195))
	_hurt_to(vlad, 0.4)
	var hp: float = vlad.get_health()
	_call_onto(river, hog)
	var counter := _heal_counter(river, vlad)
	# A rifle shot may go first (1.1 s), then the staff heals every 4 s.
	await wait_seconds(6.0)
	EventBus.ability_event.disconnect(counter[1])
	assert_eq(river.get_weapon_mode(), RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF, "she swapped to the staff")
	assert_true(int(counter[0][0]) >= 2, "staff heals in 6 s: %d" % int(counter[0][0]))
	var heal: float = ((river.get_node("AbilitySystem") as AbilitySystem).basic_attack as RiverBasicAttack).heal_amount
	assert_near(vlad.get_health(), hp + heal * float(counter[0][0]), 0.01, "each heal landed on Vlad")
	assert_true(river.is_target_valid(), "she keeps her fight target while she heals")
	await _free([river, vlad, hog, nav])


## Between fights the staff still heals: with no enemy about, River walks
## along the navigation mesh to an ally 260 px away (inside her 350 px watch)
## and heals him. Before, she stood in Idle holding the staff.
func test_river_walks_to_a_wounded_ally_and_heals_between_fights() -> void:
	var nav := await bake_nav_rect(Rect2(-600, -600, 1200, 1200))
	var river := (await spawn_entity(RIVER, Vector2(0, 0))) as River
	var vlad := (await spawn_frozen(VLAD, Vector2(260, 0))) as HeroBase
	_hurt_to(vlad, 0.4)
	var counter := _heal_counter(river, vlad)
	await wait_seconds(4.0)
	EventBus.ability_event.disconnect(counter[1])
	assert_eq(active_state_of(river), "Idle", "no fight")
	assert_true(int(counter[0][0]) >= 1, "healed between fights: %d" % int(counter[0][0]))
	assert_true(river.global_position.distance_to(vlad.global_position) <= 150.0,
		"she walked into the staff's reach (%.0f px)" % river.global_position.distance_to(vlad.global_position))
	await _free([river, vlad, nav])


## With the rifle River shoots her target from inside her band (180-300 px).
func test_river_shoots_with_the_rifle() -> void:
	var river := (await spawn_entity(RIVER, Vector2(0, 0))) as River
	var hog := await spawn_frozen(HOG, Vector2(0, 240))
	_call_onto(river, hog)
	await wait_seconds(2.0)
	assert_eq(river.get_weapon_mode(), RiverActiveWeaponSwap.WeaponMode.SNIPER, "nobody hurt: the rifle")
	assert_eq(active_state_of(river), "Fight")
	if is_instance_valid(hog):
		assert_true((hog as EntityBase).get_health() < (hog as EntityBase).get_max_health(), "the Hog was shot")
	await _free([river, hog])


# ---------------------------------------------------------------- every hero's gate

## Each hero's own AI opens its Fight gate on a Hog that stands in the middle
## of its band (min_distance..attack_range) and lands its basic attack.
func test_every_hero_swings_at_a_hog_inside_its_band() -> void:
	var x := 0.0
	for path: String in [VLAD, RIVER, TED, IRELIA]:
		var hero := (await spawn_entity(path, Vector2(x, 0))) as HeroBase
		hero.auto_use_active = false  # the basic attack alone
		hero.auto_use_ultimate = false
		var band: float = (hero.min_distance + hero.attack_range) * 0.5
		var hog := await spawn_frozen(HOG, Vector2(x + band, 0))
		var basic: AbilityBase = (hero.get_node("AbilitySystem") as AbilitySystem).basic_attack
		var casts := [0]
		var cb := func(caster: Node, ability: AbilityBase, _t: Node) -> void:
			if caster == hero and ability == basic:
				casts[0] += 1
		EventBus.ability_cast.connect(cb)
		_call_onto(hero, hog)
		await wait_seconds(2.0)
		EventBus.ability_cast.disconnect(cb)
		assert_true(casts[0] >= 1, "%s swung at a Hog %.0f px away: %d" % [hero.name, band, casts[0]])
		if is_instance_valid(hog):
			assert_true((hog as EntityBase).get_health() < (hog as EntityBase).get_max_health(), "%s hit it" % hero.name)
		await _free([hero, hog])
		x += 3000.0


## heroes-12: the ultimate goes through HeroBase._process with its own reach
## rule. Vlad's live AI holds Blood Bomb while three Hogs stand 400 px from
## him, and fires it once he stands among them.
func test_vlad_fires_blood_bomb_only_among_the_enemies() -> void:
	var vlad := (await spawn_entity(VLAD, Vector2(0, 0))) as HeroBase
	vlad.auto_ult_min_enemies = 3
	vlad.auto_use_active = false
	var hogs: Array = []
	for pos: Vector2 in [Vector2(400, 0), Vector2(440, 50), Vector2(440, -50)]:
		hogs.append(await spawn_frozen(HOG, pos))
	var ult: AbilityBase = (vlad.get_node("AbilitySystem") as AbilitySystem).ultimate_ability
	var casts := [0]
	var cb := func(caster: Node, ability: AbilityBase, _t: Node) -> void:
		if caster == vlad and ability == ult:
			casts[0] += 1
	EventBus.ability_cast.connect(cb)
	_call_onto(vlad, hogs[0])
	await wait_seconds(1.0)
	assert_eq(casts[0], 0, "nothing within the bomb's 150 px: no cast")
	vlad.global_position = Vector2(420, 0)
	await wait_seconds(1.0)
	EventBus.ability_cast.disconnect(cb)
	assert_eq(casts[0], 1, "among the three: one Blood Bomb")
	var nodes: Array = [vlad]
	nodes.append_array(hogs)
	await _free(nodes)


# ---------------------------------------------------------------- range upgrades

## meta-2: River with Long Scope 5 and Sniper's Nest 3 (450 px) is called onto
## a monster 550 px away. She walks into her new range and shoots. She used to
## stop at 450 px, past her fixed 350 px Fight leave distance, and flip
## between Approach and Fight without a shot.
func test_river_with_range_nodes_shoots_from_her_full_reach() -> void:
	if not require_isolated():
		return
	play_side(MatchRewards.Side.HEROES)
	var tree := MetaSkillManager.hero_tree_id(&"river")
	PersistedData.set_skill_rank(tree, &"r1_range", 5)
	PersistedData.set_skill_rank(tree, &"r3_range", 3)
	var nav := await bake_nav_rect(Rect2(-200, -300, 1000, 600))
	var river := (await spawn_entity(RIVER, Vector2(0, 0))) as River
	assert_near(river.attack_range, 450.0, 0.01, "300 x 1.20 x 1.25")
	var g := (await spawn_frozen(GROUNT, Vector2(550, 0))) as MonsterBase
	_call_onto(river, g)
	await wait_seconds(8.0)
	assert_eq(active_state_of(river), "Fight", "she settles in Fight")
	assert_true(g.get_health() < g.get_max_health(), "and shoots from 450 px (monster %.0f / %.0f)" % [g.get_health(), g.get_max_health()])
	await _free([river, g, nav])


## Every roster character runs its own chart onto a frozen target 1 px inside
## where Approach enters Fight (fight_enter_range - 1), with no range node and
## with every range node of its trees at its top rank (Titan Form equipped; a
## monster at Stage III, where it hunts heroes). It enters Fight, never goes
## back to Approach and lands a hit; River does it with the rifle and holds
## Fight with the staff (nobody to heal). meta-1 / meta-2: Grount with Wide
## Sweep 3 and Long Reach 2 entered at 108.6 px and left at 100, River with
## Long Scope 4 entered at 351 and left at 350; each flipped between Approach
## and Fight every tick and stood still.
func test_every_character_holds_fight_at_its_reach_with_any_range_nodes() -> void:
	if not require_isolated():
		return
	var nav := await bake_nav_rect(Rect2(-1500, -1500, 3000, 3000))
	var cases: int = 0
	var past_max: int = 0
	for def: CharacterDef in GameManager.ROSTER.all():
		var nodes := _range_nodes(def)
		for maxed: bool in [false, true]:
			for staff: bool in ([false, true] if def.scene_path == RIVER else [false]):
				PersistedData.wipe_progress(false)
				play_side(def.side)
				var label := String(def.character_id())
				if maxed:
					for pair: Array in nodes:
						var n := pair[1] as MetaSkillNode
						PersistedData.set_skill_rank(pair[0], n.id, n.max_rank)
						if n.capstone:
							PersistedData.set_equipped_capstone(pair[0], n.id)
						label += " %s %d" % [n.id, n.max_rank]
				if staff:
					label += " (staff)"
				if await _holds_fight(def.scene_path, staff, label):
					past_max += 1
				cases += 1
	assert_true(cases >= 16, "cases run: %d" % cases)
	assert_true(past_max >= 2, "cases whose enter range lies past max_distance (the ones that froze): %d" % past_max)
	await _free([nav])


## Spawns the entity at `path` with its AI running, calls it onto a frozen
## target (a Hog for a hero, Vlad for a monster) 1 px inside its Fight enter
## range and runs 1.5 s, asserting the gate holds. True when that spot lies
## past max_distance, where a leave rule of max_distance would flip it.
func _holds_fight(path: String, staff: bool, label: String) -> bool:
	var e := (await spawn_entity(path, Vector2.ZERO)) as EntityBase
	var monster := e as MonsterBase
	if e is HeroBase:
		(e as HeroBase).auto_use_active = false  # no dash or swap of its own
		(e as HeroBase).auto_use_ultimate = false
	if staff:
		(e as River)._use_active_now()
	if monster:
		evolve_to(monster, 3)
		await wait_seconds(0.7)  # the stage scale tween
	var target := (await spawn_frozen(VLAD if monster else HOG, e.global_position + Vector2(1000, 0))) as EntityBase
	var enter: float = e.fight_enter_range()
	# Due east of where the entity stands now (it may have wandered while the
	# target spawned), then in by the difference: range_to is the centre
	# distance less the bodies.
	target.global_position = e.global_position + Vector2(1000, 0)
	target.global_position.x -= e.range_to(target) - (enter - 1.0)
	assert_near(e.range_to(target), enter - 1.0, 0.5, "%s: the target 1 px inside the enter range" % label)
	assert_true(e.fight_leave_range() > enter,
		"%s: Fight leaves at %.1f, past where Approach enters it (%.1f)" % [label, e.fight_leave_range(), enter])
	var past_max: bool = enter - 1.0 > e.max_distance
	var chart := e.get_node(^"%StateChart/CompoundState")
	var entries := [0, 0]  # Fight entries, Approach entries after the first Fight
	var on_fight := func() -> void: entries[0] += 1
	var on_approach := func() -> void:
		if entries[0] > 0:
			entries[1] += 1
	chart.get_node(^"Fight").connect(&"state_entered", on_fight)
	chart.get_node(^"Approach").connect(&"state_entered", on_approach)
	_call_onto(e, target)
	for i in 90:
		if monster:  # the basic swing only: no dash or slam that moves it
			monster.ability_cooldowns["ability_2"] = 99.0
			monster.ability_cooldowns["ability_3"] = 99.0
		await wait_physics_frames(1)
	chart.get_node(^"Fight").disconnect(&"state_entered", on_fight)
	chart.get_node(^"Approach").disconnect(&"state_entered", on_approach)
	assert_true(int(entries[0]) >= 1, "%s: enters Fight with the target %.1f px away" % [label, enter - 1.0])
	assert_eq(int(entries[1]), 0, "%s: never back to Approach (enter %.1f, leave %.1f, max_distance %.0f)"
			% [label, enter, e.fight_leave_range(), e.max_distance])
	if not staff:
		var hit := not is_instance_valid(target) or target.get_health() < target.get_max_health()
		assert_true(hit, "%s: and lands a hit" % label)
	await _free([e, target])
	return past_max


## [tree id, MetaSkillNode] of every node in `def`'s base and own tree whose key
## moves a Fight gate (RANGE_KEYS).
func _range_nodes(def: CharacterDef) -> Array:
	var trees: Array[StringName] = []
	if def.side == CharacterDef.HEROES:
		trees = [MetaSkillManager.TREE_HERO_BASE, MetaSkillManager.hero_tree_id(def.character_id())]
	else:
		trees = [MetaSkillManager.TREE_MONSTER_BASE, MetaSkillManager.monster_tree_id(def.character_id())]
	var out: Array = []
	for tree_id in trees:
		var t: MetaSkillTree = MetaSkillManager.get_tree_def(tree_id)
		if t == null:
			continue
		for n in t.shown_nodes():
			if n.stat_name in RANGE_KEYS:
				out.append([tree_id, n])
	return out

extends TestCase

## Hero active abilities are actually used by the AI, and they work.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"


func test_divine_shield_protects_any_hero_not_only_irelia() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var shield := Shield.new()
	shield.name = "Shield"
	shield.shield_amount = 18.0
	shield.duration = 7.0
	shield.owner_hero = vlad
	vlad.add_child(shield)
	var hp: float = vlad.get_health()
	EventBus.deal_damage(null, vlad, 10.0)
	assert_near(vlad.get_health(), hp, 0.01, "first 10 absorbed")
	EventBus.deal_damage(null, vlad, 10.0)
	assert_near(vlad.get_health(), hp - 2.0, 0.01, "8 absorbed, 2 through")
	await wait_frames(2)
	assert_false(is_instance_valid(shield), "broken shield frees itself")
	EventBus.deal_damage(null, vlad, 10.0)
	assert_near(vlad.get_health(), hp - 12.0, 0.01, "no listener left after the shield is gone")
	vlad.queue_free()


func test_river_switches_to_heal_and_back_by_team_health() -> void:
	var river := await spawn_entity(RIVER, Vector2(0, 0))
	var vlad := await spawn_entity(VLAD, Vector2(120, 0))
	assert_false(river._should_auto_use_active(), "everyone healthy: stay sniper")
	(vlad.get_node("HeroStats") as HeroStatsComponent).take_damage(vlad.get_max_health() * 0.5)
	assert_true(river._should_auto_use_active(), "ally at 50%% wants the heal staff")
	river._use_active_now()
	assert_eq(river.get_weapon_mode(), 1, "heal staff")
	assert_false(river._should_auto_use_active(), "stays while the ally is below 85%")
	(vlad.get_node("HeroStats") as HeroStatsComponent).heal(vlad.get_max_health())
	assert_true(river._should_auto_use_active(), "healthy again: back to sniper")
	await wait_seconds(1.1)  # the swap has a 1 s cooldown
	river._use_active_now()
	assert_eq(river.get_weapon_mode(), 0)
	river.queue_free()
	vlad.queue_free()


func test_rally_cry_speeds_up_attacks() -> void:
	var ted := await spawn_entity(TED, Vector2(0, 0))
	var abilities := ted.get_node("AbilitySystem") as AbilitySystem
	var base: float = abilities.get_attack_speed_multiplier()
	ted.apply_attack_speed_boost(1.5, 0.3)
	assert_near(abilities.get_attack_speed_multiplier(), base * 1.5, 0.001)
	await wait_seconds(0.5)
	assert_near(abilities.get_attack_speed_multiplier(), base, 0.001, "boost expires")
	ted.queue_free()


func test_heroes_use_their_active_in_a_fight() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var hog := await spawn_entity(HOG, Vector2(35, 0))
	var actives := [0]
	var cb := func(caster: Node, ability: AbilityBase, _t: Node) -> void:
		if caster == vlad and ability.ability_type == AbilityBase.AbilityType.ACTIVE:
			actives[0] += 1
	EventBus.ability_cast.connect(cb)
	await wait_seconds(1.0)
	EventBus.ability_cast.disconnect(cb)
	assert_true(actives[0] >= 1, "Vlad dropped a mine while fighting")
	for n in [vlad, hog]:
		if is_instance_valid(n):
			n.queue_free()


func test_irelia_taunting_strike_pulls_a_mob_onto_her() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var irelia := await spawn_entity(IRELIA, Vector2(100, 0))
	var hog := await spawn_entity(HOG, Vector2(30, 0))
	var basic: AbilityBase = (irelia.get_node("AbilitySystem") as AbilitySystem).basic_attack
	basic.execute(irelia, hog)
	var enemies: TeamBlackboard = TeamRegistry.get_team(TeamRegistry.ENEMIES)
	assert_true(enemies.get_threat_against(hog, irelia) >= 40.0, "flat taunt threat recorded")
	assert_true(hog._get_threat_score(irelia) > hog._get_threat_score(vlad) + 50.0, "Irelia now out-threatens Vlad by more than the fight switch threshold")
	for n in [vlad, irelia, hog]:
		if is_instance_valid(n):
			n.queue_free()


## BasicStrike flashes the trail its .tres enables (GameUtils.flash_line, under
## the caster's parent, from caster to target) and the trail frees itself after
## the fade: none for Vlad, Ted's brown-orange swipe, Irelia's light-blue one.
func test_basic_strike_trails_follow_the_tres() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(-20, 0))
	var ted := await spawn_frozen(TED, Vector2(20, 0))
	var irelia := await spawn_frozen(IRELIA, Vector2(0, 20))
	var hog := await spawn_frozen(HOG, Vector2(0, 0))
	var expected: Dictionary = {vlad: [], ted: [Color(0.8, 0.5, 0.2), 2.5], irelia: [Color(0.7, 0.7, 1.0), 1.5]}
	var all_trails: Array = []
	for caster: Node2D in [vlad, ted, irelia]:
		var before: Array[Node] = get_children()
		(caster.get_node("AbilitySystem") as AbilitySystem).basic_attack.execute(caster, hog)
		var trails: Array = get_children().filter(func(n: Node) -> bool: return n is Line2D and not before.has(n))
		var want: Array = expected[caster]
		assert_eq(trails.size(), 1 if want.size() > 0 else 0, "%s: trails drawn" % caster.name)
		if trails.size() == 1 and want.size() > 0:
			var line := trails[0] as Line2D
			assert_true(line.default_color.is_equal_approx(want[0]), "%s: trail colour %s" % [caster.name, line.default_color])
			assert_near(line.width, float(want[1]), 0.001, "%s: trail width" % caster.name)
			assert_eq(line.z_index, 10)
			assert_eq(line.points, PackedVector2Array([caster.global_position, hog.global_position]), "%s: caster to target" % caster.name)
		all_trails.append_array(trails)
	await wait_seconds(0.5)
	for line in all_trails:
		assert_false(is_instance_valid(line), "trail freed after its fade")
	for n in [vlad, ted, irelia, hog]:
		if is_instance_valid(n):
			n.queue_free()


func test_heroes_focus_wounded_enemies() -> void:
	var vlad := await spawn_entity(VLAD, Vector2(0, 0))
	var a := await spawn_entity(HOG, Vector2(4000, 0))
	var b := await spawn_entity(HOG, Vector2(4000, 300))
	(b as MobBase).current_health = 20.0
	assert_true(vlad._get_threat_score(b) > vlad._get_threat_score(a) + 40.0, "a Hog at 20% outranks a full one by the focus bonus")
	for n in [vlad, a, b]:
		if is_instance_valid(n):
			n.queue_free()


func test_teds_pet_is_targetable_and_stays_leashed_to_ted() -> void:
	var ted := await spawn_frozen("res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn", Vector2(0, 0))
	await wait_frames(3)
	var pet: Node2D = null
	for e in EntityRegistry.hero_side:
		if is_instance_valid(e) and not (e is HeroBase) and e.get("owner_entity") == ted:
			pet = e
	assert_true(pet != null, "Ted's passive spawned the pet")
	if pet == null:
		ted.queue_free()
		return
	pet.global_position = Vector2(0, 0)
	var near_bat := await spawn_entity("res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn", Vector2(200, 0))
	var far_bat := await spawn_entity("res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn", Vector2(-380, 0))
	TickScheduler.unregister(near_bat)
	TickScheduler.unregister(far_bat)
	# Enemies can target the pet now (it had no area on the hero layer).
	var body := pet.get_node_or_null(^"Body") as Area2D
	assert_true(body != null and body.collision_layer == GameUtils.LAYER_BODY_HERO, "hitbox on the hero layer")
	assert_true((near_bat as EntityBase)._can_target_area(body), "a mob may target the pet")
	# Leash: only enemies near TED count, however close they are to the pet.
	ted.global_position = Vector2(-2000, 0)
	pet.call("_find_target")
	assert_true(pet.get("current_target") == null, "nothing within the leash of Ted")
	ted.global_position = Vector2(0, 0)
	pet.call("_find_target")
	assert_true(pet.get("current_target") == near_bat, "nearest enemy inside the leash")
	ted.global_position = Vector2(-2000, 0)
	assert_false(pet.call("_target_ok"), "drops the target once Ted is far away")
	for n in [ted, near_bat, far_bat]:
		n.queue_free()


## AbilitySystem._ready gives every hero its own ability copies (not only
## heroes that MetaSkillManager reaches through a hero_id), so per-hero state
## such as Ted's pet never lands on the shared .tres or on another Ted.
func test_each_hero_owns_its_ability_copies() -> void:
	var ted_a := await spawn_frozen(TED, Vector2(0, 0))
	var ted_b := await spawn_frozen(TED, Vector2(3000, 0))
	var a := ted_a.get_node("AbilitySystem") as AbilitySystem
	var b := ted_b.get_node("AbilitySystem") as AbilitySystem
	assert_true(a.passive_ability != null and b.passive_ability != null, "both Teds have the pet passive")
	assert_true(a.passive_ability != b.passive_ability, "each Ted owns its own passive")
	for abilities: AbilitySystem in [a, b]:
		for ability in abilities.all_abilities():
			assert_true(ability.resource_path.is_empty(), "%s is a per-hero copy" % ability.ability_name)
	ted_a.queue_free()
	ted_b.queue_free()
	# A bare AbilitySystem (no hero, so no hero_id) copies on _ready as well.
	var shared := load("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Abilities/active/active_mine.tres") as AbilityBase
	var holder := Node2D.new()
	var bare := AbilitySystem.new()
	bare.active_ability = shared
	holder.add_child(bare)
	add_child(holder)
	assert_true(bare.active_ability != shared, "fixture without a hero_id gets a copy")
	assert_true(bare.active_ability.resource_path.is_empty())
	assert_false(shared.resource_path.is_empty(), "the shared .tres keeps its path")
	holder.queue_free()

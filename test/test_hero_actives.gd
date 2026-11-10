extends TestCase

## Hero active abilities are actually used by the AI, and they work.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


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


## The TrapCage a cast added under `parent` since `before`, or null.
func _new_cage(parent: Node, before: Array[Node]) -> TrapCage:
	for n in parent.get_children():
		if n is TrapCage and not before.has(n):
			return n as TrapCage
	return null


## Trap Cage closes where it lands: centred on its target at the README's
## 150 px, with the enemies around the target trapped from its first frame.
## Ted's parent is a plain Node here, as World's "Heros". Until 6.3 the cage
## scanned at the world origin before it moved there, with the scene's 150 px,
## and then shrank to the ability's area_of_effect of 2.
func test_trap_cage_traps_the_enemies_around_its_target() -> void:
	var ted := await spawn_frozen(TED, Vector2(0, 0))
	var grount := await spawn_frozen(GROUNT, Vector2(2000, 0))
	var near_hog := await spawn_frozen(HOG, Vector2(2100, 0))
	var far_hog := await spawn_frozen(HOG, Vector2(2400, 0))
	var vlad := await spawn_frozen(VLAD, Vector2(2000, 60))
	var ult: AbilityBase = (ted.get_node("AbilitySystem") as AbilitySystem).ultimate_ability
	assert_eq(ult.area_of_effect, 150.0, "Ted's copy carries the cage radius")
	var before: Array[Node] = get_children()
	ult.execute(ted, grount)
	var cage := _new_cage(self, before)
	assert_true(cage != null, "the cast drops a cage")
	if cage == null:
		for n: Node in [ted, grount, near_hog, far_hog, vlad]:
			n.queue_free()
		return
	assert_eq(cage.global_position, grount.global_position, "centred on the target")
	assert_eq(cage.cage_radius, 150.0)
	var shape := (cage.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_eq(shape.radius, 150.0, "the collision shape matches the radius")
	assert_eq(cage.duration, 6.0)
	assert_true(cage.trapped_enemies.has(grount), "the monster is trapped")
	assert_true(cage.trapped_enemies.has(near_hog), "and the mob 100 px from it")
	assert_false(cage.trapped_enemies.has(far_hog), "not the mob 400 px away")
	assert_false(cage.trapped_enemies.has(vlad), "never a hero, even inside")
	# Out past the bars: the cage puts it back just inside, on the side it
	# left by (the push used to mirror it across the cage).
	grount.global_position = cage.global_position + Vector2(300, 0)
	await wait_frames(2)
	var offset: Vector2 = grount.global_position - cage.global_position
	assert_true(offset.length() < cage.cage_radius, "a trapped enemy cannot walk out (%s)" % str(offset))
	assert_true(offset.x > 100.0, "held at the edge it left by (%s)" % str(offset))
	for n: Node in [ted, grount, near_hog, far_hog, vlad, cage]:
		n.queue_free()


## A caster under a moved Node2D: the cage still lands on the target in world
## space (outside the tree, global_position would be the parent-local one).
func test_trap_cage_lands_on_the_target_under_a_moved_parent() -> void:
	var holder := Node2D.new()
	holder.position = Vector2(500, -300)
	add_child(holder)
	var ted := (load(TED) as PackedScene).instantiate() as Node2D
	ted.position = Vector2(-500, 300)
	holder.add_child(ted)
	await wait_physics_frames(4)
	await wait_frames(1)
	get_tree().root.get_node(^"TickScheduler").unregister(ted)
	var hog := await spawn_frozen(HOG, Vector2(2000, 0))
	var ult: AbilityBase = (ted.get_node("AbilitySystem") as AbilitySystem).ultimate_ability
	var before: Array[Node] = holder.get_children()
	ult.execute(ted, hog)
	var cage := _new_cage(holder, before)
	assert_true(cage != null, "the cage goes under Ted's parent")
	if cage != null:
		assert_true(cage.global_position.is_equal_approx(hog.global_position),
			"on the target: %s" % str(cage.global_position))
		assert_true(cage.trapped_enemies.has(hog), "and traps it")
	hog.queue_free()
	holder.queue_free()


## A flash (GameUtils.flash_modulate: Irelia's Last Stand, a sprite's
## evolution) ends at WHITE, not at the tint it found when it started: a
## Divine Shield that broke mid-flash used to leave Ted blue for good. Rally
## Cry itself no longer tints Ted (its recipe draws rings).
func test_rally_flash_ends_white_when_a_shield_breaks_mid_flash() -> void:
	var ted := (await spawn_frozen(TED, Vector2(0, 0))) as HeroBase
	var hog := await spawn_frozen(HOG, Vector2(3000, 0))
	ted.set_target(hog)
	var shield := Shield.new()
	shield.name = "Shield"
	shield.shield_amount = 18.0
	shield.duration = 7.0
	shield.owner_hero = ted
	ted.add_child(shield)
	await wait_frames(1)
	assert_true(ted.modulate.b > 1.0, "shielded: blue tint")
	assert_true(ted.use_active_ability(), "Rally Cry cast")
	GameUtils.flash_modulate(ted, UiPalette.get_default().amber_light, 0.2, 0.2)
	await wait_seconds(0.1)
	EventBus.deal_damage(null, ted, 20.0)
	await wait_frames(1)
	assert_false(is_instance_valid(shield), "the shield broke mid-flash")
	await wait_seconds(0.6)
	assert_eq(ted.modulate, Color.WHITE, "no tint left after the flash")
	ted.queue_free()
	hog.queue_free()


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
## the caster's parent, body to body) and the trail frees itself after the
## fade. No hero strikes with one any more: their recipes draw the slash or
## the claw (AbilityVfx), so Vlad, Ted and Irelia leave no line; a copy with
## the trail switched on still gets it.
func test_basic_strike_trails_follow_the_tres() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(-20, 0))
	var ted := await spawn_frozen(TED, Vector2(20, 0))
	var irelia := await spawn_frozen(IRELIA, Vector2(0, 20))
	var hog := await spawn_frozen(HOG, Vector2(0, 0))
	for caster: Node2D in [vlad, ted, irelia]:
		var before: Array[Node] = get_children()
		var basic := (caster.get_node("AbilitySystem") as AbilitySystem).basic_attack as BasicStrike
		assert_false(basic.trail_enabled, "%s: no trail" % caster.name)
		assert_true(basic.fx != null and basic.fx.cue in [&"strike", &"claw"], "%s: the recipe draws the hit" % caster.name)
		basic.execute(caster, hog)
		var trails: Array = get_children().filter(func(n: Node) -> bool: return n is Line2D and not before.has(n))
		assert_eq(trails.size(), 0, "%s: no line drawn" % caster.name)
	var copy := (vlad.get_node("AbilitySystem") as AbilitySystem).basic_attack as BasicStrike
	copy.trail_enabled = true  # Vlad's own copy
	copy.trail_color = UiPalette.get_default().vlad
	var others: Array[Node] = get_children()
	copy.execute(vlad, hog)
	var lines: Array = get_children().filter(func(n: Node) -> bool: return n is Line2D and not others.has(n))
	assert_eq(lines.size(), 1, "a trail when switched on")
	if lines.size() == 1:
		var line := lines[0] as Line2D
		assert_eq(line.points, PackedVector2Array([CharacterRig.mid_body_of(vlad), CharacterRig.mid_body_of(hog)]), "body to body")
		await wait_seconds(copy.trail_fade + 0.2)
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

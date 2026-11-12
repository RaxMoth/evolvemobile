extends TestCase

## AbilityVfx (Scripts/Vfx/ability_vfx.gd) and the hero ability recipes:
## every hero ability carries an AbilityFxRecipe whose cue AbilityVfx knows
## and whose colours are palette tokens; every program keeps the toning-down
## rules (rings at most 3 px and on the ground, at most 6 puffs, nothing over
## a body or head past 0.15 s, lasting marks above the head); the pools never
## grow and draw no global random number; the hero scripts emit their FxEvents
## (wards, tethers, rally marks, mines, cages, supply drops, heals) and
## VfxManager turns the heals into "+N"; RingPulse.spawn rings live their
## duration; a trapped enemy's rig takes the cage's palette tint; River's HUD
## card shows her weapon; World.tscn wires the node.

const WORLD := "res://Scenes/World/World.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const HUD_CARD := "res://Scenes/UI/Hud/HeroHudCard.tscn"
const RECIPES := "res://Assets/Vfx/recipes"
const HEROES: Array[String] = [VLAD, RIVER, TED, IRELIA]
const ABILITIES := "res://Scenes/NPCs/Hero/Heros/"
## The abilities whose recipes the program checks play (shared .tres, read only).
const BASIC_VLAD := ABILITIES + "DMG/Vlad/Abilities/basic_attack/basic_attack.tres"
const MINE := ABILITIES + "DMG/Vlad/Abilities/active/active_mine.tres"
const BOMB := ABILITIES + "DMG/Vlad/Abilities/ult/ult.tres"
const BASIC_IRELIA := ABILITIES + "Support/Irelia/Abilities/Basic_attack/irelia_basic_attack.tres"
const SHIELD := ABILITIES + "Support/Irelia/Abilities/Active/irelia_active.tres"
const TAUNT := ABILITIES + "Support/Irelia/Abilities/Ult/irelia_ult.tres"
const REGEN := ABILITIES + "Support/Irelia/Abilities/Passive/irelia_passive.tres"
const BASIC_TED := ABILITIES + "Support/Ted/Abilities/Basic_attack/ted_basic_attack.tres"
const RALLY := ABILITIES + "Support/Ted/Abilities/Active/ted_active.tres"
const CAGE := ABILITIES + "Support/Ted/Abilities/Ult/ted_ultimate.tres"
const BASIC_RIVER := ABILITIES + "Healer/River/Abilities/basic_attack/river_basic_attack.tres"
const SWAP := ABILITIES + "Healer/River/Abilities/active/river_active.tres"
const DROP := ABILITIES + "Healer/River/Abilities/ult/river_ult.tres"


## Basic attack, active and ultimate of every hero name a cue AbilityVfx
## plays; Irelia's Regeneration plays Last Stand. Every recipe's colours are
## palette tokens.
func test_every_hero_ability_has_a_known_recipe() -> void:
	for path in HEROES:
		var hero := (load(path) as PackedScene).instantiate()
		var system := hero.get_node("AbilitySystem") as AbilitySystem
		for ability: AbilityBase in [system.basic_attack, system.active_ability, system.ultimate_ability]:
			assert_true(ability.fx != null, "%s: %s has a recipe" % [hero.name, ability.ability_name])
			if ability.fx != null:
				assert_true(ability.fx.cue in AbilityVfx.CUES, "%s: cue %s" % [ability.ability_name, ability.fx.cue])
		hero.free()
	assert_eq((load(REGEN) as AbilityBase).fx.cue, &"last_stand", "Irelia's Regeneration plays Last Stand")
	var tokens: Array[StringName] = UiPalette.get_default().tokens()
	var count: int = 0
	for file in DirAccess.get_files_at(RECIPES):
		if not file.ends_with(".tres"):
			continue
		count += 1
		var recipe := load(RECIPES + "/" + file) as AbilityFxRecipe
		assert_true(recipe != null, "%s is an AbilityFxRecipe" % file)
		if recipe == null:
			continue
		for token: StringName in [recipe.accent, recipe.shade, recipe.core, recipe.alt]:
			assert_true(tokens.has(token), "%s: %s is a palette token" % [file, token])
	assert_true(count >= 13, "the hero recipes (%d)" % count)


## Each program alone: at most MAX_PUFFS puffs or dust clouds, rings at most
## MAX_RING_WIDTH wide, blasts and the slashes, claws, stars and bubbles over
## a body gone within HEAD_COVER.
func test_every_program_keeps_the_toning_down_rules() -> void:
	var stubs := _stubs()
	var programs: Dictionary[String, Array] = _programs(stubs[0], stubs[1], stubs[2] as Shield)
	assert_true(programs.size() >= 24, "every cue and event (%d)" % programs.size())
	for label: String in programs:
		var vfx := _vfx()
		var setup: Callable = programs[label][0]
		if setup.is_valid():
			setup.call(vfx)
		var puffs_before: int = _puffs(vfx)
		(programs[label][1] as Callable).call(vfx)
		assert_true(_shown(vfx) > 0, "%s shows something" % label)
		var puffs: int = _puffs(vfx) - puffs_before
		assert_true(puffs <= AbilityVfx.MAX_PUFFS, "%s: %d puffs" % [label, puffs])
		assert_true(vfx.widest_ring() <= AbilityVfx.MAX_RING_WIDTH, "%s: rings at most 3 px" % label)
		assert_true(vfx.longest_prim(AbilityVfx.Prim.DISC) <= AbilityVfx.HEAD_COVER, "%s: a blast over a body" % label)
		for i in vfx.over.capacity:
			if vfx.over.tex[i] in [FxTex.SLASH, FxTex.CLAW, FxTex.STAR, FxTex.BUBBLE]:
				assert_true(vfx.over.life[i] <= AbilityVfx.HEAD_COVER, "%s: %s over a body for %.2f s" % [
						label, vfx.over.tex[i].resource_path.get_file(), vfx.over.life[i]])
		vfx.queue_free()
	_free_stubs(stubs)
	await wait_frames(1)


## A taunt's anger vein floats above the enemy's head, and its tether runs
## body to body (also under an evolved monster's root scale), follows both
## ends and ends with the taunt.
func test_taunt_mark_sits_above_the_head_and_the_tether_follows_both_bodies() -> void:
	var grount := (await spawn_frozen(GROUNT, Vector2(0, 0))) as MonsterBase
	grount.gain_xp(1000.0)
	grount.gain_xp(0.0)
	await wait_seconds(0.7)  # stage scale tween
	assert_true(grount.scale.x > 1.4, "stage 3 root scale")
	var irelia := await spawn_frozen(IRELIA, Vector2(120, 0))
	var vfx := _vfx()
	var ult: AbilityBase = (irelia.get_node("AbilitySystem") as AbilitySystem).ultimate_ability
	ult.execute(irelia)
	await wait_frames(1)
	assert_eq(vfx.tethers_live(), 1, "one tether")
	var ends := vfx.tether_ends(grount)
	assert_eq(ends, PackedVector2Array([CharacterRig.mid_body_of(grount), CharacterRig.mid_body_of(irelia)]),
			"from the monster's body to Irelia's")
	assert_true(ends.size() == 2 and ends[1].y < irelia.global_position.y - 10.0, "above Irelia's feet")
	irelia.global_position = Vector2(60, 80)
	await wait_frames(1)
	assert_true(vfx.tether_ends(grount)[1].distance_to(CharacterRig.mid_body_of(irelia)) <= 1.0, "follows Irelia")
	# The anger vein rides the monster above its head.
	var mark: int = -1
	for i in vfx.marks.capacity:
		if vfx.marks.tex[i] == FxTex.ANGER:
			mark = i
	assert_true(mark >= 0, "an anger vein")
	if mark >= 0:
		assert_eq(vfx.marks.follow[mark], grount.get_instance_id(), "riding the monster")
		var at: Vector2 = grount.global_position + vfx.marks.pos[mark]
		assert_true(at.y < CharacterRig.head_top_of(grount).y, "above the head, never over it")
		assert_near(vfx.marks.life[mark], ult.duration, 0.001, "for the taunt's duration")
	await wait_seconds(ult.duration + 0.4)
	assert_eq(vfx.tethers_live(), 0, "gone after the taunt")
	vfx.queue_free()
	grount.queue_free()
	irelia.queue_free()
	await wait_frames(1)


## vfx-3 (pause half): the tether and the anger vein last as long as the taunt
## itself. A pause holds both (the taunt's timer is pausable since c008b27 and
## AbilityVfx ages its riders in a pausable _process), so after a pause longer
## than the taunt both are still there, and once the match runs again they end
## together. (The taunt's timer used to run on the paused tree: the tether and
## vein outlived it by the paused seconds.)
func test_a_paused_taunt_keeps_its_tether_and_both_end_together() -> void:
	var grount := (await spawn_frozen(GROUNT, Vector2(0, 0))) as MonsterBase
	var irelia := await spawn_frozen(IRELIA, Vector2(120, 0))
	var vfx := _vfx()
	var ult: AbilityBase = (irelia.get_node("AbilitySystem") as AbilitySystem).ultimate_ability
	ult.duration = 1.0  # Irelia's own copy
	ult.execute(irelia)
	await wait_frames(1)
	assert_true(grount.has_node(^"TauntEffect"), "taunted")
	assert_eq(vfx.tethers_live(), 1, "the tether")
	get_tree().paused = true
	await wait_seconds(1.5)  # an always-processing timer: runs on the paused tree
	var taunt_held := grount.has_node(^"TauntEffect")
	var tether_held := vfx.tethers_live()
	get_tree().paused = false
	assert_true(taunt_held, "1.5 s of pause: the 1 s taunt is still on")
	assert_eq(tether_held, 1, "and so is its tether")
	await wait_seconds(0.5)
	assert_true(grount.has_node(^"TauntEffect") and vfx.tethers_live() == 1, "running again: both still on")
	await wait_seconds(0.7)
	assert_false(grount.has_node(^"TauntEffect"), "the taunt ran out")
	assert_eq(vfx.tethers_live(), 0, "and its tether with it")
	vfx.queue_free()
	grount.queue_free()
	irelia.queue_free()
	await wait_frames(1)


## Divine Shield: every shielded hero gets a ward at its feet that pulses on
## an absorbed hit and snaps (six shards) when the shield breaks.
func test_divine_shield_wards_follow_the_shields() -> void:
	var irelia := await spawn_frozen(IRELIA, Vector2(0, 0))
	var vlad := await spawn_frozen(VLAD, Vector2(80, 0))
	var vfx := _vfx()
	var events := _record()
	var active: AbilityBase = (irelia.get_node("AbilitySystem") as AbilitySystem).active_ability
	active.execute(irelia)
	await wait_frames(1)
	assert_eq(vfx.wards_live(), 2, "a ward on Irelia and one on Vlad")
	assert_eq(_count(events, FxEvents.SHIELD_UP), 2, "SHIELD_UP per shielded hero")
	EventBus.deal_damage(null, vlad, 5.0)
	assert_eq(_count(events, FxEvents.SHIELD_HIT), 1, "an absorbed hit")
	EventBus.deal_damage(null, vlad, 100.0)
	assert_eq(_count(events, FxEvents.SHIELD_BROKEN), 1, "the break")
	var shards: int = 0
	for i in vfx.over.capacity:
		if vfx.over.tex[i] == FxTex.SHARD:
			shards += 1
	assert_eq(shards, 6, "six shards")
	await wait_frames(6)
	assert_eq(vfx.wards_live(), 1, "Vlad's ward snapped, Irelia's stays")
	_stop(events)
	for n: Node in [vfx, irelia, vlad]:
		n.queue_free()
	await wait_frames(1)


## Vlad's mine, Ted's Rally Cry and Trap Cage emit their moments: the arming
## and the blast of each mine, the cage closing and opening (its stakes
## spring up and sink), the trapped enemy's rig pulsing toward the palette's
## ted and back, its alpha left alone.
func test_vlad_and_ted_emit_their_moments_and_the_cage_tints_the_rig() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(0, 0))
	var ted := await spawn_frozen(TED, Vector2(-60, 0))
	var hog := await spawn_frozen(HOG, Vector2(400, 0))
	var vfx := _vfx()
	var events := _record()
	var before: Array[Node] = get_children()
	(vlad.get_node("AbilitySystem") as AbilitySystem).active_ability.execute(vlad)
	assert_eq(_count(events, FxEvents.MINE_ARMED), 1, "the mine arms")
	var mine: Mine = null
	for n in get_children():
		if n is Mine and not before.has(n):
			mine = n as Mine
	assert_true(mine != null and mine.source_ability != null, "the mine knows its ability (its recipe)")
	if mine != null:
		mine._explode()
		assert_eq(_count(events, FxEvents.MINE_EXPLODED), 1, "the blast")
		assert_false(mine.visible, "the mine itself goes out of sight")
	var cage_ability: AbilityBase = (ted.get_node("AbilitySystem") as AbilitySystem).ultimate_ability
	cage_ability.duration = 0.8  # Ted's own copy: the cage opens within the test
	cage_ability.ability_range = 1000.0  # and its throw reaches the Hog 460 px away
	cage_ability.execute(ted, hog)
	assert_eq(_count(events, FxEvents.CAGE_CLOSED), 1, "the cage closes")
	assert_true(vfx.stakes_front.live + vfx.stakes_back.live >= AbilityVfx.STAKES_MIN, "stakes around it")
	var cage: TrapCage = null
	for n in get_children():
		if n is TrapCage:
			cage = n as TrapCage
	assert_true(cage != null and cage.trapped_enemies.has(hog), "the Hog is trapped")
	var rig := (hog as EntityBase).visual_root()
	assert_true(rig is CharacterRig, "the Hog draws through its rig")
	await wait_seconds(0.4)
	var tint: Color = Color.WHITE.lerp(UiPalette.get_default().ted, TrapCage.TRAP_TINT_WEIGHT)
	assert_true(rig.modulate.b < 1.0 and rig.modulate.b >= tint.b - 0.001, "the rig pulses toward ted (%s)" % rig.modulate)
	assert_eq(rig.modulate.a, 1.0, "its alpha untouched")
	await wait_seconds(0.5)
	assert_eq(_count(events, FxEvents.CAGE_OPENED), 1, "the cage opens")
	assert_eq(rig.modulate, Color.WHITE, "the rig is back to its own colours")
	await wait_seconds(AbilityVfx.STAKE_SINK + 0.1)
	assert_eq(vfx.stakes_front.live + vfx.stakes_back.live, 0, "the stakes sank")
	_stop(events)
	for n: Node in [vfx, vlad, ted, hog]:
		n.queue_free()
	await wait_frames(1)


## River's staff heal reports what it healed: AbilityVfx hops pluses over,
## VfxManager shows a "+N" in heal green beside (not added to) the damage
## numbers. War Cry (Ted's own copy) marks every other hero it boosts.
func test_heals_and_rallies_reach_the_vfx() -> void:
	var river := await spawn_frozen(RIVER, Vector2(0, 0))
	var vlad := await spawn_frozen(VLAD, Vector2(100, 0))
	var ted := await spawn_frozen(TED, Vector2(50, 60))
	var vfx := _vfx()
	var numbers := VfxManager.new()
	add_child(numbers)
	await wait_frames(1)
	var events := _record()
	var system := river.get_node("AbilitySystem") as AbilitySystem
	system.active_ability.execute(river)  # the heal staff
	(vlad.get_node("HeroStats") as HeroStatsComponent).take_damage(40.0)
	var hp: float = vlad.get_health()
	system.basic_attack.execute(river, vlad)
	var healed: float = vlad.get_health() - hp
	assert_true(healed > 0.0, "healed")
	assert_eq(_count(events, FxEvents.HEAL_SHOT), 1, "the heal shot")
	assert_near(_value(events, FxEvents.HEAL_SHOT), healed, 0.001, "reports the HP healed")
	var pluses: int = 0
	for i in vfx.over.capacity:
		if vfx.over.tex[i] == FxTex.PLUS:
			pluses += 1
	assert_eq(pluses, 5, "three pluses hop over, two rise off Vlad")
	if numbers._view_rect.has_point(vlad.global_position):
		assert_eq(numbers.heals_on(vlad), PackedFloat32Array([healed]), "+N on Vlad")
		numbers.show_hit(vlad, 3.0)
		numbers.show_heal(vlad, 2.0)
		assert_eq(numbers.numbers_on(vlad), PackedFloat32Array([3.0]), "the damage number stands apart")
		assert_eq(numbers.heals_on(vlad), PackedFloat32Array([healed + 2.0]), "heals add up with heals")
		numbers.show_heal(vlad, 0.2)
		assert_eq(numbers.heals_on(vlad), PackedFloat32Array([healed + 2.0]), "a heal on a full bar shows nothing")
	else:
		skip("the test viewport does not show Vlad")
	var rally := (ted.get_node("AbilitySystem") as AbilitySystem).active_ability as TedActiveRally
	rally.aura_radius = 300.0  # War Cry on Ted's own copy
	rally.execute(ted)
	assert_eq(_count(events, FxEvents.RALLIED), 2 + (ted as Ted).get_pets().size(), "River, Vlad and the pets, not Ted himself")
	_stop(events)
	for n: Node in [vfx, numbers, river, vlad, ted]:
		n.queue_free()
	await wait_frames(1)


## RingPulse.spawn: the ring is drawn for its whole duration (its free waits
## for the tweens) at a constant line width, then frees itself.
func test_ring_pulse_lives_its_duration() -> void:
	var ring := RingPulse.spawn(self, Vector2(10, 10), UiPalette.get_default().gold, 10.0, 4.0, 3.0, 0.3, 0)
	await wait_frames(3)
	assert_true(is_instance_valid(ring) and ring.is_inside_tree(), "still showing after its first tween steps")
	if is_instance_valid(ring):
		assert_true(ring.scale.x > 1.0, "growing")
		assert_near(ring.width * ring.scale.x, 3.0, 0.3, "the line keeps its width")
	await wait_seconds(0.4)
	assert_false(is_instance_valid(ring), "freed after its duration")


## River's card wears her weapon on its portrait and swaps it with her mode;
## a hero with one weapon has no badge.
func test_river_card_shows_her_weapon() -> void:
	var river := await spawn_frozen(RIVER, Vector2(0, 0))
	var vlad := await spawn_frozen(VLAD, Vector2(100, 0))
	var river_card := (load(HUD_CARD) as PackedScene).instantiate() as HeroHudCard
	var vlad_card := (load(HUD_CARD) as PackedScene).instantiate() as HeroHudCard
	add_child(river_card)
	add_child(vlad_card)
	river_card.bind_to_hero(river)
	vlad_card.bind_to_hero(vlad)
	var badge := river_card.get_node(^"%Weapon") as AbilitySlot
	var basic := (river.get_node("AbilitySystem") as AbilitySystem).basic_attack as RiverBasicAttack
	assert_true(badge.visible, "River's card shows her weapon")
	assert_eq(badge.slot_type, AbilityBase.AbilityType.BASIC_ATTACK)
	assert_true(badge.icon_texture == basic.icon, "the rifle")
	(river.get_node("AbilitySystem") as AbilitySystem).active_ability.execute(river)
	await wait_frames(1)
	assert_true(badge.icon_texture == basic.heal_icon, "the heal staff after the swap")
	assert_false((vlad_card.get_node(^"%Weapon") as CanvasItem).visible, "Vlad's card has no badge")
	for n: Node in [river_card, vlad_card, river, vlad]:
		n.queue_free()
	await wait_frames(1)


## The node lives with the match: World.tscn's Vfx/Abilities (group
## ability_vfx, camera wired) over the characters and under VfxManager's
## numbers, its ground layer at absolute z 0.
func test_world_wires_the_ability_vfx() -> void:
	var world := (load(WORLD) as PackedScene).instantiate()
	var vfx := world.get_node_or_null(^"Vfx/Abilities") as AbilityVfx
	assert_true(vfx != null, "World/Vfx/Abilities is an AbilityVfx")
	if vfx != null:
		assert_true(vfx.is_in_group(&"ability_vfx"), "group ability_vfx")
		assert_eq(vfx.camera, world.get_node(^"MainCam"), "camera wired")
		assert_eq([vfx.z_as_relative, vfx.z_index], [false, 45], "over the characters, under the numbers (50)")
		var ground := vfx.ground
		assert_true(ground != null and ground == vfx.get_node(^"Ground"), "ground wired")
		if ground != null:
			assert_eq(ground.vfx, vfx, "the ground layer paints for it")
			assert_eq([ground.z_as_relative, ground.z_index], [false, 0], "on the ground, under the characters")
	world.free()


## The pools never grow past their caps and nothing draws from the global RNG,
## which drives gameplay.
func test_pools_stay_capped_and_the_global_rng_untouched() -> void:
	var stubs := _stubs()
	var programs: Dictionary[String, Array] = _programs(stubs[0], stubs[1], stubs[2] as Shield)
	var vfx := _vfx()
	seed(4242)
	var expected: Array[int] = []
	for _i in 8:
		expected.append(randi())
	seed(4242)
	for round_i in 12:
		for label: String in programs:
			for step: Callable in programs[label]:
				if step.is_valid():
					step.call(vfx)
		assert_true(vfx.over.live <= AbilityVfx.OVER_CAP and vfx.marks.live <= AbilityVfx.MARK_CAP, "round %d" % round_i)
		assert_true(vfx.stakes_front.live <= AbilityVfx.STAKE_CAP and vfx.stakes_back.live <= AbilityVfx.STAKE_CAP, "stakes")
		await wait_frames(2)
	assert_eq([vfx.over.capacity, vfx.over.pos.size(), vfx.under.capacity, vfx.marks.capacity],
			[AbilityVfx.OVER_CAP, AbilityVfx.OVER_CAP, AbilityVfx.UNDER_CAP, AbilityVfx.MARK_CAP], "never grew")
	var after: Array[int] = []
	for _i in 8:
		after.append(randi())
	assert_eq(after, expected, "the vfx drew no global random number")
	vfx.queue_free()
	_free_stubs(stubs)
	await wait_frames(1)


# ---------- helpers ----------

## A fresh AbilityVfx. The test viewport shows the world from 0,0 down and
## right (grown by CULL_MARGIN), where the tests place their characters.
func _vfx() -> AbilityVfx:
	var vfx := AbilityVfx.new()
	add_child(vfx)
	return vfx


## A caster and a foe (plain Node2Ds in view, in group Hero / not) and a
## Shield on the caster (not in the tree): [caster, foe, shield].
func _stubs() -> Array[Object]:
	var caster := Node2D.new()
	caster.position = Vector2(40.0, 40.0)
	caster.add_to_group(&"Hero")
	add_child(caster)
	var foe := Node2D.new()
	foe.position = Vector2(100.0, 40.0)
	add_child(foe)
	var shield := Shield.new()
	shield.shield_amount = 18.0
	shield.owner_hero = caster
	return [caster, foe, shield]


func _free_stubs(stubs: Array[Object]) -> void:
	(stubs[0] as Node).queue_free()
	(stubs[1] as Node).queue_free()
	(stubs[2] as Node).free()


## Everything the vfx has alive or waiting.
func _shown(vfx: AbilityVfx) -> int:
	var prims: int = 0
	for kind: AbilityVfx.Prim in [AbilityVfx.Prim.RING, AbilityVfx.Prim.DISC, AbilityVfx.Prim.TRACER, AbilityVfx.Prim.BEAM]:
		prims += vfx.prims_of(kind)
	return prims + vfx.over.live + vfx.under.live + vfx.marks.live + vfx.stakes_front.live \
			+ vfx.stakes_back.live + vfx.wards_live() + vfx.halos_live() + vfx.cages_live()


## Every cast, hit and event program of the hero recipes: [setup, program],
## callables on an AbilityVfx. A ward's hit, break and expiry are set up by
## its SHIELD_UP, a cage's opening by its closing; the others need none.
func _programs(caster_obj: Object, foe_obj: Object, shield: Shield) -> Dictionary[String, Array]:
	var caster := caster_obj as Node2D
	var foe := foe_obj as Node2D
	var hit := func(path: String) -> Callable:
		return func(vfx: AbilityVfx) -> void:
			vfx._on_damage_applied(DamagePacket.make(caster, foe, 10.0, load(path) as AbilityBase))
	var cast := func(path: String) -> Callable:
		return func(vfx: AbilityVfx) -> void:
			vfx._on_ability_cast(caster, load(path) as AbilityBase, foe)
	var event := func(path: String, name_: StringName, source: Node, pos: Vector2, value: float) -> Callable:
		return func(vfx: AbilityVfx) -> void:
			vfx._on_ability_event(source, load(path) as AbilityBase if not path.is_empty() else null, name_, pos, value)
	var then := func(first: Callable, second: Callable) -> Array:
		return [first, second]
	var at := foe.global_position
	var shield_up: Callable = event.call(SHIELD, FxEvents.SHIELD_UP, shield, caster.global_position, 18.0)
	var cage_closed: Callable = event.call(CAGE, FxEvents.CAGE_CLOSED, null, at, 150.0)
	var programs: Dictionary[String, Array] = {}
	var all: Dictionary = {
		"strike vlad": hit.call(BASIC_VLAD),
		"strike irelia": hit.call(BASIC_IRELIA),
		"claw ted": hit.call(BASIC_TED),
		"sniper river": hit.call(BASIC_RIVER),
		"shield cast": cast.call(SHIELD),
		"taunt cast": cast.call(TAUNT),
		"rally cast": cast.call(RALLY),
		"swap cast": cast.call(SWAP),
		"mine cast": cast.call(MINE),
		"blood bomb": cast.call(BOMB),
		"shield up": shield_up,
		"shield hit": then.call(shield_up, event.call("", FxEvents.SHIELD_HIT, caster, caster.global_position, 5.0)),
		"shield broken": then.call(shield_up, event.call("", FxEvents.SHIELD_BROKEN, caster, caster.global_position, 0.0)),
		"shield expired": then.call(shield_up, event.call("", FxEvents.SHIELD_EXPIRED, caster, caster.global_position, 0.0)),
		"taunted": event.call(TAUNT, FxEvents.TAUNTED, foe, caster.global_position, 5.0),
		"rallied": event.call(RALLY, FxEvents.RALLIED, caster, at, 5.0),
		"last stand": event.call(REGEN, FxEvents.LAST_STAND, caster, caster.global_position, 2.0),
		"mine armed": event.call(MINE, FxEvents.MINE_ARMED, null, at, 100.0),
		"mine exploded": event.call(MINE, FxEvents.MINE_EXPLODED, null, at, 100.0),
		"cage closed": cage_closed,
		"cage opened": then.call(cage_closed, event.call(CAGE, FxEvents.CAGE_OPENED, null, at, 150.0)),
		"kit landed": event.call(DROP, FxEvents.KIT_LANDED, null, at, 60.0),
		"kit picked": event.call(DROP, FxEvents.KIT_PICKED, caster, caster.global_position, 30.0),
		"heal shot": event.call(BASIC_RIVER, FxEvents.HEAL_SHOT, caster, at, 9.0),
		"chain heal": event.call(BASIC_RIVER, FxEvents.CHAIN_HEAL, caster, at, 9.0),
	}
	for label: String in all:
		var steps: Variant = all[label]
		programs[label] = steps if steps is Array else [Callable(), steps]
	return programs


## Puffs and dust clouds alive or waiting in the vfx's sprite buffers.
func _puffs(vfx: AbilityVfx) -> int:
	var n: int = 0
	for buf: FxSpriteBuffer in [vfx.over, vfx.under]:
		for i in buf.capacity:
			if buf.tex[i] == FxTex.PUFF or buf.tex[i] == FxTex.DUST:
				n += 1
	return n


## Records every EventBus.ability_event: [the callback, [event, value]...]
## (stop with _stop).
func _record() -> Array:
	var recorded: Array = []
	var cb := func(_source: Node, _ability: AbilityBase, event: StringName, _pos: Vector2, value: float) -> void:
		recorded.append([event, value])
	recorded.append(cb)
	EventBus.ability_event.connect(cb)
	return recorded


func _stop(recorded: Array) -> void:
	EventBus.ability_event.disconnect(recorded[0] as Callable)
	# The callback captures `recorded`: drop it from there, or the two keep
	# each other (and this script, its abilities and their art) alive past exit.
	recorded[0] = null


func _count(recorded: Array, event: StringName) -> int:
	var n: int = 0
	for entry: Variant in recorded.slice(1):
		if (entry as Array)[0] == event:
			n += 1
	return n


func _value(recorded: Array, event: StringName) -> float:
	for entry: Variant in recorded.slice(1):
		if (entry as Array)[0] == event:
			return float((entry as Array)[1])
	return NAN

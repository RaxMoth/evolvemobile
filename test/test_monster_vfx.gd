extends TestCase

## The monster ability looks (Phase 7, 7.3): every ability of Grount, Nyxa
## and Gorrak carries an AbilityFxRecipe whose cue AbilityVfx plays (their
## passives' recipes colour the capstone moments); every monster program
## keeps the toning-down rules; the cleave, screech, dash, slam and stomp
## draw VfxManager's ground telegraphs (cone, lane, circle) at 35% alpha;
## the monster scripts emit their moments (dash, slam, stun, recruit,
## Rampage, Vampiric Rebirth, Unstoppable) and only emit; stun stars float
## above the head while the stun lasts; Call of the Herd rings its recruits;
## evolving shakes the camera; the pools never grow and draw no global
## random number.

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const NYXA := "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn"
const GORRAK := "res://Scenes/NPCs/Monster/Gorrak/Gorrak.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const ABILITIES := "res://Scenes/NPCs/Monster/"
const CLEAVE := ABILITIES + "Grount/abilities/grount_front_cleave.tres"
const DASH := ABILITIES + "Grount/abilities/grout_ram_dash.tres"
const SLAM := ABILITIES + "Grount/abilities/grount_ground_slam.tres"
const EVOLUTION := ABILITIES + "Grount/abilities/grount_evolution.tres"
const SCREECH := ABILITIES + "Nyxa/abilities/nyxa_screech.tres"
const SWOOP := ABILITIES + "Nyxa/abilities/nyxa_swoop.tres"
const SWARM := ABILITIES + "Nyxa/abilities/nyxa_night_swarm.tres"
const BLOOD := ABILITIES + "Nyxa/abilities/nyxa_blood_drinker.tres"
const CHOP := ABILITIES + "Gorrak/abilities/gorrak_cleaver.tres"
const AXE := ABILITIES + "Gorrak/abilities/gorrak_axe.tres"
const STOMP := ABILITIES + "Gorrak/abilities/gorrak_stomp.tres"
const HIDE := ABILITIES + "Gorrak/abilities/gorrak_bristled_hide.tres"
## Each monster's cues: ability_1, ability_2, ability_3, passive.
const CUES: Dictionary[String, Array] = {
	GROUNT: [&"cleave", &"ram_dash", &"slam", &"rampage"],
	NYXA: [&"screech", &"swoop", &"swarm", &"rebirth"],
	GORRAK: [&"cleave", &"axe", &"stomp", &"unstoppable"],
}


func before_each() -> void:
	# The capstone tests seed a monster tree: the played side applies it.
	play_side(MatchRewards.Side.MONSTER)
	if is_isolated():
		PersistedData.wipe_progress(false)


func after_each() -> void:
	if is_isolated():
		PersistedData.wipe_progress(false)


## Every slot of the three monsters names its cue; the colours are palette
## tokens (test_ability_vfx checks every recipe file); Gorrak's axe recipe
## hides a part his body has.
func test_every_monster_ability_has_a_known_recipe() -> void:
	for path: String in CUES:
		var m := (load(path) as PackedScene).instantiate() as MonsterBase
		var slots: Array[AbilityBase] = [m.ability_1, m.ability_2, m.ability_3, m.passive_ability]
		for k in slots.size():
			var ability := slots[k]
			assert_true(ability.fx != null, "%s: %s has a recipe" % [m.name, ability.ability_name])
			if ability.fx != null:
				assert_eq(ability.fx.cue, CUES[path][k], "%s: %s" % [m.name, ability.ability_name])
				assert_true(ability.fx.cue in AbilityVfx.CUES, "%s is a program" % ability.fx.cue)
		if path == GORRAK:
			var body := m.get_node(^"Rig/GorrakBody") as RigBody
			assert_true(body.part_order.has(String(m.ability_2.fx.prop_part)), "his body has the axe part")
		m.free()


## Each program alone: at most MAX_PUFFS puffs or dust clouds, rings and
## sound arcs at most MAX_RING_WIDTH wide, blasts, slashes and stars over a
## body gone within HEAD_COVER; its telegraphs at 35% alpha.
func test_every_monster_program_keeps_the_toning_down_rules() -> void:
	var stubs := _stubs()
	var programs := _programs(stubs[0] as Node2D, stubs[1] as Node2D)
	assert_true(programs.size() >= 16, "every monster cue and event (%d)" % programs.size())
	for label: String in programs:
		var pair := _pair()
		var mgr: VfxManager = pair[0]
		var vfx: AbilityVfx = pair[1]
		var puffs_before: int = _puffs(vfx)
		(programs[label] as Callable).call(vfx)
		assert_true(_shown(vfx) + mgr.telegraphs_live() > 0, "%s shows something" % label)
		var puffs: int = _puffs(vfx) - puffs_before
		assert_true(puffs <= AbilityVfx.MAX_PUFFS, "%s: %d puffs" % [label, puffs])
		assert_true(vfx.widest_ring() <= AbilityVfx.MAX_RING_WIDTH, "%s: rings at most 3 px" % label)
		assert_true(vfx.longest_prim(AbilityVfx.Prim.DISC) <= AbilityVfx.HEAD_COVER, "%s: a blast over a body" % label)
		for i in vfx.over.capacity:
			if vfx.over.tex[i] in [FxTex.SLASH, FxTex.CLAW, FxTex.STAR, FxTex.BUBBLE]:
				assert_true(vfx.over.life[i] <= AbilityVfx.HEAD_COVER, "%s: %s over a body for %.2f s" % [
						label, vfx.over.tex[i].resource_path.get_file(), vfx.over.life[i]])
		for c in mgr.get_children():
			var ring := c as RingPulse
			if ring != null and ring.visible:
				assert_near(ring.default_color.a, VfxManager.TELEGRAPH_ALPHA, 0.001, "%s: telegraph alpha" % label)
				assert_near(ring.width * ring.scale.x, mgr.telegraph_width, 0.001, "%s: telegraph line width" % label)
		mgr.queue_free()
	_free_stubs(stubs)
	await wait_frames(1)


## The cleave and the screech draw a cone, a full-circle cleave (Whirlwind) a
## circle, a dash its lane (the bar crossing it with the dash), the slam's
## leap the landing circle that fills over the airtime.
func test_telegraphs_take_each_ability_shape() -> void:
	var stubs := _stubs()
	var caster := stubs[0] as Node2D
	var foe := stubs[1] as Node2D
	var pair := _pair()
	var mgr: VfxManager = pair[0]
	var vfx: AbilityVfx = pair[1]
	vfx._on_ability_cast(caster, load(CLEAVE) as AbilityBase, foe)
	vfx._on_ability_cast(caster, load(SCREECH) as AbilityBase, foe)
	assert_eq(mgr.telegraph_shapes(), PackedInt32Array([VfxManager.Shape.CONE, VfxManager.Shape.CONE]), "two cones")
	var whirl := (load(CHOP) as BullFrontCleave).duplicate() as BullFrontCleave
	whirl.cone_angle = BullFrontCleave.FULL_CIRCLE
	vfx._on_ability_cast(caster, whirl, foe)
	var dash := load(DASH) as BullRamDash
	vfx._on_ability_event(caster, dash, FxEvents.DASH_STARTED, caster.global_position + Vector2(200.0, 0.0), 40.0)
	assert_eq(mgr.telegraph_shapes(), PackedInt32Array([VfxManager.Shape.CONE, VfxManager.Shape.CONE,
			VfxManager.Shape.CIRCLE, VfxManager.Shape.LANE]), "Whirlwind's circle, the dash's lane")
	var lane_bar := mgr._t_fill[3]
	var start: Vector2 = lane_bar.position
	await wait_frames(6)
	assert_true(lane_bar.position.x > start.x + 1.0, "the bar crosses the lane with the dash")
	vfx._on_ability_event(caster, load(SLAM) as AbilityBase, FxEvents.SLAM_LEAP, foe.global_position, 1.0)
	assert_eq(mgr._t_shape[0], VfxManager.Shape.CIRCLE, "the landing circle (the oldest slot recycled)")
	assert_true(mgr._t_outline[0].position.distance_to(foe.global_position) < 0.5, "at the landing point")
	assert_near(mgr._t_outline[0].scale.x, (load(SLAM) as BullGroundSlam).slam_radius, 0.001, "the slam's radius")
	mgr.queue_free()
	_free_stubs(stubs)
	await wait_frames(1)


## Grount's dash and slam emit their moments: DASH_STARTED with the end point
## and the lane's half-width, DASH_ENDED where he stopped (the trail fades and
## frees), SLAM_LEAP on the take-off and SLAM_LANDED with the radius.
func test_grount_dash_and_slam_emit_their_moments() -> void:
	var pair := _pair()
	var mgr: VfxManager = pair[0]
	var vfx: AbilityVfx = pair[1]
	var g := (await spawn_frozen(GROUNT, Vector2(100, 100))) as MonsterBase
	var v := await spawn_frozen(VLAD, Vector2(300, 100))
	var recorded := _record()
	var dash := g.ability_2 as BullRamDash
	assert_true(g._cast("ability_2", dash, v))
	assert_eq(_count(recorded, FxEvents.DASH_STARTED), 1)
	assert_near(_value(recorded, FxEvents.DASH_STARTED), dash.get_hit_radius(), 0.001, "the lane's half-width")
	assert_eq(vfx.trails_live(), 1, "a trail follows him")
	assert_true(mgr.telegraph_shapes().has(VfxManager.Shape.LANE), "the lane")
	await wait_seconds(0.8)
	assert_false(dash.is_dashing)
	assert_eq(_count(recorded, FxEvents.DASH_ENDED), 1, "one end")
	assert_eq(vfx.trails_live(), 0, "faded and freed")
	g.gain_xp(1000.0)
	var slam := g.ability_3 as BullGroundSlam
	assert_true(g._cast("ability_3", slam, v))
	assert_eq(_count(recorded, FxEvents.SLAM_LEAP), 1, "the take-off")
	assert_eq(_count(recorded, FxEvents.SLAM_LANDED), 0, "not landed yet")
	await wait_seconds(slam.jump_duration + 0.2)
	assert_eq(_count(recorded, FxEvents.SLAM_LANDED), 1, "the impact")
	assert_near(_value(recorded, FxEvents.SLAM_LANDED), slam.slam_radius, 0.001)
	_stop(recorded)
	mgr.queue_free()
	g.queue_free()
	v.queue_free()
	await wait_frames(1)


## Warcry Stomp stuns: STUNNED per target, three stars circling above its
## head (never over it) that end with the stun.
func test_stun_stars_float_above_the_head_while_the_stun_lasts() -> void:
	var pair := _pair()
	var mgr: VfxManager = pair[0]
	var vfx: AbilityVfx = pair[1]
	var g := (await spawn_frozen(GORRAK, Vector2(100, 100))) as MonsterBase
	var v := (await spawn_frozen(VLAD, Vector2(160, 100))) as EntityBase
	var recorded := _record()
	var stomp := g.ability_3 as BullGroundSlam
	stomp.execute(g, v, 1.0)
	await wait_seconds(stomp.jump_duration + 0.1)
	assert_eq(_count(recorded, FxEvents.STUNNED), 1, "Vlad stunned")
	assert_true(v.is_stunned())
	assert_eq(vfx.stuns_live(), 1, "stars")
	var lowest: float = CharacterRig.head_top_of(v).y - 6.0 + AbilityVfx.STUN_ORBIT * 0.35
	assert_true(lowest < CharacterRig.head_top_of(v).y, "the stars circle above the head")
	v.clear_stun()  # a frozen entity's stun never decays: end it as Guardian Angel does
	await wait_frames(2)
	assert_eq(vfx.stuns_live(), 0, "gone with the stun")
	_stop(recorded)
	mgr.queue_free()
	g.queue_free()
	v.queue_free()
	await wait_frames(1)


## Echo Strike: the swoop's turn is DASH_TURNED (a second lane back), once.
func test_echo_strike_turns_the_streak() -> void:
	if not require_isolated():
		return
	PersistedData.set_skill_rank(&"monster_nyxa", &"ny_echo", 1)
	PersistedData.set_equipped_capstone(&"monster_nyxa", &"ny_echo")
	var pair := _pair()
	var mgr: VfxManager = pair[0]
	var n := (await spawn_frozen(NYXA, Vector2(100, 100))) as MonsterBase
	var v := await spawn_frozen(VLAD, Vector2(250, 100))
	var recorded := _record()
	assert_true(n._cast("ability_2", n.ability_2, v))
	await wait_seconds(1.0)
	assert_eq(_count(recorded, FxEvents.DASH_TURNED), 1, "one turn")
	assert_eq(_count(recorded, FxEvents.DASH_ENDED), 1, "one end, after the return pass")
	_stop(recorded)
	mgr.queue_free()
	n.queue_free()
	v.queue_free()
	await wait_frames(1)


## Rampage reports the HP it healed (VfxManager shows the "+N"); Vampiric
## Rebirth reports the scatter and the re-form with where the bats were;
## Unstoppable reports the taunt and the cage it shrugs off. Every moment
## carries the monster's passive (its recipe colours it).
func test_capstone_moments_reach_the_vfx() -> void:
	if not require_isolated():
		return
	PersistedData.set_skill_rank(&"monster_grount", &"g4_rampage", 1)
	PersistedData.set_equipped_capstone(&"monster_grount", &"g4_rampage")
	PersistedData.set_skill_rank(&"monster_nyxa", &"ny_rebirth", 1)
	PersistedData.set_equipped_capstone(&"monster_nyxa", &"ny_rebirth")
	PersistedData.set_skill_rank(&"monster_gorrak", &"gk_unstoppable", 1)
	PersistedData.set_equipped_capstone(&"monster_gorrak", &"gk_unstoppable")
	var pair := _pair()
	var mgr: VfxManager = pair[0]
	var recorded := _record()
	# Rampage
	var g := (await spawn_frozen(GROUNT, Vector2(100, 100))) as MonsterBase
	var v := (await spawn_frozen(VLAD, Vector2(160, 100))) as HeroBase
	g.current_health = 0.5 * g.get_max_health()
	EventBus.deal_damage(g, v, 99999.0)
	await wait_frames(1)
	assert_eq(_count(recorded, FxEvents.RAMPAGE), 1, "a hero kill")
	assert_near(_value(recorded, FxEvents.RAMPAGE), 0.15 * g.get_max_health(), 0.01, "the HP healed")
	assert_eq(_ability(recorded, FxEvents.RAMPAGE), g.passive_ability, "his passive colours it")
	var heals := mgr.heals_on(g)
	assert_true(heals.size() == 1 and absf(heals[0] - 0.15 * g.get_max_health()) < 0.01, "+N on him: %s" % str(heals))
	g.queue_free()
	# Vampiric Rebirth
	var n := (await spawn_frozen(NYXA, Vector2(100, 100))) as MonsterBase
	var hero := (await spawn_frozen(VLAD, Vector2(220, 100))) as HeroBase
	EventBus.deal_damage(hero, n, 99999.0)
	assert_eq(_count(recorded, FxEvents.SCATTERED), 1, "the bats burst")
	await wait_seconds(3.1)
	assert_eq(_count(recorded, FxEvents.REFORMED), 1, "and re-form")
	assert_true(_pos(recorded, FxEvents.REFORMED).distance_to(n.global_position) > 100.0,
			"from where the bats were to the re-form point 400 px off the hero")
	n.queue_free()
	hero.queue_free()
	# Unstoppable
	var gk := (await spawn_frozen(GORRAK, Vector2(100, 100))) as MonsterBase
	var irelia := await spawn_frozen(IRELIA, Vector2(200, 100))
	var ted := await spawn_frozen(TED, Vector2(100, 700))
	(irelia.get_node(^"AbilitySystem") as AbilitySystem).ultimate_ability.execute(irelia)
	assert_eq(_count(recorded, FxEvents.CC_SHRUGGED), 1, "the taunt")
	(ted.get_node(^"AbilitySystem") as AbilitySystem).ultimate_ability.execute(ted, gk)
	assert_eq(_count(recorded, FxEvents.CC_SHRUGGED), 2, "and the cage")
	assert_eq(_ability(recorded, FxEvents.CC_SHRUGGED), gk.passive_ability, "in his passive's colours")
	_stop(recorded)
	for c in get_children():
		if c is TrapCage:
			c.queue_free()
	for node: Node in [gk, irelia, ted, mgr]:
		node.queue_free()
	if is_instance_valid(v):
		v.queue_free()
	await wait_frames(1)


## Call of the Herd: RECRUITED per Hog; each gets a ring at its feet while it
## fights in the warband, gone once the warband ends.
func test_call_of_the_herd_rings_its_recruits() -> void:
	if not require_isolated():
		return
	PersistedData.set_skill_rank(&"monster_gorrak", &"gk_warband", 1)
	PersistedData.set_equipped_capstone(&"monster_gorrak", &"gk_warband")
	var pair := _pair()
	var mgr: VfxManager = pair[0]
	var vfx: AbilityVfx = pair[1]
	var g := (await spawn_frozen(GORRAK, Vector2(100, 100))) as MonsterBase
	var hog := (await spawn_frozen(HOG, Vector2(180, 100))) as MobBase
	var v := await spawn_frozen(VLAD, Vector2(100, 360))
	var recorded := _record()
	var stomp := g.ability_3 as BullGroundSlam
	stomp.execute(g, v, 1.0)
	await wait_seconds(stomp.jump_duration + 0.2)
	assert_eq(_count(recorded, FxEvents.RECRUITED), 1, "the Hog joined")
	assert_near(_value(recorded, FxEvents.RECRUITED), stomp.recruit_duration, 0.001)
	assert_eq(vfx.bands_live(), 1, "a ring at its feet")
	hog.warband_timer.start(0.05)
	await wait_seconds(0.2)
	assert_false(hog.is_in_warband())
	assert_eq(vfx.bands_live(), 0, "gone with the warband")
	_stop(recorded)
	for node: Node in [g, hog, v, mgr]:
		node.queue_free()
	await wait_frames(1)


## The monster evolving shakes the match camera (trauma_evolve).
func test_evolution_shakes_the_camera() -> void:
	if not GameCamera.shake_setting_on():
		skip("screen shake is off in Settings")
		return
	var mgr := VfxManager.new()
	var cam := GameCamera.new()
	mgr.camera = cam
	add_child(mgr)
	var g := (await spawn_frozen(GROUNT, Vector2(100, 100))) as MonsterBase
	assert_near(cam.trauma, 0.0, 0.0001)
	g.gain_xp(1000.0)
	assert_true(cam.trauma >= mgr.trauma_evolve - 0.001, "trauma on the evolution (%.2f)" % cam.trauma)
	g.queue_free()
	mgr.queue_free()
	cam.free()
	await wait_frames(1)


## The monster programs never grow a pool past its cap and draw no global
## random number (it drives gameplay).
func test_monster_pools_stay_capped_and_the_global_rng_untouched() -> void:
	var stubs := _stubs()
	var programs := _programs(stubs[0] as Node2D, stubs[1] as Node2D)
	var pair := _pair()
	var mgr: VfxManager = pair[0]
	var vfx: AbilityVfx = pair[1]
	seed(777)
	var expected: Array[int] = []
	for _i in 8:
		expected.append(randi())
	seed(777)
	for round_i in 10:
		for label: String in programs:
			(programs[label] as Callable).call(vfx)
		assert_true(vfx.over.live <= AbilityVfx.OVER_CAP and vfx.marks.live <= AbilityVfx.MARK_CAP, "round %d" % round_i)
		assert_true(vfx.trails_live() <= AbilityVfx.TRAIL_CAP and vfx.swarms_live() <= AbilityVfx.SWARM_CAP, "trails, swarms")
		assert_true(vfx.axes_live() <= AbilityVfx.AXE_CAP and vfx.stuns_live() <= AbilityVfx.STUN_CAP, "axes, stuns")
		assert_true(mgr.telegraphs_live() <= VfxManager.TELEGRAPH_CAP, "telegraphs")
		await wait_frames(2)
	assert_eq([vfx.over.capacity, vfx._r_path.size(), vfx._s_phase.size()],
			[AbilityVfx.OVER_CAP, AbilityVfx.TRAIL_CAP * AbilityVfx.TRAIL_POINTS,
			AbilityVfx.SWARM_CAP * AbilityVfx.SWARM_BATS_BROOD], "never grew")
	var after: Array[int] = []
	for _i in 8:
		after.append(randi())
	assert_eq(after, expected, "the vfx drew no global random number")
	mgr.queue_free()
	_free_stubs(stubs)
	await wait_frames(1)


# ---------- helpers ----------

## A VfxManager with an AbilityVfx under it wired to its telegraphs, as in
## World.tscn: [manager, vfx]. The test viewport shows the world from 0,0
## down and right, where the tests place their characters.
func _pair() -> Array:
	var mgr := VfxManager.new()
	add_child(mgr)
	var vfx := AbilityVfx.new()
	vfx.telegraphs = mgr
	mgr.add_child(vfx)
	return [mgr, vfx]


## A caster and a foe: plain Node2Ds in view.
func _stubs() -> Array[Object]:
	var caster := Node2D.new()
	caster.position = Vector2(80.0, 80.0)
	add_child(caster)
	var foe := Node2D.new()
	foe.position = Vector2(160.0, 80.0)
	add_child(foe)
	return [caster, foe]


func _free_stubs(stubs: Array[Object]) -> void:
	for o in stubs:
		(o as Node).queue_free()


## Everything the vfx has alive or waiting.
func _shown(vfx: AbilityVfx) -> int:
	var prims: int = 0
	for kind: AbilityVfx.Prim in [AbilityVfx.Prim.RING, AbilityVfx.Prim.DISC, AbilityVfx.Prim.TRACER,
			AbilityVfx.Prim.BEAM, AbilityVfx.Prim.ARC]:
		prims += vfx.prims_of(kind)
	return prims + vfx.over.live + vfx.under.live + vfx.marks.live + vfx.trails_live() + vfx.swarms_live() \
			+ vfx.axes_live() + vfx.stuns_live() + vfx.bands_live()


func _puffs(vfx: AbilityVfx) -> int:
	var n: int = 0
	for buf: FxSpriteBuffer in [vfx.over, vfx.under]:
		for i in buf.capacity:
			if buf.tex[i] == FxTex.PUFF or buf.tex[i] == FxTex.DUST:
				n += 1
	return n


## Every monster cast and event program, as callables on an AbilityVfx. The
## shared .tres are only read; the axe and the swarm run on copies set
## flying / running by hand.
func _programs(caster: Node2D, foe: Node2D) -> Dictionary[String, Callable]:
	var cast := func(ability: AbilityBase) -> Callable:
		return func(vfx: AbilityVfx) -> void:
			vfx._on_ability_cast(caster, ability, foe)
	var event := func(ability: AbilityBase, name_: StringName, source: Node, pos: Vector2, value: float) -> Callable:
		return func(vfx: AbilityVfx) -> void:
			vfx._on_ability_event(source, ability, name_, pos, value)
	var then := func(first: Callable, second: Callable) -> Callable:
		return func(vfx: AbilityVfx) -> void:
			first.call(vfx)
			second.call(vfx)
	var whirl := (load(CHOP) as BullFrontCleave).duplicate() as BullFrontCleave
	whirl.cone_angle = BullFrontCleave.FULL_CIRCLE
	var axe := (load(AXE) as ThrownAxe).duplicate() as ThrownAxe
	axe._flying = true
	axe._dir = Vector2.RIGHT
	axe.axe_position = foe.global_position
	var swarm := (load(SWARM) as NightSwarm).duplicate() as NightSwarm
	swarm.execute(caster)
	var end := foe.global_position + Vector2(60.0, 0.0)
	var at := foe.global_position
	var dash_start: Callable = event.call(load(DASH), FxEvents.DASH_STARTED, caster, end, 40.0)
	var swoop_start: Callable = event.call(load(SWOOP), FxEvents.DASH_STARTED, caster, end, 40.0)
	var out: Dictionary[String, Callable] = {
		"grount cleave": cast.call(load(CLEAVE)),
		"gorrak chop": cast.call(load(CHOP)),
		"whirlwind": cast.call(whirl),
		"nyxa screech": cast.call(load(SCREECH)),
		"gorrak axe": cast.call(axe),
		"night swarm": cast.call(swarm),
		"ram dash start": dash_start,
		"ram dash end": then.call(dash_start, event.call(load(DASH), FxEvents.DASH_ENDED, caster, end, 0.0)),
		"swoop start": swoop_start,
		"swoop turn": then.call(swoop_start, event.call(load(SWOOP), FxEvents.DASH_TURNED, caster, caster.global_position, 40.0)),
		"slam leap": event.call(load(SLAM), FxEvents.SLAM_LEAP, caster, at, 1.0),
		"slam landed": event.call(load(SLAM), FxEvents.SLAM_LANDED, caster, at, 180.0),
		"stomp leap": event.call(load(STOMP), FxEvents.SLAM_LEAP, caster, caster.global_position, 0.6),
		"stomp landed": event.call(load(STOMP), FxEvents.SLAM_LANDED, caster, caster.global_position, 160.0),
		"stunned": event.call(load(STOMP), FxEvents.STUNNED, foe, at, 0.6),
		"rampage": event.call(load(EVOLUTION), FxEvents.RAMPAGE, caster, caster.global_position, 120.0),
		"scattered": event.call(load(BLOOD), FxEvents.SCATTERED, caster, caster.global_position, 0.0),
		"reformed": event.call(load(BLOOD), FxEvents.REFORMED, caster, at, 0.0),
		"shrugged": event.call(load(HIDE), FxEvents.CC_SHRUGGED, caster, at, 0.0),
	}
	return out


## Records every EventBus.ability_event: [the callback, [event, value, pos,
## ability]...] (stop with _stop).
func _record() -> Array:
	var recorded: Array = []
	var cb := func(_source: Node, ability: AbilityBase, event: StringName, pos: Vector2, value: float) -> void:
		recorded.append([event, value, pos, ability])
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


## The last `event`'s field `k` (1 value, 2 pos, 3 ability).
func _field(recorded: Array, event: StringName, k: int) -> Variant:
	var found: Variant = null
	for entry: Variant in recorded.slice(1):
		if (entry as Array)[0] == event:
			found = (entry as Array)[k]
	return found


func _value(recorded: Array, event: StringName) -> float:
	var v: Variant = _field(recorded, event, 1)
	return float(v) if v != null else NAN


func _pos(recorded: Array, event: StringName) -> Vector2:
	var v: Variant = _field(recorded, event, 2)
	return v as Vector2 if v != null else Vector2.INF


func _ability(recorded: Array, event: StringName) -> AbilityBase:
	return _field(recorded, event, 3) as AbilityBase

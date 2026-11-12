extends TestCase

## AbilitySlot (Scenes/UI/Hud): mirrors a CooldownSource (or set_cooldown)
## into its own shader material and the CooldownNumber label without a timer of
## its own, writes the shader only when the progress moved, pops once when the
## ability becomes ready (ready_flash, became_ready, the ultimate's glow),
## locks with a padlock and the stage numeral, wears the kit frame of its slot
## type, follows the ability's display icon (River's weapon mode), and goes
## dead with its owner (no countdown frozen on a fallen hero's card).

const SLOT := "res://Scenes/UI/Hud/AbilitySlot.tscn"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const NYXA := "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const KIT := "res://Assets/UI/Kit/%s.svg"
const READY_GLOW := "res://Assets/UI/Shaders/ready_glow.gdshader"


## One scripted slot.
class FixedSource extends CooldownSource:
	var p: float = 0.5
	var rem: float = 4.0
	var lock: bool = false
	var kind: AbilityBase.AbilityType = AbilityBase.AbilityType.ULTIMATE
	var tex: Texture2D = null

	func is_valid() -> bool:
		return true

	func slot_count() -> int:
		return 1

	func slot_type(_slot: int) -> AbilityBase.AbilityType:
		return kind

	func icon(_slot: int) -> Texture2D:
		return tex

	func progress(_slot: int) -> float:
		return p

	func remaining(_slot: int) -> float:
		return rem

	func locked(_slot: int) -> bool:
		return lock

	func lock_hint(_slot: int) -> String:
		return "II"


func _make_slot() -> AbilitySlot:
	var slot := (load(SLOT) as PackedScene).instantiate() as AbilitySlot
	add_child(slot)
	return slot


func _mat(slot: AbilitySlot) -> ShaderMaterial:
	return (slot.get_node(^"%Icon") as TextureRect).material as ShaderMaterial


## AbilitySlot.tscn stores every per-slot parameter (progress, ready_flash,
## locked), so each one reads back as a float.
func _param(slot: AbilitySlot, param: StringName) -> float:
	return float(_mat(slot).get_shader_parameter(param))


func _number(slot: AbilitySlot) -> Label:
	return slot.get_node(^"%CooldownNumber") as Label


func _glowing(slot: AbilitySlot) -> bool:
	return (slot.get_node(^"%Glow") as CanvasItem).visible


func test_mirrors_the_source_and_pops_once_when_ready() -> void:
	var slot := _make_slot()
	var src := FixedSource.new()
	slot.bind(src, 0)
	var fired: Array[int] = []
	slot.became_ready.connect(func(i: int) -> void: fired.append(i))
	await wait_frames(1)
	assert_near(_param(slot, &"progress"), 0.5, 0.001)
	assert_true(_number(slot).visible, "4 s left: digits shown")
	assert_eq(_number(slot).text, "4")
	assert_false(_glowing(slot), "a cooling ultimate does not glow")
	src.p = 1.0
	src.rem = 0.0
	await wait_frames(2)
	assert_eq(fired.size(), 1, "one became_ready on the transition")
	assert_eq(fired.front(), 0, "with the slot index")
	assert_near(_param(slot, &"progress"), 1.0, 0.0001)
	assert_false(_number(slot).visible, "no digits once ready")
	assert_true(_glowing(slot), "a ready ultimate glows")
	assert_true(_param(slot, &"ready_flash") > 0.5, "ready_flash starts near 1")
	assert_true((slot.get_node(^"%Body") as Control).scale.x > 1.0, "the slot pops")
	await wait_seconds(0.4)
	assert_near(_param(slot, &"ready_flash"), 0.0, 0.001, "the flash is over after 0.25 s")
	assert_eq((slot.get_node(^"%Body") as Control).scale, Vector2.ONE, "and the pop")
	assert_eq(fired.size(), 1, "staying ready does not pop again")
	src.p = 0.0
	src.rem = 20.0
	await wait_frames(2)
	assert_false(_glowing(slot), "cast again: the glow goes")
	src.p = 1.0
	src.rem = 0.0
	await wait_frames(2)
	assert_eq(fired.size(), 2, "ready again: a second pop")
	slot.queue_free()
	await wait_frames(1)


func test_a_slot_that_starts_ready_does_not_pop() -> void:
	var slot := _make_slot()
	var src := FixedSource.new()
	src.p = 1.0
	src.rem = 0.0
	var fired: Array[int] = []
	slot.became_ready.connect(func(i: int) -> void: fired.append(i))
	slot.bind(src, 0)
	await wait_frames(2)
	assert_eq(fired.size(), 0, "bound while ready: no pop")
	assert_true(_glowing(slot), "but a ready ultimate glows")
	assert_near(_param(slot, &"ready_flash"), 0.0, 0.0001)
	slot.queue_free()
	await wait_frames(1)


func test_no_shader_write_while_progress_is_unchanged() -> void:
	var slot := _make_slot()
	slot.set_cooldown(0.5, 4.0)
	assert_near(_param(slot, &"progress"), 0.5, 0.0001)
	# A sentinel only a write could overwrite.
	_mat(slot).set_shader_parameter(&"progress", 0.123)
	_number(slot).text = "x"
	slot.set_cooldown(0.5, 3.9)
	assert_near(_param(slot, &"progress"), 0.123, 0.0001, "same progress: no shader write")
	assert_eq(_number(slot).text, "x", "same number shown: no label write")
	slot.set_cooldown(0.501, 3.8)
	assert_near(_param(slot, &"progress"), 0.123, 0.0001, "moved less than PROGRESS_STEP: no write")
	slot.set_cooldown(0.51, 2.9)
	assert_near(_param(slot, &"progress"), 0.51, 0.0001, "moved 0.01: written")
	assert_eq(_number(slot).text, "3")
	slot.set_cooldown(0.9985, 0.02)
	slot.set_cooldown(1.0, 0.0)
	assert_near(_param(slot, &"progress"), 1.0, 0.0001, "reaching ready is always written")
	slot.queue_free()
	await wait_frames(1)


func test_countdown_format() -> void:
	# [remaining, label]: whole seconds rounded up above 1 s, tenths below.
	for c: Array in [[12.0, "12"], [2.3, "3"], [1.01, "2"], [1.0, "1.0"], [0.95, "1.0"], [0.31, "0.4"],
			[0.3, "0.3"], [0.04, "0.1"], [0.0, ""], [-0.5, ""]]:
		var r: float = c[0]
		assert_eq(AbilitySlot.countdown_text(AbilitySlot.countdown_tenths(r)), c[1], "%s s" % str(r))
	var slot := _make_slot()
	slot.set_cooldown(0.9, 0.62)
	assert_eq(_number(slot).text, "0.7")
	assert_true(_number(slot).visible)
	slot.show_countdown = false
	slot.set_cooldown(0.5, 4.0)
	assert_false(_number(slot).visible, "show_countdown off: no digits")
	slot.queue_free()
	await wait_frames(1)


func test_lock_state() -> void:
	var slot := _make_slot()
	var src := FixedSource.new()
	src.lock = true
	src.p = 1.0
	src.rem = 0.0
	var fired: Array[int] = []
	slot.became_ready.connect(func(i: int) -> void: fired.append(i))
	slot.bind(src, 0)
	await wait_frames(1)
	assert_true(slot.is_locked())
	assert_true((slot.get_node(^"%Lock") as CanvasItem).visible, "padlock shown")
	assert_eq((slot.get_node(^"%LockText") as Label).text, "II", "with the stage numeral")
	assert_true((slot.get_node(^"%Frame") as TextureRect).texture == slot.frame_locked, "slot_locked frame")
	assert_near(_param(slot, &"locked"), 1.0, 0.0001, "icon greyed")
	assert_false(_number(slot).visible)
	assert_false(_glowing(slot), "a locked ultimate never glows")
	slot.set_cooldown(0.2, 9.0)
	assert_near(_param(slot, &"progress"), 1.0, 0.0001, "no sweep under the padlock")
	src.lock = false
	await wait_frames(2)
	assert_false(slot.is_locked())
	assert_false((slot.get_node(^"%Lock") as CanvasItem).visible)
	assert_true((slot.get_node(^"%Frame") as TextureRect).texture == slot.frame_ult, "back to slot_ult")
	assert_near(_param(slot, &"locked"), 0.0, 0.0001)
	assert_eq(fired.size(), 1, "unlocking into a ready ability pops")
	assert_true(_glowing(slot))
	slot.queue_free()
	await wait_frames(1)


func test_frames_and_materials() -> void:
	var a := _make_slot()
	var b := _make_slot()
	assert_true(_mat(a) != _mat(b), "every slot owns its material")
	assert_true(_mat(a).shader.resource_path.ends_with("ability_cooldown.gdshader"))
	var frame := a.get_node(^"%Frame") as TextureRect
	for c: Array in [[AbilityBase.AbilityType.BASIC_ATTACK, "slot_basic"], [AbilityBase.AbilityType.ACTIVE, "slot_active"],
			[AbilityBase.AbilityType.ULTIMATE, "slot_ult"], [AbilityBase.AbilityType.PASSIVE, "slot_passive"]]:
		a.slot_type = c[0]
		assert_eq(frame.texture.resource_path, KIT % c[1])
	assert_eq(a.frame_locked.resource_path, KIT % "slot_locked")
	a.slot_type = AbilityBase.AbilityType.PASSIVE
	a.set_cooldown(1.0, 0.0)
	assert_false(_glowing(a), "only ultimates glow")
	var glow := (a.get_node(^"%Glow") as CanvasItem).material as ShaderMaterial
	assert_eq(glow.shader.resource_path, READY_GLOW)
	var amber_light := UiPalette.get_default().amber_light
	var re := RegEx.create_from_string("glow_color : source_color = vec4\\(([0-9.]+), ([0-9.]+), ([0-9.]+)")
	var m := re.search(glow.shader.code)
	assert_true(m != null, "ready_glow declares glow_color")
	if m != null:
		assert_near(float(m.get_string(1)), amber_light.r, 0.002, "glow_color is amber_light r")
		assert_near(float(m.get_string(2)), amber_light.g, 0.002, "g")
		assert_near(float(m.get_string(3)), amber_light.b, 0.002, "b")
	a.queue_free()
	b.queue_free()
	await wait_frames(1)


func test_river_slot_follows_her_weapon_mode() -> void:
	var river := await spawn_frozen(RIVER, Vector2(0, 0))
	var system := river.get_node("AbilitySystem") as AbilitySystem
	var basic := system.basic_attack as RiverBasicAttack
	var slot := _make_slot()
	slot.bind(CooldownSource.Hero.new(system), 0)
	await wait_frames(1)
	var icon := slot.get_node(^"%Icon") as TextureRect
	assert_eq(slot.slot_type, AbilityBase.AbilityType.BASIC_ATTACK)
	assert_true(icon.texture == basic.icon, "rifle: the sniper icon")
	river._use_active_now()
	await wait_frames(2)
	assert_true(icon.texture == basic.heal_icon, "staff: the slot swapped to the heal icon")
	slot.queue_free()
	river.queue_free()
	await wait_frames(1)


func test_monster_slot_unlocks_on_evolution_and_stops_with_the_monster() -> void:
	var g := (await spawn_frozen(GROUNT, Vector2(4000, 0))) as MonsterBase
	var slot := _make_slot()
	var fired: Array[int] = []
	slot.became_ready.connect(func(i: int) -> void: fired.append(i))
	slot.bind(CooldownSource.Monster.new(g), 2)
	await wait_frames(1)
	assert_true(slot.is_locked(), "Ground Slam locked at Stage I")
	assert_eq((slot.get_node(^"%LockText") as Label).text, "II")
	g.gain_xp(1000.0)
	await wait_frames(2)
	assert_false(slot.is_locked(), "unlocked at Stage II")
	assert_eq(fired.size(), 1, "and it pops")
	assert_eq(fired.front(), 2, "reporting slot 2")
	assert_true(_glowing(slot), "the ultimate is ready")
	g.queue_free()
	await wait_frames(2)
	assert_false(slot.is_processing(), "the slot stops polling a freed monster")
	assert_true(slot.is_dead(), "and goes dead")
	assert_false(_glowing(slot), "a dead ultimate does not glow")
	slot.queue_free()
	await wait_frames(1)


## hud-6: under Brood Mother, Nyxa's Stage III Night Swarm never ends and
## refuses a recast while it runs (NightSwarm.can_use). Once its cooldown is
## over its slot shows the plain icon (CooldownSource.castable false): no
## ready glow, no pop, no number; F3 reads "running". Without the capstone the
## same slot pops and glows (the swarm may be cast again).
func test_a_never_ending_swarm_is_no_ready_ultimate() -> void:
	if not require_isolated():
		return
	play_side(MatchRewards.Side.MONSTER)
	for owned: bool in [true, false]:
		PersistedData.wipe_progress(false)
		if owned:
			PersistedData.set_skill_rank(&"monster_nyxa", &"ny_brood", 1)
			PersistedData.set_equipped_capstone(&"monster_nyxa", &"ny_brood")
		var n := (await spawn_frozen(NYXA, Vector2(4000, 0))) as MonsterBase
		evolve_to(n, 3)
		var swarm := n.ability_3 as NightSwarm
		assert_eq(swarm.is_permanent(), owned, "Brood Mother: %s" % str(owned))
		var src := CooldownSource.Monster.new(n)
		var slot := _make_slot()
		var fired: Array[int] = []
		slot.became_ready.connect(func(i: int) -> void: fired.append(i))
		slot.bind(src, 2)
		await wait_frames(1)
		assert_true(n._cast("ability_3", swarm, null), "the swarm is cast")
		await wait_frames(2)
		assert_false(_glowing(slot), "cooling down: no glow")
		n.ability_cooldowns["ability_3"] = 0.0  # its cooldown is over
		await wait_frames(2)
		assert_true(swarm.is_active(), "the swarm still runs")
		assert_eq(swarm.can_use(n), not owned, "a recast: %s" % str(not owned))
		assert_eq(src.castable(2), not owned)
		assert_false(_number(slot).visible, "no countdown")
		if owned:
			assert_false(_glowing(slot), "a running never-ending swarm does not glow")
			assert_true(fired.is_empty(), "and does not pop")
			assert_eq(src.debug_state(2), "running")
		else:
			assert_true(_glowing(slot), "a ready ultimate glows")
			assert_eq(fired, [2] as Array[int], "and pops")
			assert_eq(src.debug_state(2), "ready")
		slot.queue_free()
		n.queue_free()
		await wait_frames(1)
	PersistedData.wipe_progress(false)


## set_dead(): no number, no sweep, no glow, the icon greyed under its own
## frame; nothing feeds the slot afterwards and nothing pops.
func test_dead_state() -> void:
	var slot := _make_slot()
	var src := FixedSource.new()
	src.p = 0.4
	src.rem = 6.0
	var fired: Array[int] = []
	slot.became_ready.connect(func(i: int) -> void: fired.append(i))
	slot.bind(src, 0)
	await wait_frames(1)
	assert_true(_number(slot).visible and _number(slot).text == "6", "cooling: the countdown shows")
	assert_near(_param(slot, &"progress"), 0.4, 0.0001)
	assert_false(slot.is_dead())

	slot.set_dead()
	assert_true(slot.is_dead())
	assert_false(_number(slot).visible, "no number")
	assert_eq(_number(slot).text, "")
	assert_near(_param(slot, &"progress"), 1.0, 0.0001, "no sweep")
	assert_near(_param(slot, &"locked"), 1.0, 0.0001, "the icon greyed")
	assert_false(slot.is_locked(), "dead is not locked")
	assert_false((slot.get_node(^"%Lock") as CanvasItem).visible, "no padlock")
	assert_true((slot.get_node(^"%Frame") as TextureRect).texture == slot.frame_ult, "its own frame")
	assert_false(_glowing(slot))
	assert_false(slot.is_processing(), "it stops polling")

	# Nothing brings it back: the source, a card's calls, a new bind.
	src.p = 1.0
	src.rem = 0.0
	await wait_frames(2)
	slot.set_cooldown(0.2, 9.0)
	slot.set_locked(true, "II")
	slot.bind(src, 0)
	await wait_frames(2)
	assert_false(_number(slot).visible, "still no number")
	assert_near(_param(slot, &"progress"), 1.0, 0.0001, "still no sweep")
	assert_false(slot.is_locked() or _glowing(slot) or slot.is_processing(), "no lock, no glow, no polling")
	assert_eq(fired.size(), 0, "a dead slot never reports ready")
	slot.queue_free()

	# A ready, glowing ultimate caught mid-pop.
	var ready_slot := _make_slot()
	var ready_src := FixedSource.new()
	ready_src.p = 0.5
	ready_slot.bind(ready_src, 0)
	await wait_frames(1)
	ready_src.p = 1.0
	ready_src.rem = 0.0
	await wait_frames(1)
	assert_true(_glowing(ready_slot), "ready: the ultimate glows")
	var body := ready_slot.get_node(^"%Body") as Control
	ready_slot.set_dead()
	assert_false(_glowing(ready_slot), "the glow goes out")
	assert_eq(body.scale, Vector2.ONE, "the pop is cut")
	assert_near(_param(ready_slot, &"ready_flash"), 0.0, 0.0001, "and its flash")
	await wait_frames(3)
	assert_eq(body.scale, Vector2.ONE, "no tween keeps running")
	ready_slot.queue_free()

	# Dead before it entered the tree (a card built for a hero already gone).
	var early := (load(SLOT) as PackedScene).instantiate() as AbilitySlot
	early.set_dead()
	early.bind(src, 0)
	add_child(early)
	await wait_frames(1)
	assert_true(early.is_dead() and not early.is_processing() and not _number(early).visible, "dead from its first frame")
	assert_near(_param(early, &"locked"), 1.0, 0.0001)
	early.queue_free()
	await wait_frames(1)


## A hero's slot mid-countdown when the hero is freed: it used to stop polling
## and keep the last number and sweep ("6" under the skull).
func test_slot_clears_its_countdown_when_the_hero_is_gone() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2.ZERO)
	var system := vlad.get_node("AbilitySystem") as AbilitySystem
	var ult := AbilityBase.AbilityType.ULTIMATE
	var slot := _make_slot()
	slot.bind(CooldownSource.Hero.new(system), 2)
	system.cooldowns[ult] = 6.0
	system._cooldown_totals[ult] = 20.0
	await wait_frames(1)
	assert_true(_number(slot).visible and _number(slot).text == "6", "the ultimate counts down")
	assert_true(_param(slot, &"progress") < 0.75, "with its sweep")
	vlad.queue_free()
	await wait_frames(2)
	assert_true(slot.is_dead(), "the hero is gone: the slot is dead")
	assert_false(_number(slot).visible, "no frozen countdown")
	assert_near(_param(slot, &"progress"), 1.0, 0.0001, "no frozen sweep")
	assert_near(_param(slot, &"locked"), 1.0, 0.0001, "greyed")
	slot.queue_free()
	await wait_frames(1)

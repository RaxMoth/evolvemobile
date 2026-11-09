extends TestCase

## VfxManager (Scripts/Vfx): fixed pools that never grow past their caps (a
## full pool recycles its oldest entry), damage numbers that add up hits
## within MERGE_WINDOW and show at most NUMBERS_PER_TARGET per target, hits
## outside the camera view skipped, ground telegraphs from pooled RingPulse
## rings, trauma on the camera for kills and big hits (capped, behind the
## Settings toggle), the F3 line, World.tscn's wiring and the hit flash
## material on every rig body. None of it draws from the global RNG, which
## drives gameplay (tools/sim_trace.sh).

const WORLD := "res://Scenes/World/World.tscn"
const FLASH_MATERIAL := "res://Assets/Shaders/hit_flash_material.tres"
const CHARACTERS := "res://Assets/Characters"
const FIXTURE_BODY := "res://test/fixtures/rig_fixture/rig_fixture_body.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"


func test_sprite_pool_never_grows_past_its_cap() -> void:
	var cap := VfxManager.SPRITE_CAP
	var buf := FxSpriteBuffer.new(cap)
	for i in 500:
		buf.spawn(FxTex.STAR, Vector2(float(i), 0.0), 10.0, 5.0, 1.0, Color.WHITE)
		assert_true(buf.live <= cap, "spawn %d: %d live" % [i, buf.live])
	assert_eq(buf.live, cap, "full")
	assert_eq([buf.tex.size(), buf.pos.size(), buf.col.size(), buf.life.size()], [cap, cap, cap, cap], "the arrays never grow")
	var xs: Array[float] = []
	for i in cap:
		xs.append(buf.pos[i].x)
	xs.sort()
	assert_eq([xs[0], xs[cap - 1]], [float(500 - cap), 499.0], "a full ring recycled its oldest sprites")
	buf.step(2.0)
	assert_eq(buf.live, 0, "all expired")
	# Through the manager: 50 hits and kills a frame for 25 frames.
	var vfx := _vfx()
	var targets := _targets(vfx, 50)
	var peak := 0
	for _f in 25:
		for t in targets:
			vfx.show_hit(t, 12.0, true)
		peak = maxi(peak, vfx.sprites.live)
		await wait_frames(1)
	assert_true(peak <= cap, "peak %d sprites" % peak)
	assert_eq(peak, cap, "the stress filled the pool")
	assert_eq([vfx.sprites.capacity, vfx.sprites.pos.size()], [cap, cap], "never grew")
	assert_true(vfx.hits_over_budget > 0, "hits past MAX_HITS_PER_FRAME spawn no sprites")
	_free(vfx, targets)
	await wait_frames(1)


func test_numbers_merge_and_stay_capped() -> void:
	var vfx := _vfx()
	var targets := _targets(vfx, 100)
	for i in 500:
		vfx.show_hit(targets[i % 100], 5.0)
		assert_true(vfx.numbers_live() <= VfxManager.NUMBER_CAP, "hit %d: %d numbers" % [i, vfx.numbers_live()])
	assert_eq(vfx.numbers_live(), VfxManager.NUMBER_CAP, "full")
	_free(vfx, targets)
	await wait_frames(1)
	vfx = _vfx()
	targets = _targets(vfx, 1)
	var t := targets[0]
	for _i in 5:
		vfx.show_hit(t, 7.0)
	assert_eq(vfx.numbers_on(t), PackedFloat32Array([35.0]), "hits in one frame add up in one number")
	# 10 frames (0.17 s) apart: past the merge window, each starts a number,
	# up to NUMBERS_PER_TARGET; the next one adds up in the youngest.
	for _i in 3:
		await wait_frames(10)
		vfx.show_hit(t, 1.0)
	var values := vfx.numbers_on(t)
	assert_eq(values.size(), VfxManager.NUMBERS_PER_TARGET, "at most %d numbers on a target" % VfxManager.NUMBERS_PER_TARGET)
	var total := 0.0
	for v in values:
		total += v
	assert_near(total, 38.0, 0.001, "nothing lost: %s" % values)
	await wait_frames(int(ceilf(VfxManager.NUMBER_LIFE * 60.0)) + 2)
	assert_eq(vfx.numbers_live(), 0, "numbers expire")
	_free(vfx, targets)
	await wait_frames(1)


func test_hits_outside_the_view_are_skipped() -> void:
	var vfx := _vfx()
	var far := Node2D.new()
	far.position = _view_center(vfx) + Vector2(100000.0, 0.0)
	add_child(far)
	vfx.show_hit(far, 10.0, true)
	assert_eq([vfx.hits_culled, vfx.hits_shown, vfx.numbers_live(), vfx.sprites.live], [1, 0, 0, 0], "culled")
	_free(vfx, [far])
	await wait_frames(1)


## EventBus.damage_applied reaches the manager (a frozen Bat takes a hit) and
## the number starts above the HP bar; a killing blow adds the puff burst.
func test_damage_applied_shows_a_number_over_the_hp_bar() -> void:
	var vfx := _vfx()
	var bat := await spawn_frozen(BAT, _view_center(vfx)) as EntityBase
	EventBus.deal_damage(null, bat, 3.0)
	assert_eq(vfx.numbers_on(bat), PackedFloat32Array([3.0]), "the bus's hit shows")
	assert_eq(vfx.sprites.live, 1 + VfxManager.SPARKS_PER_HIT, "a star and its sparks")
	var slot := Array(vfx._n_target).find(bat.get_instance_id())
	assert_true(vfx._n_pos[slot].y < bat.hud.global_position.y, "starts above the HP bar")
	EventBus.deal_damage(null, bat, 10000.0)
	assert_false(bat.is_alive(), "killed")
	assert_eq(vfx.sprites.live, 2 * (1 + VfxManager.SPARKS_PER_HIT) + VfxManager.PUFFS_PER_KILL + 1, "plus the kill's puffs and star")
	if is_instance_valid(bat):
		bat.queue_free()
	vfx.queue_free()
	await wait_frames(1)


func test_telegraphs_reuse_pooled_rings() -> void:
	var vfx := _vfx()
	var center := _view_center(vfx)
	var color := UiPalette.get_default().danger
	for i in 10:
		vfx.telegraph(center + Vector2(float(i), 0.0), 40.0, 0.5, color)
	assert_eq(vfx.telegraphs_live(), VfxManager.TELEGRAPH_CAP, "a full pool recycles")
	var rings: Array[RingPulse] = []
	for c in vfx.get_children():
		if c is RingPulse:
			rings.append(c as RingPulse)
	assert_eq(rings.size(), 2 * VfxManager.TELEGRAPH_CAP, "an outline and a fill ring per telegraph, made once")
	for ring in rings:
		assert_true(ring.visible, "showing")
		assert_near(ring.default_color.a, VfxManager.TELEGRAPH_ALPHA, 0.001, "telegraphs at 35% alpha")
		assert_eq([ring.z_as_relative, ring.z_index], [false, 0], "on the ground, under the characters")
		assert_near(ring.width * ring.scale.x, vfx.telegraph_width, 0.001, "the line keeps its width at any radius")
		assert_true(vfx.telegraph_width <= 3.0, "ground rings at most 3 px wide")
	await wait_frames(15)
	var grown := false
	for ring in rings:
		grown = grown or (ring.scale.x > 1.0 and ring.scale.x < 40.0)
	assert_true(grown, "the fill grows toward the outline")
	await wait_frames(30)
	assert_eq(vfx.telegraphs_live(), 0, "done after the windup")
	for ring in rings:
		assert_false(ring.visible, "hidden, not freed")
		assert_true(is_instance_valid(ring), "kept for the next telegraph")
	vfx.queue_free()
	await wait_frames(1)


func test_camera_trauma_is_capped_and_follows_the_setting() -> void:
	var before: bool = GameCamera.shake_setting_on()
	GameCamera.set_shake_setting(true)
	var cam := GameCamera.new()
	cam.add_trauma(0.5)
	cam.add_trauma(0.5)
	assert_near(cam.trauma, cam.shake_trauma_cap, 0.0001, "capped")
	cam._update_shake(0.1)
	var left := cam.shake_trauma_cap - cam.shake_decay * 0.1
	assert_near(cam.trauma, left, 0.0001, "decays")
	var reach := cam.shake_max_offset * left * left
	assert_true(absf(cam.offset.x) <= reach and absf(cam.offset.y) <= reach, "offset within max x trauma²: %s" % cam.offset)
	cam._update_shake(10.0)
	assert_eq([cam.trauma, cam.offset], [0.0, Vector2.ZERO], "settles")
	GameCamera.set_shake_setting(false)
	cam.add_trauma(0.5)
	assert_eq(cam.trauma, 0.0, "the Settings toggle turns it off")
	GameCamera.set_shake_setting(true)
	cam.shake_enabled = false
	cam.add_trauma(0.5)
	assert_eq(cam.trauma, 0.0, "and so does the export")
	cam.free()
	GameCamera.set_shake_setting(before)


## A hero hit hard on screen adds a little trauma, a hero going down more.
func test_kills_and_big_hits_add_trauma() -> void:
	var before: bool = GameCamera.shake_setting_on()
	GameCamera.set_shake_setting(true)
	var vfx := _vfx()
	var cam := GameCamera.new()
	vfx.camera = cam
	var hero := await spawn_frozen(VLAD, _view_center(vfx)) as EntityBase
	vfx.show_hit(hero, vfx.big_hit - 1.0)
	assert_eq(cam.trauma, 0.0, "a small hit does not shake")
	vfx.show_hit(hero, vfx.big_hit)
	assert_near(cam.trauma, vfx.trauma_big_hit, 0.0001, "a big hit on a hero")
	vfx.show_hit(hero, 1.0, true)
	assert_near(cam.trauma, vfx.trauma_big_hit + vfx.trauma_hero_down, 0.0001, "a hero going down")
	hero.queue_free()
	vfx.queue_free()
	cam.free()
	GameCamera.set_shake_setting(before)
	await wait_frames(1)


func test_global_rng_untouched_by_500_spawns() -> void:
	seed(4242)
	var expected: Array[int] = []
	for _i in 8:
		expected.append(randi())
	seed(4242)
	var vfx := _vfx()
	var cam := GameCamera.new()
	cam.add_trauma(0.8)
	var targets := _targets(vfx, 20)
	var color := UiPalette.get_default().monster
	for i in 500:
		vfx.show_hit(targets[i % 20], 3.0 + float(i % 40), i % 7 == 0)
		if i % 50 == 0:
			vfx.telegraph(targets[i % 20].position, 30.0, 0.3, color)
			cam._update_shake(1.0 / 60.0)
			await wait_frames(1)
	await wait_frames(5)
	var after: Array[int] = []
	for _i in 8:
		after.append(randi())
	assert_eq(after, expected, "the vfx drew no global random number")
	cam.free()
	_free(vfx, targets)
	await wait_frames(1)


func test_f3_overlay_shows_the_pools() -> void:
	var vfx := _vfx()
	vfx.add_to_group(&"vfx")
	var overlay := DebugOverlay.new()
	add_child(overlay)
	await wait_frames(1)
	overlay.set_active(true)
	overlay._collect_snapshots()
	assert_true(overlay._hud_label.text.contains("VFX sprites 0/%d  numbers 0/%d  telegraphs 0/%d" % [
			VfxManager.SPRITE_CAP, VfxManager.NUMBER_CAP, VfxManager.TELEGRAPH_CAP]), overlay._hud_label.text)
	overlay.queue_free()
	vfx.queue_free()
	await wait_frames(1)


## The manager lives with the match: a World.tscn node in group "vfx" with the
## camera wired, right after the ground layers and before every entity holder
## (its telegraph rings draw on the ground under the characters).
func test_world_wires_the_vfx_manager() -> void:
	var world := (load(WORLD) as PackedScene).instantiate()
	var vfx := world.get_node_or_null(^"Vfx") as VfxManager
	assert_true(vfx != null, "World/Vfx is a VfxManager")
	if vfx != null:
		assert_true(vfx.is_in_group(&"vfx"), "group vfx")
		assert_eq(vfx.camera, world.get_node(^"MainCam"), "camera wired")
		assert_true(vfx.z_index > 10 and vfx.z_index < 100, "above the entities and their trails, under the fog")
		var at := vfx.get_index()
		assert_true(at > world.get_node(^"Deko").get_index(), "after the ground layers")
		for holder: String in ["Spawns", "Heros", "MonsterSlot"]:
			assert_true(at < world.get_node(holder).get_index(), "before %s" % holder)
	world.free()


## Every rig body draws through the one shared hit flash material (its root's,
## every node under it using its parent's): the rig's over-bright hurt
## modulate becomes a white flash, and a character still batches into one draw.
func test_rig_bodies_draw_through_the_hit_flash_material() -> void:
	var flash := load(FLASH_MATERIAL) as ShaderMaterial
	assert_true(flash != null and flash.shader != null, "the material loads")
	var paths: Array[String] = [FIXTURE_BODY]
	for id in DirAccess.get_directories_at(CHARACTERS):
		var path := "%s/%s/%s_body.tscn" % [CHARACTERS, id, id]
		if ResourceLoader.exists(path):
			paths.append(path)
	assert_true(paths.size() >= 9, "every character body (%d)" % paths.size())
	for path in paths:
		var body := (load(path) as PackedScene).instantiate() as RigBody
		assert_eq(body.material, flash, "%s: the shared hit flash material" % path.get_file())
		var parts := 0
		for node in body.find_children("*", "CanvasItem", true, false):
			parts += 1
			assert_true((node as CanvasItem).use_parent_material, "%s/%s uses its parent's material" % [path.get_file(), node.name])
		assert_true(parts > 0, "%s has parts" % path.get_file())
		body.free()


# ---------- helpers ----------

func _vfx() -> VfxManager:
	var vfx := VfxManager.new()
	add_child(vfx)
	return vfx


## The middle of the camera view the manager culls against.
func _view_center(vfx: VfxManager) -> Vector2:
	var vp := vfx.get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect().get_center()


func _targets(vfx: VfxManager, n: int) -> Array[Node2D]:
	var center := _view_center(vfx)
	var out: Array[Node2D] = []
	for i in n:
		var t := Node2D.new()
		t.position = center + Vector2(float(i % 10) * 8.0, floorf(float(i) / 10.0) * 8.0)
		add_child(t)
		out.append(t)
	return out


func _free(vfx: VfxManager, nodes: Array) -> void:
	for n: Node in nodes:
		n.queue_free()
	vfx.queue_free()

extends TestCase

## Fight readability (the walkthrough's findings on the big fight):
##  - the hurt flash is rate-limited per rig and softer on the monster, so a
##    body five attackers hit keeps its art readable;
##  - a cast at a target turns the body to the target's side at once;
##  - a cleave's crescent starts outside the caster's drawn body, however big
##    the monster has grown;
##  - stacked characters' in-world huds (HP bar and level pill) rise above
##    each other, and damage numbers never start on top of a live one;
##  - World.tscn y-sorts its characters (a hero in front of the monster's
##    feet draws in front of it);
##  - a hero's or the monster's rig stays behind as the corpse for the death
##    beat, while the entity is freed as before; a mob's stays with the mob.
## GameManager holding the result screen back for the beat is in
## test_match_result; the Trap Cage's freed entry in test_hero_actives.

const WORLD := "res://Scenes/World/World.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const IRELIA := "res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn"
const TED := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"
const CLEAVE := "res://Scenes/NPCs/Monster/Grount/abilities/grount_front_cleave.tres"
## Frames between two hits of a five-attacker fight (0.15 s at 60 fps).
const HIT_EVERY := 9


func after_each() -> void:
	CharacterRig.force_awake = false


func _rig(e: Node) -> CharacterRig:
	return e.get_node(^"Rig") as CharacterRig


## Frames of `frames` in which `rig`'s body is flashing while `e` is hit every
## HIT_EVERY frames, and the strongest flash seen (the modulate above 1).
func _flash_under_fire(e: EntityBase, rig: CharacterRig, frames: int) -> Array[float]:
	var flashing := 0
	var peak := 0.0
	for f in frames:
		if f % HIT_EVERY == 0:
			e.damaged.emit(DamagePacket.make(null, e, 1.0, null, 0))
		await wait_frames(1)
		var over: float = rig.body.modulate.r - 1.0
		if over > 0.001:
			flashing += 1
		peak = maxf(peak, over)
	return [float(flashing), peak]


## Hits every 0.15 s used to restart the 0.18 s flash each time: the body
## stayed a white silhouette. Now it flashes at most once per
## hurt_flash_interval, and the monster's flash never reaches full white.
func test_hurt_flash_is_rate_limited_and_softer_on_the_monster() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(300, 300)) as EntityBase
	var grount := await spawn_frozen(GROUNT, Vector2(900, 300)) as EntityBase
	var frames := 180
	for e: EntityBase in [vlad, grount]:
		var rig := _rig(e)
		rig.set_on_screen(true)
		var seen: Array[float] = await _flash_under_fire(e, rig, frames)
		var share: float = seen[0] / float(frames)
		assert_true(share > 0.2, "%s still flashes under fire (%.2f of the frames)" % [e.name, share])
		assert_true(share <= rig.profile.hurt_time / rig.hurt_flash_interval + 0.02,
				"%s: at most one flash per interval (%.2f of the frames; every frame before)" % [e.name, share])
		if e == grount:
			assert_true(seen[1] < 0.6, "the monster's flash never reaches a white silhouette (peak %.2f)" % seen[1])
		else:
			assert_true(seen[1] > 0.8, "a hero's flash stays strong (peak %.2f)" % seen[1])
	assert_true(_rig(grount).hurt_flash_gain < _rig(vlad).hurt_flash_gain, "the monster's flash is softer")
	# A puppet's play_hurt (menus, previews) always plays.
	var rig := _rig(vlad)
	rig.play_hurt()
	rig.play_hurt()
	await wait_frames(1)
	assert_true(rig.body.modulate.r > 1.0, "play_hurt restarts the flash")
	vlad.queue_free()
	grount.queue_free()
	await wait_frames(1)


## Irelia bashed a target 50 px to her right while facing left: the facing
## carrier pointed straight up (no side of its own), so the rig kept the old
## side. A cast at a target now picks the side from target.x - caster.x.
func test_a_cast_faces_its_target() -> void:
	var irelia := await spawn_frozen(IRELIA, Vector2(300, 300)) as EntityBase
	var foe := Node2D.new()
	add_child(foe)
	var rig := _rig(irelia)
	rig.set_on_screen(true)
	var carrier := irelia.get_node(^"Sprite2D") as Node2D
	carrier.rotation = PI
	await wait_frames(2)
	assert_true(rig.body.scale.x < 0.0, "faces left with the carrier")
	carrier.rotation = -PI * 0.5
	await wait_frames(2)
	assert_true(rig.body.scale.x < 0.0, "a carrier pointing up keeps the side")
	var bash: AbilityBase = (irelia.get_node(^"AbilitySystem") as AbilitySystem).basic_attack
	foe.global_position = irelia.global_position + Vector2(50, -200)
	irelia.ability_cast.emit(bash, foe)
	await wait_frames(1)
	assert_true(rig.body.scale.x > 0.0, "the bash faces the target on her right")
	# The carrier still points the old way for a moment: the cast's side holds.
	carrier.rotation = PI
	await wait_frames(4)
	assert_true(rig.body.scale.x > 0.0, "held while the carrier turns (4 frames after the cast)")
	await wait_seconds(CharacterRig.FACE_HOLD + 0.1)
	assert_true(rig.body.scale.x < 0.0, "then the carrier decides again")
	# No target, the caster itself or one straight above changes nothing.
	irelia.ability_cast.emit(bash, null)
	irelia.ability_cast.emit(bash, irelia)
	foe.global_position = irelia.global_position + Vector2(1, -80)
	irelia.ability_cast.emit(bash, foe)
	await wait_frames(1)
	assert_true(rig.body.scale.x < 0.0, "nothing to face: the side stays")
	irelia.queue_free()
	foe.queue_free()
	await wait_frames(1)


## The slash crescent of the cast `caster` just played: its centre in world px.
func _crescent(vfx: AbilityVfx) -> Vector2:
	for i in vfx.over.capacity:
		if vfx.over.tex[i] == FxTex.SLASH:
			return vfx.over.pos[i]
	return Vector2.INF


## Front Cleave's crescent sat at half the reach (40 px) whatever the size: on
## a Stage III Grount (50 px to either side) that was his own face. It now
## starts outside the drawn body.
func test_cleave_crescent_clears_the_grown_body() -> void:
	var mgr := VfxManager.new()
	add_child(mgr)
	var vfx := AbilityVfx.new()
	vfx.telegraphs = mgr
	mgr.add_child(vfx)
	var vp := mgr.get_viewport()
	var center: Vector2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect().get_center()
	var grount := await spawn_frozen(GROUNT, center) as MonsterBase
	var cleave := load(CLEAVE) as BullFrontCleave
	var foe := Node2D.new()
	foe.position = center + Vector2(60, 0)
	add_child(foe)
	grount.sprite.rotation = 0.0
	var reach: float = cleave.cone_range
	var out_by_scale: Array[float] = []
	for s: float in [1.0, 1.5]:
		grount.scale = Vector2(s, s)
		vfx.over.clear()
		vfx._on_ability_cast(grount, cleave, foe)
		var at := _crescent(vfx)
		assert_true(at.is_finite(), "scale %.1f: the cleave draws its crescent" % s)
		var swing: Vector2 = grount.global_position.lerp(CharacterRig.mid_body_of(grount), 0.6)
		var out: float = at.x - swing.x
		out_by_scale.append(out)
		assert_near(at.y, swing.y, 0.01, "scale %.1f: at swing height" % s)
		assert_true(out > CharacterRig.half_width_of(grount), "scale %.1f: %.1f px out, past the body's %.1f" % [
				s, out, CharacterRig.half_width_of(grount)])
		assert_true(out <= reach, "scale %.1f: inside the reach (%.1f of %.1f)" % [s, out, reach])
	assert_near(out_by_scale[0], reach * 0.5, 4.0, "Stage I keeps its spot at about half the reach")
	assert_true(out_by_scale[1] > out_by_scale[0] + 10.0, "a grown body pushes it out (%s)" % str(out_by_scale))
	# Aimed up (the target stands behind the tall body): past the head top,
	# not on the face. Aimed down: the half-width, in front of the feet.
	grount.sprite.rotation = -PI * 0.5
	vfx.over.clear()
	vfx._on_ability_cast(grount, cleave, foe)
	var above := _crescent(vfx)
	assert_true(above.y < CharacterRig.head_top_of(grount).y, "aimed up: above the head (%.1f, head top %.1f)" % [
			above.y, CharacterRig.head_top_of(grount).y])
	grount.sprite.rotation = PI * 0.5
	vfx.over.clear()
	vfx._on_ability_cast(grount, cleave, foe)
	var below := _crescent(vfx)
	assert_near(below.y - grount.global_position.lerp(CharacterRig.mid_body_of(grount), 0.6).y, out_by_scale[1], 0.01,
			"aimed down: as far out as to the side")
	assert_true(below.y > grount.global_position.y, "in front of the feet")
	assert_near(CharacterRig.half_width_of(foe), 0.0, 0.001, "a node without a rig has no width")
	grount.queue_free()
	foe.queue_free()
	mgr.queue_free()
	await wait_frames(1)


func _hud(e: Node) -> EntityHud:
	return e.get_node(^"%Hud") as EntityHud


## Heroes on one spot drew their bars and pills on top of each other. A
## stacking hud rises above the huds on screen before it and comes back down
## when it is clear; a mob's never stacks; every hud draws above the bodies.
func test_stacked_huds_rise_above_each_other() -> void:
	var at := Vector2(400, 400)
	var heroes: Array[EntityBase] = []
	for path: String in [VLAD, IRELIA, TED]:
		heroes.append(await spawn_frozen(path, at) as EntityBase)
	# Far from Ted's fox, which would bite it.
	var bat := await spawn_frozen(BAT, at + Vector2(3000, 0)) as EntityBase
	var bat_hud := _hud(bat)
	bat_hud._on_screen_entered()
	assert_false(bat_hud.stacks or bat_hud.is_processing(), "a mob's hud never stacks")
	bat.queue_free()
	var huds: Array[EntityHud] = []
	for h in heroes:
		var hud := _hud(h)
		assert_true(hud != null and hud.stacks, "%s: a stacking hud" % h.name)
		assert_eq(hud.z_index, 1, "%s: above the bodies" % h.name)
		hud._on_screen_entered()
		huds.append(hud)
	var rest: Array[float] = []
	for hud in huds:
		rest.append(hud.position.y)
	assert_true(huds[0].world_rect().intersects(huds[1].world_rect()), "at rest the huds overlap")
	await wait_seconds(0.8)
	for i in huds.size():
		for j in i:
			assert_false(huds[i].world_rect().intersects(huds[j].world_rect()),
					"%s clears %s" % [heroes[i].name, heroes[j].name])
	var pitch: float = huds[0].footprint.size.y + EntityHud.GAP
	assert_near(huds[0].lift(), 0.0, 0.01, "the first on screen stays")
	# One row above the first: the bottom of its pill on the first's top edge.
	assert_near(huds[1].world_rect().end.y, huds[0].world_rect().position.y - EntityHud.GAP, 0.5, "the second one row up")
	assert_near(huds[2].world_rect().end.y, huds[1].world_rect().position.y - EntityHud.GAP, 0.5, "the third two rows up")
	assert_near(huds[1].global_position.y, heroes[1].global_position.y + rest[1] - huds[1].lift(), 0.01, "raised in world px")
	# Apart again: back to rest.
	heroes[1].global_position = at + Vector2(300, 0)
	heroes[2].global_position = at + Vector2(-300, 0)
	await wait_seconds(0.8)
	assert_near(huds[1].lift(), 0.0, 0.01, "clear: back down")
	assert_near(huds[2].position.y, rest[2], 0.01, "at its scene position")
	# Off screen it sleeps at rest and leaves the order.
	heroes[1].global_position = at
	await wait_seconds(0.3)
	assert_true(huds[1].lift() > 1.0, "overlapping again")
	huds[1]._on_screen_exited()
	assert_false(huds[1].is_processing(), "asleep off screen")
	assert_near(huds[1].position.y, rest[1], 0.01, "at rest")
	# A grown monster: the lift is world px whatever its scale.
	var grount := await spawn_frozen(GROUNT, Vector2(2000, 400)) as MonsterBase
	var g_hud := _hud(grount)
	assert_true(g_hud.stacks, "the monster's hud stacks")
	grount._update_stage_scale(3)
	await wait_seconds(0.6)
	assert_near(grount.scale.y, 1.5, 0.001, "Stage III size")
	var g_rest: Vector2 = g_hud.global_position
	heroes[0].global_position = g_rest - Vector2(0, rest[0])
	g_hud._on_screen_entered()
	await wait_seconds(0.6)
	# The monster's bar ranks first: it stays and the hero's rises above it.
	assert_eq(g_hud.stack_priority, 1, "the monster's hud ranks before the heroes'")
	assert_near(g_hud.lift(), 0.0, 0.01, "the monster's bar never moves for a hero's")
	assert_near(huds[0].lift(), pitch, 0.5, "the hero's bar rises a row above it")
	# Two monsters' bars (equal rank): the later one rises, in world px on a
	# 1.5x body.
	var other := await spawn_frozen(GROUNT, grount.global_position + Vector2(0, 4)) as MonsterBase
	other._update_stage_scale(3)
	await wait_seconds(0.6)
	var o_hud := _hud(other)
	var o_rest: Vector2 = o_hud.global_position
	o_hud._on_screen_entered()
	await wait_seconds(0.6)
	assert_near(g_hud.lift(), 0.0, 0.01, "the first monster's bar stays")
	assert_true(o_hud.lift() > 1.0, "the second one rises")
	assert_near(o_hud.global_position.y, o_rest.y - o_hud.lift(), 0.01, "in world px on a 1.5x monster")
	assert_false(o_hud.world_rect().intersects(g_hud.world_rect()), "clear of the first")
	other.queue_free()
	for n: Node in [heroes[0], heroes[1], heroes[2], grount]:
		n.queue_free()
	await wait_frames(1)


## An area hit on characters standing on one spot: each number gets a spot of
## its own (the next column, then the row above).
func test_damage_numbers_never_start_on_a_live_one() -> void:
	var vfx := VfxManager.new()
	add_child(vfx)
	var vp := vfx.get_viewport()
	var center: Vector2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect().get_center()
	var targets: Array[Node2D] = []
	for _i in 8:
		var t := Node2D.new()
		t.position = center
		add_child(t)
		targets.append(t)
		vfx.show_hit(t, 12.0)
	var spots: Array[Vector2] = []
	for t in targets:
		var slot := Array(vfx._n_target).find(t.get_instance_id())
		assert_true(slot >= 0, "every target shows its number")
		spots.append(vfx._n_pos[slot])
	var column: float = maxf(vfx.number_spread, 1.5 * vfx.number_px / vfx._view_zoom)
	var row: float = (vfx.number_px + 4.0) / vfx._view_zoom
	for i in spots.size():
		for j in i:
			var d: Vector2 = (spots[i] - spots[j]).abs()
			assert_true(d.x >= column * 0.7 or d.y >= row * 0.9, "numbers %d and %d apart (%s)" % [j, i, str(d)])
	# One target alone keeps the old layout: centre, then right, then left.
	await wait_seconds(VfxManager.NUMBER_LIFE + 0.1)
	var solo := targets[0]
	var xs: Array[float] = []
	for _k in 3:
		vfx.show_hit(solo, 5.0)
		xs.append(vfx._n_pos[(vfx._n_next + VfxManager.NUMBER_CAP - 1) % VfxManager.NUMBER_CAP].x)
		await wait_frames(10)
	assert_near(xs[0], center.x, 2.01, "the first above the bar")
	assert_near(xs[1], center.x + column, 2.01, "the second right of it")
	assert_near(xs[2], center.x - column, 2.01, "the third left of it")
	for t in targets:
		t.queue_free()
	vfx.queue_free()
	await wait_frames(1)


## World.tscn y-sorts its characters: the root and the three holders are
## y-sorted Node2Ds at the origin, so a character draws in front of whatever
## stands behind (north of) its feet. The monster used to draw last, over
## every hero inside its sprite.
func test_world_y_sorts_its_characters() -> void:
	var world := (load(WORLD) as PackedScene).instantiate() as Node2D
	assert_true(world.y_sort_enabled, "the World root sorts its children by y")
	for holder: String in ["Spawns", "Heros", "MonsterSlot"]:
		var node := world.get_node(holder) as Node2D
		assert_true(node != null, "%s is a Node2D" % holder)
		if node != null:
			assert_true(node.y_sort_enabled, "%s sorts with the World" % holder)
			assert_eq(node.position, Vector2.ZERO, "%s at the origin: positions stay global" % holder)
	for ground: String in ["Ground", "Deko"]:
		var layer := world.get_node(ground) as Node2D
		assert_eq(layer.position.y, 0.0, "%s sorts under every character" % ground)
	world.free()


## The death beat's visual: a hero's (FULL) rig on screen leaves the dying
## hero, tips over, fades and frees itself, while the hero is freed as before.
func test_a_dead_heros_rig_stays_as_the_corpse() -> void:
	var vlad := await spawn_frozen(VLAD, Vector2(300, 300)) as EntityBase
	var rig := _rig(vlad)
	rig.set_on_screen(true)
	var feet: Vector2 = rig.global_position
	EventBus.deal_damage(null, vlad, 999999.0)
	assert_false(vlad.is_alive(), "killed")
	assert_true(rig.is_dying(), "the rig plays the death beat")
	assert_eq(rig.get_parent(), self, "under the hero's parent")
	assert_true(rig.global_position.is_equal_approx(feet), "where he stood")
	assert_true(vlad.visual_root() == null, "the hero has no body left to move or tint")
	await wait_frames(2)
	assert_false(is_instance_valid(vlad), "the hero is freed as before")
	assert_true(is_instance_valid(rig) and rig.is_processing(), "the corpse plays on")
	assert_near(rig.modulate.a, 1.0, 0.001, "opaque at first")
	await wait_seconds(CharacterRig.DEATH_TIME * 0.5)
	assert_true(absf(rig.body.rotation) > 0.4, "tipping over (%.2f rad)" % rig.body.rotation)
	await wait_seconds(CharacterRig.DEATH_TIME * 0.35)
	assert_true(rig.modulate.a < 0.6, "fading (alpha %.2f)" % rig.modulate.a)
	await wait_seconds(CharacterRig.DEATH_TIME * 0.2 + 0.1)
	assert_false(is_instance_valid(rig), "gone after DEATH_TIME")


## The monster and the fox fall too; a mob's rig (pooled with the mob) and a
## rig that is off screen stay where they are.
func test_death_beat_is_for_full_rigs_on_screen() -> void:
	var grount := await spawn_frozen(GROUNT, Vector2(900, 300)) as EntityBase
	var g_rig := _rig(grount)
	g_rig.set_on_screen(true)
	grount.scale = Vector2(1.5, 1.5)
	EventBus.deal_damage(null, grount, 999999.0)
	assert_true(g_rig.is_dying() and g_rig.get_parent() == self, "the monster's rig stays behind")
	assert_near(g_rig.global_scale.x, 1.5, 0.001, "at its stage size")
	# The fox frees itself without an owner: give it one.
	var keeper := Node2D.new()
	add_child(keeper)
	var pet := (load(PET) as PackedScene).instantiate() as Node2D
	pet.position = Vector2(300, 600)
	pet.call(&"set_owner_entity", keeper)
	add_child(pet)
	await wait_physics_frames(3)
	var p_rig := _rig(pet)
	p_rig.set_on_screen(true)
	EventBus.deal_damage(null, pet, 999999.0)
	assert_true(p_rig.is_dying() and p_rig.get_parent() == self, "the fox's rig stays behind")
	var bat := await spawn_frozen(BAT, Vector2(600, 300)) as EntityBase
	var b_rig := _rig(bat)
	b_rig.set_on_screen(true)
	EventBus.deal_damage(null, bat, 999999.0)
	assert_false(b_rig.is_dying(), "a mob's rig plays no death beat")
	assert_eq(b_rig.get_parent(), bat, "and stays with the mob")
	var vlad := await spawn_frozen(VLAD, Vector2(300, 300)) as EntityBase
	var v_rig := _rig(vlad)
	EventBus.deal_damage(null, vlad, 999999.0)
	assert_false(v_rig.is_dying(), "off screen: no corpse")
	await wait_frames(2)
	assert_false(is_instance_valid(v_rig), "freed with the hero")
	for node: Node in [g_rig, p_rig, keeper]:
		if is_instance_valid(node):
			node.queue_free()
	await wait_frames(2)

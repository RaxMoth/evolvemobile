extends TestCase

## The match world's own colours come from the palette (UiPalette), like the
## UI's: the in-world HP bars (HpBar2D tokens: heal for the hero side, danger
## for mobs and the monster, a panel_inset trough and an ink outline), the
## level badge next to a hero's or the monster's bar (the HUD's Pill and
## PillText, none on mobs), the world fog (FogOfWarSystem: bg_void) and the
## clear colour behind the tile map (the same token). The minimap's dots and
## fog map are test_minimap.gd's.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const PET := "res://Scenes/NPCs/Hero/Heros/Support/Ted/Abilities/Passive/TedsPet.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const NYXA := "res://Scenes/NPCs/Monster/Nyxa/Nyxa.tscn"
const GORRAK := "res://Scenes/NPCs/Monster/Gorrak/Gorrak.tscn"
const FOG := "res://Scenes/World/FogOfWar/FogOfWarSystem.tscn"


## Which fill token each scene's bar uses: hero HP heals green, enemy HP is
## danger red.
func test_hp_bars_take_their_colours_from_the_palette() -> void:
	var palette := UiPalette.get_default()
	var expected: Dictionary[String, StringName] = {
		VLAD: &"heal", HOG: &"danger", BAT: &"danger", GROUNT: &"danger", NYXA: &"danger", GORRAK: &"danger",
	}
	for path: String in expected:
		var e := await spawn_frozen(path, Vector2(4000, 4000))
		var bar := e.get_node(^"%HealthBar") as HpBar2D
		assert_eq(bar.fill_token, expected[path], "%s: fill token" % path.get_file())
		assert_eq(bar._fill_color, palette.color(expected[path]), "%s: the fill is the token's colour" % path.get_file())
		_check_trough_and_outline(bar, path.get_file())
		e.queue_free()
	var pet := (load(PET) as PackedScene).instantiate()
	var pet_bar := pet.get_node(^"HealthBar") as HpBar2D
	assert_eq(pet_bar.fill_token, &"heal", "the pet is on the hero side")
	pet.free()
	await wait_frames(1)


func _check_trough_and_outline(bar: HpBar2D, label: String) -> void:
	var palette := UiPalette.get_default()
	var trough := palette.panel_inset
	trough.a = bar.bg_alpha
	var outline := palette.ink
	outline.a = bar.border_alpha
	assert_eq(bar._bg_color, trough, "%s: panel_inset trough" % label)
	assert_eq(bar._border_color, outline, "%s: ink outline" % label)


## The old plain white LVLabel is now the HUD's level badge: a Pill panel with
## the PillText number, next to the bar, ignoring taps. Mobs carry none.
func test_level_badge_is_the_huds_pill() -> void:
	for path: String in [VLAD, GROUNT, NYXA, GORRAK]:
		var e := await spawn_frozen(path, Vector2(4000, 4000)) as EntityBase
		var badge := e.get_node_or_null(^"%LevelBadge") as Panel
		assert_true(badge != null, "%s has a level badge" % path.get_file())
		if badge == null:
			e.queue_free()
			continue
		assert_eq(badge.theme_type_variation, &"Pill", "%s: the HUD's Pill" % path.get_file())
		assert_eq(badge.get_parent(), e.hud, "%s: in the counter-scaled Hud group" % path.get_file())
		assert_eq(badge.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: taps reach the world" % path.get_file())
		assert_eq(e.lv_label.get_parent(), badge, "%s: the number sits in the badge" % path.get_file())
		assert_eq(e.lv_label.theme_type_variation, &"PillText", "%s: PillText" % path.get_file())
		assert_eq(e.lv_label.text, "1", "%s: level / stage 1" % path.get_file())
		assert_true(e.lv_label.label_settings == null, "%s: no hand-set label style" % path.get_file())
		var bar := e.health_bar
		assert_true(badge.position.x >= bar.position.x + bar.bar_size.x, "%s: right of the HP bar" % path.get_file())
		e.queue_free()
	for path: String in [HOG, BAT]:
		var mob := await spawn_frozen(path, Vector2(4000, 4000)) as EntityBase
		assert_true(mob.get_node_or_null(^"%LevelBadge") == null and mob.lv_label == null, "%s: no badge on a mob" % path.get_file())
		mob.queue_free()
	await wait_frames(1)


## The fog over the world is the palette's warm near-black at fog_alpha, on
## the fog sprite's shader.
func test_world_fog_is_a_palette_token() -> void:
	var fog := (load(FOG) as PackedScene).instantiate() as FogOfWarSystem
	fog.world_size = Vector2(640, 640)
	add_child(fog)
	var expected := UiPalette.get_default().bg_void
	expected.a = fog.fog_alpha
	assert_eq(fog.fog_token, &"bg_void")
	assert_eq(fog.fog_color(), expected)
	var material := fog.fog_sprite.material as ShaderMaterial
	assert_eq(material.get_shader_parameter(&"fog_color"), expected, "the shader draws the token")
	fog.queue_free()
	await wait_frames(1)


## Where the tile map has no ground (past its edge, in its holes) a revealed
## view shows the clear colour. It is the fog's token, not the engine's grey
## (project.godot holds the value; this keeps it in step with the palette).
func test_clear_colour_is_the_fog_token() -> void:
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	var fog_token := UiPalette.get_default().bg_void
	assert_true(clear.is_equal_approx(fog_token), "default_clear_color %s is bg_void %s" % [clear, fog_token])

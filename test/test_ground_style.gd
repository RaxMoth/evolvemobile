extends TestCase

## The match's ground style: the pixel jungle tiles stay, graded to sit under
## the muted chibi palette. World.tscn's two TileMapLayers (Ground and Deko)
## share one ShaderMaterial with ground_grade.gdshader and draw with nearest
## filtering (crisp texels, no atlas bleed at the tile seams); nothing else in
## the World is graded (no CanvasModulate: the rigs and the HUD keep their
## colours). The grade's defaults are the spec (saturation 0.72, value 0.85, a
## slight warm lift, the green pull), and a CPU copy of its maths shows they do
## what the art asks: the dirt and the grass come out darker and calmer while
## the dirt stays brown and the grass green. test_rigged_scenes checks the
## rigs' contact shadows.

const WORLD := "res://Scenes/World/World.tscn"
const GRADE := "res://Assets/Shaders/ground_grade.gdshader"
## Mean colours of a dirt path and a grass patch of the pixel tiles as drawn
## before the grade (a muted render of the World, camera zoom 2).
const DIRT := Color(0.43, 0.288, 0.26)
const GRASS := Color(0.205, 0.5, 0.382)


func test_tile_layers_share_the_grade() -> void:
	var world := (load(WORLD) as PackedScene).instantiate()
	var layers := world.find_children("*", "TileMapLayer", true, false)
	assert_eq(layers.size(), 2, "Ground and Deko")
	var grade: ShaderMaterial = null
	for node in layers:
		var layer := node as TileMapLayer
		var mat := layer.material as ShaderMaterial
		assert_true(mat != null and mat.shader != null and mat.shader.resource_path == GRADE, "%s: the ground grade" % layer.name)
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "%s: nearest filtering" % layer.name)
		if grade == null:
			grade = mat
		assert_eq(mat, grade, "%s: one shared material" % layer.name)
	assert_eq(world.find_children("*", "CanvasModulate", true, false).size(), 0, "no CanvasModulate dims the rigs and the HUD")
	var others := 0
	for node in world.find_children("*", "CanvasItem", true, false):
		if not (node is TileMapLayer) and grade != null and (node as CanvasItem).material == grade:
			others += 1
	assert_eq(others, 0, "only the tiles are graded")
	world.free()


func test_grade_defaults_are_the_spec() -> void:
	var shader := load(GRADE) as Shader
	assert_true(shader != null, "the grade loads")
	if shader == null:
		return
	var u := _defaults(shader.code)
	var spec: Dictionary[String, float] = {"saturation": 0.72, "value": 0.85, "contrast": 1.0, "green_pull": 0.45}
	for uniform in spec:
		var actual: float = u.get(uniform, -1.0)
		assert_near(actual, spec[uniform], 0.0001, uniform)
	var lift: Color = u.get("shadow_lift", Color.MAGENTA)
	assert_true(lift.r > lift.b and lift.r >= lift.g and lift.r <= 0.05, "a slight warm lift of the shadows: %s" % lift)
	var tint: Color = u.get("highlight_tint", Color.MAGENTA)
	assert_true(tint.r >= tint.g and tint.g >= tint.b and tint.b >= 0.85, "cream highlights: %s" % tint)


## Darker (luma), calmer (chroma), and still brown dirt against green grass,
## far apart in hue.
func test_grade_darkens_and_calms_but_keeps_dirt_and_grass_apart() -> void:
	var u := _defaults((load(GRADE) as Shader).code)
	for pair: Array in [["dirt", DIRT], ["grass", GRASS]]:
		var before: Color = pair[1]
		var after := _grade(before, u)
		assert_true(_luma(after) < 0.9 * _luma(before), "%s: darker (%.3f -> %.3f)" % [pair[0], _luma(before), _luma(after)])
		assert_true(_chroma(after) < _chroma(before), "%s: calmer (%.3f -> %.3f)" % [pair[0], _chroma(before), _chroma(after)])
	var dirt := _grade(DIRT, u)
	var grass := _grade(GRASS, u)
	assert_true(dirt.r > dirt.g and dirt.r > dirt.b, "the dirt stays brown: %s" % dirt)
	assert_true(grass.g > grass.r and grass.g > grass.b, "the grass stays green: %s" % grass)
	var apart := absf(grass.h - dirt.h)
	assert_true(minf(apart, 1.0 - apart) > 0.25, "dirt and grass stay apart in hue (%.3f)" % apart)
	var black := _grade(Color.BLACK, u)
	assert_true(black.r > black.b, "black lifts warm: %s" % black)


## The shader's uniform defaults by name: floats and source_color vec4s.
func _defaults(code: String) -> Dictionary:
	var out := {}
	var floats := RegEx.create_from_string("uniform float (\\w+) : [^=]*= ([0-9.]+);")
	for m in floats.search_all(code):
		out[m.get_string(1)] = float(m.get_string(2))
	var colors := RegEx.create_from_string("uniform vec4 (\\w+) : source_color = vec4\\(([0-9.]+), ([0-9.]+), ([0-9.]+), ([0-9.]+)\\);")
	for m in colors.search_all(code):
		out[m.get_string(1)] = Color(float(m.get_string(2)), float(m.get_string(3)), float(m.get_string(4)), float(m.get_string(5)))
	return out


## CPU copy of ground_grade.gdshader's fragment() (keep in step with it).
func _grade(c: Color, u: Dictionary) -> Color:
	var saturation: float = u.get("saturation", 1.0)
	var contrast: float = u.get("contrast", 1.0)
	var value: float = u.get("value", 1.0)
	var pull: float = u.get("green_pull", 0.0)
	var green: Color = u.get("green_target", Color.BLACK)
	var lift: Color = u.get("shadow_lift", Color.BLACK)
	var tint: Color = u.get("highlight_tint", Color.WHITE)
	var luma := _luma(c)
	var g := Vector3(luma, luma, luma).lerp(Vector3(c.r, c.g, c.b), saturation)
	var greenness := clampf((c.g - maxf(c.r, c.b)) * 3.0, 0.0, 1.0)
	g = g.lerp(Vector3(green.r, green.g, green.b) * (luma * 1.6 + 0.15), greenness * pull)
	g = (g - Vector3.ONE * 0.5) * contrast + Vector3.ONE * 0.5
	var lo := Vector3(lift.r, lift.g, lift.b)
	var hi := Vector3(tint.r, tint.g, tint.b)
	var o := (lo + (hi - lo) * g) * value
	return Color(o.x, o.y, o.z)


func _luma(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))

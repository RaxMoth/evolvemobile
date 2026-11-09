shader_type canvas_item;
// Ground grade: the material of World.tscn's two TileMapLayers (Ground and
// Deko) and nothing else. It sits the saturated 16 px pixel jungle under the
// muted chibi palette, darker and calmer, so the ink-outlined SVG rigs and
// their accents are the brightest thing in the match, while the dirt paths
// stay brown and the grass stays green. A CanvasModulate would have dimmed the
// rigs and the HUD too. It replaces the layers' default fragment: no extra
// pass. Look: the third panel of the characters area's grade_variants.png,
// with more contrast.
//
// 1. Desaturate toward the luma (saturation).
// 2. Pull the tileset's electric greens toward deep moss (green_pull): only
//    pixels whose green leads red and blue, so browns and flowers keep their
//    hue.
// 3. Contrast around mid grey.
// 4. Warm lift: black maps to shadow_lift, white to highlight_tint (shadows a
//    touch warm, highlights a touch cream), then everything times value.

uniform float saturation : hint_range(0.0, 1.5) = 0.72;
uniform float value : hint_range(0.3, 1.5) = 0.85;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
uniform vec4 shadow_lift : source_color = vec4(0.03, 0.02, 0.0, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform vec4 green_target : source_color = vec4(0.24, 0.42, 0.32, 1.0);
uniform float green_pull : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 c = COLOR;   // texture * modulate
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(luma), c.rgb, saturation);
	float greenness = clamp((c.g - max(c.r, c.b)) * 3.0, 0.0, 1.0);
	g = mix(g, green_target.rgb * (luma * 1.6 + 0.15), greenness * green_pull);
	g = (g - 0.5) * contrast + 0.5;
	g = mix(shadow_lift.rgb, highlight_tint.rgb, g) * value;
	COLOR = vec4(g, c.a);
}

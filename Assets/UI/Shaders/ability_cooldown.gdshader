shader_type canvas_item;
// Ability icon cooldown (HUD + skill previews). Put on the icon TextureRect.
// progress: 0 = just cast, 1 = ready. The not-yet-recovered sector (clockwise
// from 12 o'clock, shrinking) is desaturated and veiled; an amber edge marks
// the sweep. ready_flash (0..1, tweened 1 -> 0 on ready) whitens the icon.
// locked = 1 greys the whole icon (Ground Slam before Stage 2, and a fallen
// owner's slot: AbilitySlot.set_dead).
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float ready_flash : hint_range(0.0, 1.0) = 0.0;
uniform float locked : hint_range(0.0, 1.0) = 0.0;
uniform vec4 veil_color : source_color = vec4(0.078, 0.067, 0.063, 0.7);
uniform vec4 edge_color : source_color = vec4(0.949, 0.663, 0.231, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.035;

void fragment() {
	vec4 c = COLOR;   // texture * modulate (Godot 4 canvas_item input)
	vec2 d = UV - vec2(0.5);
	float a = fract(atan(d.x, -d.y) / TAU + 1.0);   // 0 at 12 o'clock, clockwise
	float cooling = step(progress, a) * step(progress, 0.999);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dim = mix(vec3(grey), veil_color.rgb, veil_color.a);
	float edge = cooling * (1.0 - step(edge_width, a - progress)) * step(0.18, length(d));
	vec3 rgb = mix(c.rgb, dim, max(cooling, locked * 0.8));
	rgb = mix(rgb, edge_color.rgb, edge);
	rgb = mix(rgb, vec3(1.0), ready_flash * 0.7);
	COLOR = vec4(rgb, c.a);
}

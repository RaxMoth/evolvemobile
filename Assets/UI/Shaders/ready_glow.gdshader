shader_type canvas_item;
// Pulsing rounded-square halo drawn BEHIND a ready ultimate's AbilitySlot
// (from the UX v2 prototype). The slot covers the inside, so only the halo
// around its frame shows: a 5 rad/s pulse plus two sparks circling the slot.
// slot_fraction = slot size / glow rect size (AbilitySlot's Glow reaches 0.2
// of the slot past every edge: 1 / 1.4). glow_color is the palette's
// amber_light.
uniform vec4 glow_color : source_color = vec4(1.0, 0.824, 0.478, 1.0);
uniform float slot_fraction : hint_range(0.1, 1.0) = 0.714;
uniform float corner : hint_range(0.0, 0.5) = 0.16;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = abs(UV - vec2(0.5)) * 2.0;
	vec2 q = p - vec2(slot_fraction - corner);
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
	float halo = 1.0 - smoothstep(0.0, 1.0 - slot_fraction, max(sd, 0.0));
	float pulse = 0.6 + 0.4 * sin(TIME * 5.0);
	float ang = atan(UV.y - 0.5, UV.x - 0.5);
	float spark = pow(max(0.0, sin(ang * 2.0 - TIME * 3.0)), 6.0);
	COLOR = vec4(glow_color.rgb, halo * (0.55 * pulse + 0.45 * spark) * strength);
}

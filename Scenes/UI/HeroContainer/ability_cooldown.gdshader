shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);

void fragment() {
	// Center UV coordinates (-0.5 to 0.5)
	vec2 uv = UV - vec2(0.5);
	
	// Calculate angle from center (0 = right, increases counterclockwise)
	float angle = atan(uv.y, uv.x);
	
	// Normalize angle to 0-1 range, starting from top (12 o'clock)
	// Rotate by 90 degrees (PI/2) to start at top
	float normalized_angle = (angle + PI * 0.5) / (2.0 * PI);
	if (normalized_angle < 0.0) {
		normalized_angle += 1.0;
	}
	
	// Get original texture color
	vec4 tex_color = texture(TEXTURE, UV);
	
	// If cooldown not complete (clockwise from top), darken the icon
	if (normalized_angle > progress) {
		COLOR = mix(tex_color, overlay_color, overlay_color.a);
	} else {
		COLOR = tex_color;
	}
}
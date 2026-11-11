shader_type canvas_item;
render_mode unshaded;

// A CanvasGroup's material (RigView.greyed: a fallen character on the match
// result's stage). The group draws its children (the rig's parts, each with
// the shared hit_flash material) into one backbuffer picture; this draws that
// picture with its colour drained by `amount` toward its luminance, so the
// parts' own ink outlines and overlaps grey as one shape. The parts were
// drawn with the inherited modulate already (a palette tint on an ancestor),
// so only the group's alpha is applied again, not its tint (twice would turn
// the body black).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(luma), amount), c.a * COLOR.a);
}

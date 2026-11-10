shader_type canvas_item;

// Hit flash for every rig body through ONE shared material
// (hit_flash_material.tres on each <id>_body.tscn root, its parts
// use_parent_material), so a character still batches into one draw and
// same-species mobs batch together.
//
// The flash amount travels per instance in the vertex colour: CharacterRig's
// hurt reaction (and its evolution flash) drives the body's modulate over 1
// (white x hurt_flash_gain, easing back to white), and the parts' COLOR is the
// texture times the inherited modulate. A modulate of (1 + f) on all three
// channels is a flash of f (0..1): the vertex stage divides it back out and
// the fragment mixes the art toward flash_color by f, a true white silhouette
// instead of a brightened one (a plain over-bright modulate leaves the ink
// outlines dark). Ordinary tints never raise all three channels above 1 at
// once (Trap Cage's honey pulse, Last Stand's glow), so they pass through
// untouched.

uniform vec4 flash_color : source_color = vec4(1.0);

varying float v_flash;

void vertex() {
	float f = clamp(min(COLOR.r, min(COLOR.g, COLOR.b)) - 1.0, 0.0, 1.0);
	v_flash = f;
	COLOR.rgb /= (1.0 + f);
}

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, v_flash);
}

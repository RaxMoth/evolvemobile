shader_type canvas_item;

// Camera-following fog shader.
//
// The fog sprite is positioned and sized to match the visible viewport
// each frame (see FogOfWarSystem._process). To still sample the world-
// space exploration map correctly, the vertex shader computes each
// fragment's WORLD position (not screen position) and the fragment
// shader divides by world_size to get a UV into the exploration map.
//
// This way the fog quad is small (viewport-sized), but the fog content
// still corresponds to fixed world-space tiles.

uniform sampler2D exploration_map : filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform vec2 world_size = vec2(2000.0, 2000.0);

// Legacy uniforms kept so existing material set_shader_parameter calls don't error.
uniform float tile_size = 32.0;
uniform vec2 grid_size = vec2(100.0, 100.0);

varying vec2 world_pos;

void vertex() {
	// VERTEX is in local sprite space. MODEL_MATRIX transforms to world space.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 tex_uv = (world_pos - world_offset) / world_size;
	float explored = texture(exploration_map, tex_uv).r;
	COLOR = mix(fog_color, vec4(0.0, 0.0, 0.0, 0.0), explored);
}

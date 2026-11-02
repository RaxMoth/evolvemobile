shader_type canvas_item;

// World-space fog. The fog quad is static and covers the world plus a border
// (see FogOfWarSystem._setup_fog_sprite); every fragment looks up the
// exploration texel of its WORLD position, so the fog never moves with the
// camera.
//
// The texture has exactly grid_size texels of tile_size world pixels each, so
// the UV is mapped by grid_size * tile_size (not a free world_size that may
// not be a whole number of tiles). Outside the map is always fogged: with the
// default repeat sampling the border used to show explored tiles from the
// opposite edge.

uniform sampler2D exploration_map : filter_nearest, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform float tile_size = 32.0;
uniform vec2 grid_size = vec2(100.0, 100.0);

varying vec2 world_pos;

void vertex() {
	// VERTEX is in local sprite space. MODEL_MATRIX transforms to world space.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 tex_uv = (world_pos - world_offset) / (grid_size * tile_size);
	vec2 inside2 = step(vec2(0.0), tex_uv) * step(tex_uv, vec2(1.0));
	float explored = texture(exploration_map, clamp(tex_uv, 0.0, 1.0)).r * inside2.x * inside2.y;
	COLOR = mix(fog_color, vec4(0.0, 0.0, 0.0, 0.0), explored);
}

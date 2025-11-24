shader_type canvas_item;

uniform sampler2D exploration_map : filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);
uniform float tile_size = 32.0;
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform vec2 grid_size = vec2(100.0, 100.0);
uniform vec2 world_size = vec2(2000.0, 2000.0);

void fragment() {
	// UV is in 0-1 range for the sprite texture
	// Convert UV to world position
	vec2 world_pos = (UV * world_size) + world_offset;
	
	// Convert to grid coordinates
	vec2 grid_pos = (world_pos - world_offset) / tile_size;
	
	// Convert to texture UV for exploration map
	vec2 tex_uv = grid_pos / grid_size;
	
	// Sample exploration map
	float explored = texture(exploration_map, tex_uv).r;
	
	// If explored (white), make transparent; otherwise show fog
	COLOR = mix(fog_color, vec4(0.0, 0.0, 0.0, 0.0), explored);
}
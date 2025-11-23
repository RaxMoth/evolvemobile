shader_type canvas_item;

// Fog of War shader
// Uses a texture to store explored/unexplored state

uniform sampler2D exploration_map : filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);
uniform float tile_size = 64.0;
uniform vec2 world_offset = vec2(0.0, 0.0);

void fragment() {
	// Calculate which tile we're in
	vec2 world_pos = (FRAGCOORD.xy + world_offset) / tile_size;
	
	// Sample exploration map
	float explored = texture(exploration_map, world_pos).r;
	
	// If explored, fade to transparent; if not, show fog
	if (explored > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);  // Transparent (revealed)
	} else {
		COLOR = fog_color;  // Fog (hidden)
	}
}

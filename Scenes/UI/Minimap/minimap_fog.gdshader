shader_type canvas_item;

// The fog system's exploration map is an R8 texture (1 = explored).
// Paint explored tiles as ground, unexplored as dark fog.
uniform vec4 explored_color : source_color = vec4(0.36, 0.42, 0.30, 0.95);
uniform vec4 unexplored_color : source_color = vec4(0.05, 0.06, 0.08, 0.95);

void fragment() {
	float explored = texture(TEXTURE, UV).r;
	COLOR = mix(unexplored_color, explored_color, step(0.5, explored));
}

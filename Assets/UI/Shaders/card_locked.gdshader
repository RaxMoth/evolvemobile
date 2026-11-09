shader_type canvas_item;
// Locked character silhouette: every opaque pixel becomes the locked fill,
// bright source pixels keep a faint rim so the shape still reads.
uniform vec4 fill : source_color = vec4(0.078, 0.067, 0.063, 1.0);
uniform vec4 rim : source_color = vec4(0.290, 0.271, 0.255, 1.0);

void fragment() {
	vec4 c = COLOR;   // texture * modulate
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(fill.rgb, rim.rgb, smoothstep(0.35, 0.9, lum) * 0.55), c.a);
}

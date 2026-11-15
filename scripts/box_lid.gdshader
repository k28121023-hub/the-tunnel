shader_type canvas_item;
render_mode unshaded;

// The lid crop includes dark dungeon pixels around the warm wooden edge.
// Keep the wood and highlights, making the captured backdrop transparent.
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float wood = smoothstep(0.015, 0.045, color.r - max(color.g, color.b));
	float highlight = smoothstep(0.45, 0.7, min(color.r, color.g));
	color.a *= max(wood, highlight);
	COLOR = color;
}

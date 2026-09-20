shader_type canvas_item;
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float paper = min(ink.r, min(ink.g, ink.b));
	COLOR.a *= 1.0 - smoothstep(0.91, 0.995, paper);
}

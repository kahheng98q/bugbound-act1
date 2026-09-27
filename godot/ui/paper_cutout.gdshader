shader_type canvas_item;
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float paper = min(ink.r, min(ink.g, ink.b));
	COLOR.rgb = mix(COLOR.rgb, vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114))), desaturation);
	COLOR.a *= 1.0 - smoothstep(0.91, 0.995, paper);
}

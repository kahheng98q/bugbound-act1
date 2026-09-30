shader_type canvas_item;
varying vec4 actor_tint;
void vertex() { actor_tint = COLOR; }
// Preserve the Blender alpha. Cyan left / magenta right match the room plates.
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 3.0;
	float left_edge = max(0.0, source.a - texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a);
	float right_edge = max(0.0, source.a - texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	vec3 room = mix(vec3(0.15, 0.86, 0.94), vec3(0.98, 0.22, 0.60), UV.x);
	source.rgb = source.rgb * vec3(0.91, 0.95, 1.0) + room * 0.035;
	source.rgb += vec3(0.15, 0.86, 0.94) * left_edge * 0.32;
	source.rgb += vec3(0.98, 0.22, 0.60) * right_edge * 0.24;
	COLOR = source * actor_tint;
}

// GLOW (SNES ADR-054) on a pre-coloured sprite (the ball): its dark
// outline pixels turn neon green.
shader_type canvas_item;

uniform vec4 neon : source_color = vec4(0.13, 1.0, 0.26, 1.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float luma = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = luma < 0.2 ? vec4(neon.rgb, t.a) : t * COLOR;
}

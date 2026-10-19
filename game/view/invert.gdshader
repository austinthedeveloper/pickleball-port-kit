// INVERSE (SNES ADR-054): the picture under the HUD as a photo negative.
// On a full-screen rect in a CanvasLayer just under the HUD's.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(vec3(1.0) - c, 1.0);
}

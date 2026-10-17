// Colours an indexed role sheet (manifest sprites.players.roles): each
// pixel's red is its role index * 8 / 255, index 0 transparent. The
// palette is one colour per role, from PlayerLook.
shader_type canvas_item;

uniform vec4 palette[32];
// The hit flash (the team sheets use modulate for it).
uniform float brighten = 1.0;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	int i = clamp(int(round(t.r * 255.0 / 8.0)), 0, 31);
	COLOR = vec4(palette[i].rgb * brighten, t.a);
}

// Shadows drawn in one flat colour (CourtStyle.SHADOW_GREY on a dark
// court), keeping the sprite's shape and alpha. keep_alpha keeps the
// texture's own alpha too (INVERSE's white shadows, SNES ADR-054).
shader_type canvas_item;

uniform vec4 tint : source_color;
uniform bool keep_alpha = false;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, keep_alpha ? a : (a > 0.0 ? tint.a : 0.0));
}

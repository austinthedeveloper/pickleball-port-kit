// Shadows drawn in one flat colour (CourtStyle.SHADOW_GREY on a dark
// court), keeping the sprite's shape and alpha.
shader_type canvas_item;

uniform vec4 tint : source_color;

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a > 0.0 ? tint.a : 0.0);
}

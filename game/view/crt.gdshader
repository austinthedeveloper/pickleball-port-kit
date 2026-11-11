// CRT (port ADR-109, PORT-131): the picture as a 1994 TV showed it, over
// everything drawn: scanlines on the game's 540 rows, a soft shadow mask
// of red, green and blue columns, a little bloom from the bright parts,
// and a gentle darkening at the corners. Display only.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float scan = 0.25;      // how dark a scanline's gap is (0 none)
uniform float mask = 0.10;      // the shadow mask's strength
uniform float bloom = 0.15;     // the bright parts' glow
uniform float vignette = 0.12;  // the corners' darkening
uniform float rows = 540.0;     // the game's rows (the scanlines follow them)

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen, uv).rgb;
	// bloom: four taps a little away, the bright parts only
	vec2 px = SCREEN_PIXEL_SIZE * 2.0;
	vec3 b = texture(screen, uv + vec2(px.x, 0.0)).rgb + texture(screen, uv - vec2(px.x, 0.0)).rgb
		+ texture(screen, uv + vec2(0.0, px.y)).rgb + texture(screen, uv - vec2(0.0, px.y)).rgb;
	b = max(b * 0.25 - 0.55, 0.0) * 2.2;
	c += b * bloom;
	// scanlines: the lower half of each game row a little darker
	float row = fract(uv.y * rows);
	c *= 1.0 - scan * smoothstep(0.35, 0.65, row) * (1.0 - smoothstep(0.85, 1.0, row));
	// the shadow mask: every screen column leans to red, green or blue
	int col = int(mod(FRAGCOORD.x, 3.0));
	vec3 m = col == 0 ? vec3(1.0, 1.0 - mask, 1.0 - mask) : (col == 1 ? vec3(1.0 - mask, 1.0, 1.0 - mask)
		: vec3(1.0 - mask, 1.0 - mask, 1.0));
	c *= m * (1.0 + mask * 0.6);
	// the corners
	vec2 d = uv - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 2.5;
	COLOR = vec4(c, 1.0);
}

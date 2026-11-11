// Court colours (ADR-022/027) on a venue's ground layer: each pixel's
// court-mask role picks a target colour; the pixel becomes the target
// scaled by its brightness relative to the part's painted base, which
// keeps the target's hue and the paint's texture. Roles without a target
// keep the painted pixel. CourtStyle.recolor is the same formula on the
// CPU, for the tests. Then the time of day scales it.
shader_type canvas_item;

uniform sampler2D mask : filter_nearest;
// per role (manifest court_mask_roles): rgb target, a = 1 to recolour
uniform vec4 target[9];
uniform float base_lum[9];
// Night courts (ADR-045): the court under the lights (roles 3-8) scales by
// lit, the surround by dark; DAY is 1.
uniform vec3 dark = vec3(1.0);
uniform vec3 lit = vec3(1.0);
// The lit apron (port ADR-109, PORT-161): the surround round the court,
// in px of the ground: the court's box (x0, y0, x1, y1) and how far past
// it the floodlights reach; the light fades out over that margin.
uniform vec4 apron = vec4(0.0);
uniform float apron_px = 0.0;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	int role = clamp(int(round(texture(mask, UV).r * 255.0)), 0, 8);
	vec3 c = t.rgb;
	if (target[role].a > 0.5) {
		float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
		c = clamp(target[role].rgb * (lum / max(base_lum[role], 0.001)), 0.0, 1.0);
	}
	// the lines (7-8) catch the lights: half the dimming (ADR-052, PORT-06)
	vec3 surround = dark;
	if (apron_px > 0.0) {
		vec2 p = UV / TEXTURE_PIXEL_SIZE;
		vec2 out_by = max(max(apron.xy - p, p - apron.zw), vec2(0.0));
		surround = mix(lit, dark, clamp(length(out_by) / apron_px, 0.0, 1.0));
	}
	c *= role >= 7 ? (lit + 1.0) * 0.5 : (role >= 3 ? lit : surround);
	COLOR = vec4(c, t.a);
}

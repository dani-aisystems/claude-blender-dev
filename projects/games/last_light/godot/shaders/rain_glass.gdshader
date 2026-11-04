shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Rain on the watch-room windows: static droplets + drops running down in streaks, refracting the
// storm behind the glass. Strength follows the storm (set from the game: rain).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float rain : hint_range(0.0, 1.0) = 0.6;
uniform float flash = 0.0;            // lightning flash brightening
uniform vec3 tint : source_color = vec3(0.86, 0.92, 0.98);
uniform float refract_px = 26.0;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// returns droplet normal offset (xy) and mask (z)
vec3 droplets(vec2 uv, float density, float t) {
	vec3 acc = vec3(0.0);
	// static beads
	vec2 g = uv * vec2(38.0, 26.0);
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	if (h < density * 0.45) {
		vec2 c = vec2(hash(id + 3.1), hash(id + 7.7)) * 0.6 - 0.3;
		float r = 0.12 + 0.18 * hash(id + 1.3);
		vec2 d = f - c;
		float m = smoothstep(r, r * 0.6, length(d));
		acc += vec3(d / r * m, m);
	}
	// running drops with trails
	vec2 g2 = uv * vec2(14.0, 1.0);
	float col = floor(g2.x);
	float ch = hash(vec2(col, 5.0));
	if (ch < density * 1.4) {
		float speed = 0.08 + 0.18 * hash(vec2(col, 9.0));
		float y = fract(uv.y * 0.35 + t * speed + ch * 7.0);
		float x = fract(g2.x) - 0.5 + 0.08 * sin(uv.y * 23.0 + col);
		float head = smoothstep(0.09, 0.03, length(vec2(x * 1.4, (y - 0.5) * 9.0)));
		float trail = smoothstep(0.05, 0.0, abs(x)) * smoothstep(0.5, 0.95, y) * 0.35;
		acc += vec3(vec2(x, (y - 0.5)) * head * 2.0, max(head, trail));
	}
	return acc;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 tang = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	vec2 uv = vec2(dot(w_pos, tang), -w_pos.y) * 0.9;
	vec3 d = droplets(uv, 0.25 + 0.55 * rain, TIME);
	vec2 off = d.xy * refract_px / VIEWPORT_SIZE * (0.4 + rain);
	vec3 bg = textureLod(screen_tex, SCREEN_UV + off, d.z * 1.5).rgb;
	vec3 c = bg * tint;
	c *= 1.0 - 0.18 * d.z;                                      // beads darken/refract, not glow
	c += vec3(0.02, 0.025, 0.03) * d.z * (0.3 + 4.0 * flash);   // catches light only in a flash
	c = mix(c, c * 0.92 + vec3(0.012, 0.015, 0.02), 0.35);     // slight haze on old glass
	ALBEDO = c;
	ALPHA = 1.0;
}

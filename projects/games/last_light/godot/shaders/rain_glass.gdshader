shader_type spatial;
render_mode blend_premul_alpha, depth_draw_never, cull_back, specular_schlick_ggx;
// Rain on the watch-room windows (Stage 1b rewrite). Clear glass is truly transparent (the beam, the
// rain and the sea behind it stay visible: the old shader re-painted the whole pane from a screen
// copy, ALPHA = 1). The pane is LIT: lamp and room reflections (ReflectionProbe) appear across it,
// strongest at grazing angles (Schlick fresnel, F0 = 0.04). Premultiplied alpha, so reflections add on
// top even where the glass is clear.
//   drops        : static beads + running drops, refracting the background (emitted, not lit)
//   condensation : mottled haze rising from the sill, lit warm by the room, cleared by drop trails

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float rain : hint_range(0.0, 1.0) = 0.6;
uniform float flash = 0.0;                    // lightning flash: drops sparkle
uniform vec3 tint : source_color = vec3(0.86, 0.92, 0.98);
uniform float refract_px = 22.0;
uniform float floor_y = 20.0;
uniform float sill_h = 0.95;                  // window sill above the floor (spec.py room.window)
uniform float condensation : hint_range(0.0, 1.0) = 0.6;
uniform vec3 haze_color : source_color = vec3(0.62, 0.66, 0.7);

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// xy: droplet normal offset, z: drop mask, w: trail mask (trails clear the condensation)
vec4 droplets(vec2 uv, float density, float t) {
	vec4 acc = vec4(0.0);
	vec2 g = uv * vec2(38.0, 26.0);                       // static beads
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	if (h < density * 0.45) {
		vec2 c = vec2(hash(id + 3.1), hash(id + 7.7)) * 0.6 - 0.3;
		float r = 0.12 + 0.18 * hash(id + 1.3);
		vec2 d = f - c;
		float m = smoothstep(r, r * 0.6, length(d));
		acc.xyz += vec3(d / r * m, m);
	}
	vec2 g2 = uv * vec2(14.0, 1.0);                       // running drops with trails
	float col = floor(g2.x);
	float ch = hash(vec2(col, 5.0));
	if (ch < density * 1.4) {
		float speed = 0.08 + 0.18 * hash(vec2(col, 9.0));
		float y = fract(uv.y * 0.35 + t * speed + ch * 7.0);
		float x = fract(g2.x) - 0.5 + 0.08 * sin(uv.y * 23.0 + col);
		float head = smoothstep(0.09, 0.03, length(vec2(x * 1.4, (y - 0.5) * 9.0)));
		float trail = smoothstep(0.06, 0.0, abs(x)) * smoothstep(0.5, 0.95, y);
		acc.xyz += vec3(vec2(x, (y - 0.5)) * head * 2.0, max(head, trail * 0.35));
		acc.w = max(acc.w, trail);
	}
	return acc;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 tang = normalize(cross(vec3(0.0, 1.0, 0.0), n));
	vec2 uv = vec2(dot(w_pos, tang), -w_pos.y) * 0.9;
	vec4 d = droplets(uv, 0.25 + 0.55 * rain, TIME);
	float drop = clamp(d.z, 0.0, 1.0);
	// condensation: thickest at the sill, mottled, thinned where drops have run through
	float h = w_pos.y - floor_y - sill_h;
	float band = 1.0 - smoothstep(0.0, 0.55, h);
	float mott = vnoise(uv * 3.0) * 0.6 + vnoise(uv * 11.0) * 0.4;
	float cond = clamp(band * (0.45 + 0.55 * mott) * condensation * (1.0 - 0.85 * d.w), 0.0, 1.0);
	// refracted background through the drops (emitted: it is the world behind, not lit by the room)
	vec2 off = d.xy * refract_px / VIEWPORT_SIZE * (0.4 + rain);
	vec3 bg = textureLod(screen_tex, SCREEN_UV + off, drop * 1.5 + cond * 2.5).rgb * tint;
	float a_drop = drop * 0.9;
	float a_cond = cond * 0.55;
	float a = clamp(a_drop + a_cond * (1.0 - a_drop), 0.0, 1.0);
	EMISSION = bg * a_drop * (1.0 - 0.15 * drop) + vec3(0.04, 0.05, 0.06) * drop * flash;
	ALBEDO = haze_color * a_cond * (1.0 - a_drop);   // premultiplied; the haze takes the room's light
	ALPHA = a;
	ROUGHNESS = mix(0.04, 0.45, cond);              // clear glass mirror-sharp; fogged patches blur reflections
	METALLIC = 0.0;
	SPECULAR = 0.5;
}

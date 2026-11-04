shader_type spatial;
// THE LAST LIGHT watch-room materials (Stage 1b): a 1971 NLB station, "maintained but aged".
// The palette decides the colour; the CC0 scan contributes only normalised detail (and, for wood,
// its grain colour), normal and AO/roughness (ARM). World-space triplanar for now: the build has no
// metric UVs or wear masks yet (build.py is owned by the geometry session until its iterations land).
//   dado   : on wall faces, cream gloss above dado_y, dark-green dado below, dark skirting, oak rail line
//   chips  : hand-height paint chips showing the under-layer (procedural; no vertex masks yet)
//   coat   : clearcoat for gloss paint and varnish

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;  // R AO, G rough, B metal
uniform float scale = 0.6;                        // repeats per metre
uniform vec3 base_color : source_color = vec3(0.5);
uniform float detail_amt : hint_range(0.0, 1.5) = 0.4;   // how strongly the scan modulates the palette
uniform float detail_color : hint_range(0.0, 1.0) = 0.0; // 0 luminance only, 1 the scan's own hue ratios (wood grain)
uniform vec3 scan_avg = vec3(0.45);               // mean linear RGB of the scan (normalises the detail)
uniform float rough_lo = 0.3;                     // ARM.g 0 -> rough_lo, 1 -> rough_hi
uniform float rough_hi = 0.6;
uniform float metallic_v : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.7;
uniform float coat : hint_range(0.0, 1.0) = 0.0;
uniform float coat_rough : hint_range(0.0, 1.0) = 0.2;
// two-tone wall (interim, until iteration 2 builds the dado in geometry)
uniform float dado = 0.0;                         // 1 enables
uniform float floor_y = 20.0;
uniform float dado_h = 1.05;
uniform float skirt_h = 0.14;
uniform vec3 dado_color : source_color = vec3(0.18, 0.27, 0.215);
uniform vec3 skirt_color : source_color = vec3(0.1, 0.11, 0.1);
uniform vec3 rail_color : source_color = vec3(0.45, 0.29, 0.16);
uniform float ceiling_mul = 0.92;                 // down-facing faces (ceiling): slightly darker, matte
// wear
uniform float chips : hint_range(0.0, 1.0) = 0.0;
uniform vec3 under_color : source_color = vec3(0.55, 0.54, 0.5);
uniform float chip_lo = 0.75;                     // hand-height band above floor_y
uniform float chip_hi = 1.5;
uniform float blend_sharpness = 4.0;
uniform float cyl_map = 0.0;          // 1: wall faces map around the room's vertical axis (no triplanar stretch)

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i), n100 = hash13(i + vec3(1, 0, 0)), n010 = hash13(i + vec3(0, 1, 0)), n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1)), n101 = hash13(i + vec3(1, 0, 1)), n011 = hash13(i + vec3(0, 1, 1)), n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

vec3 unpack_n(vec4 t) {
	vec2 xy = (t.xy * 2.0 - 1.0) * normal_strength;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));      // RGTC-safe: rebuild Z
}

void fragment() {
	vec3 n = normalize(w_nrm);
	// The round wall is 96 flat facets with flat normals (no smooth shading in the build yet), so lamps
	// picked out every facet as a vertical "board". On its inward faces the true normal is radial.
	if (cyl_map > 0.5 && abs(n.y) < 0.5) {
		vec3 radial_in = normalize(vec3(-w_pos.x, 0.0, -w_pos.z));
		if (dot(n, radial_in) > 0.9) {
			n = radial_in;
		}
	}
	vec3 bw = pow(abs(n), vec3(blend_sharpness));
	bw /= (bw.x + bw.y + bw.z);
	vec2 uvx = w_pos.zy * scale;
	vec2 uvy = w_pos.xz * scale;
	vec2 uvz = w_pos.xy * scale;
	vec3 c;
	vec3 arm;
	vec3 wn;
	if (cyl_map > 0.5 && abs(n.y) < 0.5) {
		// one sample, unrolled around the room axis: u = arc length, v = height
		float rad = length(w_pos.xz);
		vec2 uvc = vec2(atan(w_pos.x, w_pos.z) * rad, w_pos.y) * scale;
		c = texture(albedo_tex, uvc).rgb;
		arm = texture(arm_tex, uvc).rgb;
		vec3 t = unpack_n(texture(normal_tex, uvc));
		vec3 bt = vec3(0.0, 1.0, 0.0);
		vec3 tg = normalize(cross(bt, n));
		wn = normalize(tg * t.x + bt * t.y + n * t.z);
	} else {
		c = texture(albedo_tex, uvx).rgb * bw.x + texture(albedo_tex, uvy).rgb * bw.y + texture(albedo_tex, uvz).rgb * bw.z;
		arm = texture(arm_tex, uvx).rgb * bw.x + texture(arm_tex, uvy).rgb * bw.y + texture(arm_tex, uvz).rgb * bw.z;
		vec3 tx = unpack_n(texture(normal_tex, uvx));
		vec3 ty = unpack_n(texture(normal_tex, uvy));
		vec3 tz = unpack_n(texture(normal_tex, uvz));
		vec3 nx = vec3(tx.xy + n.zy, abs(tx.z) * n.x).zyx;            // whiteout triplanar blend
		vec3 ny = vec3(ty.xy + n.xz, abs(ty.z) * n.y).xzy;
		vec3 nz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
		wn = normalize(nx * bw.x + ny * bw.y + nz * bw.z);
	}

	// palette colour, modulated by the scan's normalised detail
	float l_scan = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float l_avg = max(dot(scan_avg, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
	vec3 ratio = mix(vec3(l_scan / l_avg), c / max(scan_avg, vec3(1e-3)), detail_color);
	vec3 base = base_color;
	float rough = mix(rough_lo, rough_hi, arm.g);
	float cc = coat;
	float h = w_pos.y - floor_y;
	bool wall = abs(n.y) < 0.5;
	if (dado > 0.5 && wall) {
		if (h < skirt_h) {
			base = skirt_color; rough = 0.45;
		} else if (h < dado_h - 0.03) {
			base = dado_color;
		} else if (h < dado_h + 0.015) {
			base = rail_color; rough = 0.35; cc = 0.6;          // oak dado-rail line
		}
	}
	if (n.y < -0.5) {
		base *= ceiling_mul; rough = max(rough, 0.6); cc *= 0.3;   // ceiling: flat paint
	}
	vec3 col = base * mix(vec3(1.0), ratio, detail_amt);

	// hand-height paint chips (only where the keeper's hands and elbows go)
	if (chips > 0.0 && wall) {
		float band = smoothstep(chip_lo - 0.1, chip_lo, h) * (1.0 - smoothstep(chip_hi, chip_hi + 0.15, h));
		float nse = vnoise(w_pos * 26.0) * 0.6 + vnoise(w_pos * 61.0) * 0.4;
		float m = smoothstep(0.78, 0.8, nse * (0.65 + 0.35 * vnoise(w_pos * 3.0))) * band * chips;
		col = mix(col, under_color * mix(1.0, l_scan / l_avg, 0.5), m);
		rough = mix(rough, 0.75, m);
		cc *= 1.0 - m;
	}

	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = metallic_v * arm.b;
	AO = mix(1.0, arm.r, ao_strength);
	AO_LIGHT_AFFECT = 0.0;
	CLEARCOAT = cc;
	CLEARCOAT_ROUGHNESS = coat_rough;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}

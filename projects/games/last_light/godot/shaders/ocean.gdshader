shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// Storm ocean: 6 Gerstner waves (amplitude follows the storm) + two scrolling detail normal maps,
// crest foam from wave steepness, shore/reef foam from a distance-field texture built from layout.json.
// OceanWaves.height_at() on the CPU uses the same wave set so ships ride the same surface.

uniform float storm = 0.5;
uniform float time_s = 0.0;
uniform vec4 waves[6];          // dir.x, dir.y, steepness, wavelength
uniform vec3 deep_color : source_color = vec3(0.012, 0.03, 0.045);
uniform vec3 shallow_color : source_color = vec3(0.03, 0.075, 0.085);
uniform vec3 foam_color : source_color = vec3(0.62, 0.66, 0.68);
uniform sampler2D detail_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D shore_field : filter_linear;     // R = foam proximity (1 at rocks), mapped over field_rect
uniform vec4 field_rect = vec4(-260.0, -260.0, 520.0, 520.0);
uniform float flash = 0.0;

varying vec3 w_pos;
varying float crest;

vec3 gerstner(vec4 w, vec3 p, float amp_mul, inout vec3 tangent, inout vec3 binormal) {
	float steep = w.z * amp_mul;
	float k = 6.2831853 / w.w;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(w.xy);
	float f = k * (dot(d, p.xz) - c * time_s);
	float a = steep / k;
	tangent += vec3(-d.x * d.x * steep * sin(f), d.x * steep * cos(f), -d.x * d.y * steep * sin(f));
	binormal += vec3(-d.x * d.y * steep * sin(f), d.y * steep * cos(f), -d.y * d.y * steep * sin(f));
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	float amp = mix(0.35, 1.0, storm);
	vec3 disp = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		disp += gerstner(waves[i], p, amp, tangent, binormal);
	}
	// calm the water inside the lagoon / near the island so it doesn't swallow the shore
	float r = length(p.xz);
	float calm = smoothstep(15.0, 45.0, r);
	disp *= mix(0.35, 1.0, calm);
	VERTEX += disp;
	w_pos = p + disp;
	NORMAL = normalize(cross(binormal, tangent));
	crest = clamp(disp.y / (1.2 * amp + 0.01), 0.0, 1.0);
}

void fragment() {
	vec2 uv = w_pos.xz;
	vec3 na = texture(detail_a, uv * 0.045 + vec2(time_s * 0.012, time_s * 0.007)).xyz * 2.0 - 1.0;
	vec3 nb = texture(detail_b, uv * 0.11 - vec2(time_s * 0.02, -time_s * 0.015)).xyz * 2.0 - 1.0;
	vec3 dn = normalize(vec3((na.xy + nb.xy) * (0.35 + 0.45 * storm), 1.0));
	NORMAL_MAP = dn * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	vec2 fuv = (w_pos.xz - field_rect.xy) / field_rect.zw;
	float shore = texture(shore_field, fuv).r;
	float n1 = texture(foam_noise, uv * 0.06 + vec2(time_s * 0.03, 0.0)).r;
	float n2 = texture(foam_noise, uv * 0.17 - vec2(0.0, time_s * 0.05)).r;
	float crest_foam = smoothstep(0.55 - 0.25 * storm, 0.95, crest + (n1 - 0.5) * 0.5) * (0.35 + 0.65 * storm);
	float surf = smoothstep(0.25, 0.9, shore * (0.7 + 0.6 * n2) + 0.15 * sin(time_s * 1.3 + shore * 9.0));
	float foam = clamp(max(crest_foam * n2 * 1.6, surf), 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 water = mix(deep_color, shallow_color, crest * 0.6 + shore * 0.4);
	ALBEDO = mix(water, foam_color, foam);
	ROUGHNESS = mix(0.06 + 0.1 * storm, 0.85, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	EMISSION = vec3(0.08, 0.1, 0.14) * fres * (0.25 + 3.0 * flash) * (1.0 - foam);
}

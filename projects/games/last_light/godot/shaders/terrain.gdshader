shader_type spatial;
// Island terrain: wet dark rock on cliffs and the shore, sparse grass on the gentle top, a gravel path
// band. World-space triplanar so the procedural mesh needs no UVs.

uniform sampler2D rock_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shore_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wet = 0.6;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri(sampler2D t, vec3 p, vec3 bw, float s) {
	return texture(t, p.zy * s).rgb * bw.x + texture(t, p.xz * s).rgb * bw.y + texture(t, p.xy * s).rgb * bw.z;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	vec3 rock = tri(rock_a, w_pos, bw, 0.16);
	float lr = dot(rock, vec3(0.3, 0.59, 0.11));
	rock = mix(rock, vec3(lr), 0.88) * vec3(0.36, 0.36, 0.37) * 1.35;
	vec3 grass = tri(grass_a, w_pos, bw, 0.22) * vec3(0.55, 0.6, 0.45);
	vec3 shore = tri(shore_a, w_pos, bw, 0.18);
	shore = mix(shore, vec3(dot(shore, vec3(0.33))), 0.6) * 0.5;
	float g = smoothstep(0.72, 0.9, n.y) * smoothstep(2.2, 3.6, w_pos.y);
	float s = smoothstep(2.4, 0.4, w_pos.y);
	vec3 col = mix(rock, grass, g);
	col = mix(col, shore, s * (1.0 - g));
	float wetness = clamp(wet * (0.55 + s), 0.0, 1.0);
	ALBEDO = col * (1.0 - 0.4 * wetness);
	ROUGHNESS = mix(0.9, 0.25, wetness * (1.0 - g));
	vec3 tn = tri(rock_n, w_pos, bw, 0.16) * 2.0 - 1.0;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tn.x, 0.0, tn.y, 0.0)).xyz * 0.5 * (1.0 - g));
}

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Lighthouse beam shaft: soft edges (fresnel), fades along its length, broken up by moving rain/fog
// noise. Complements the SpotLight3D's real volumetric scattering.

uniform vec3 color : source_color = vec3(1.0, 0.76, 0.45);
uniform float intensity = 1.0;
uniform float length_m = 180.0;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float time_s = 0.0;

varying vec3 l_pos;

void vertex() {
	l_pos = VERTEX;
}

void fragment() {
	float along = clamp((l_pos.y + length_m * 0.5) / length_m, 0.0, 1.0);   // cylinder Y axis
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float fade = (1.0 - along) * smoothstep(0.0, 0.03, along);
	float n = texture(noise, vec2(l_pos.y * 0.02 - time_s * 0.15, atan(l_pos.x, l_pos.z) * 0.3)).r;
	float a = edge * fade * (0.55 + 0.6 * n) * intensity;
	ALBEDO = color * a;
	ALPHA = 1.0;
}

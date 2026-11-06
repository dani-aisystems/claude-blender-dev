shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
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
	// The cylinder's +Y end (narrow, r 0.6 m) sits at the lantern, so d = 0 at the lantern and 1 at the far rim.
	float d = 1.0 - clamp((l_pos.y + length_m * 0.5) / length_m, 0.0, 1.0);
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.4);    // softer silhouette (G1 capture: hard wedge at 1.6)
	// Bright at the lantern, decaying into the dark and reaching exactly 0 well before the open rim,
	// so the shaft never ends in a visible disc (the old fade was inverted: it peaked at the rim).
	// 0.5 x and faster decay: the first G1 capture read as a solid bright wedge, far stronger than the
	// original's subtle shaft (the SpotLight's own volumetric scatter carries most of the beam)
	float fade = 0.5 * smoothstep(0.0, 0.025, d) * exp(-3.2 * d) * (1.0 - smoothstep(0.35, 0.85, d));
	float n = texture(noise, vec2(l_pos.y * 0.02 - time_s * 0.15, atan(l_pos.x, l_pos.z) * 0.3)).r;
	float a = edge * fade * (0.55 + 0.6 * n) * intensity;
	ALBEDO = color * a;
	ALPHA = 1.0;
}

shader_type sky;
// Night storm sky: layered scrolling cloud noise, darker overhead, a faint horizon glow,
// lightning flashes lighting the cloud bellies, and a dawn blend for the ending.

uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;
uniform float storm = 0.5;
uniform float flash = 0.0;
uniform float dawn = 0.0;
uniform float time_s = 0.0;
uniform vec2 flash_dir = vec2(0.0, -1.0);

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, -0.2, 1.0);
	vec3 night_top = vec3(0.012, 0.016, 0.024);
	vec3 night_hor = vec3(0.05, 0.062, 0.078);
	vec3 dawn_top = vec3(0.16, 0.18, 0.22);
	vec3 dawn_hor = vec3(0.62, 0.5, 0.44);
	vec3 col = mix(mix(night_hor, night_top, smoothstep(0.0, 0.5, h)), mix(dawn_hor, dawn_top, smoothstep(0.0, 0.6, h)), dawn);
	vec2 uv = d.xz / max(d.y + 0.12, 0.05);
	float c1 = texture(clouds, uv * 0.05 + vec2(time_s * 0.004, time_s * 0.0015)).r;
	float c2 = texture(clouds, uv * 0.13 - vec2(time_s * 0.009, 0.0)).r;
	float cover = smoothstep(0.35 - 0.25 * storm, 0.85, c1 * 0.7 + c2 * 0.45);
	vec3 cloud_col = mix(vec3(0.03, 0.035, 0.045), vec3(0.4, 0.38, 0.38), dawn);
	float belly = c2 * cover;
	col = mix(col, cloud_col * (0.6 + 0.6 * c2), cover * smoothstep(-0.05, 0.15, h));
	// lightning: bright from the flash direction, through the cloud bellies
	float fd = pow(max(dot(normalize(d.xz + 0.0001), normalize(flash_dir)), 0.0), 3.0);
	col += vec3(0.55, 0.6, 0.75) * flash * (0.25 + 1.6 * belly * fd) * smoothstep(-0.05, 0.2, h);
	if (d.y < 0.0) {
		col = mix(col, vec3(0.02, 0.03, 0.04), clamp(-d.y * 6.0, 0.0, 1.0));
	}
	COLOR = col;
}

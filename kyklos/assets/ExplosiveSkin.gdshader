shader_type spatial;

render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 glass_color : source_color = vec4(0.45, 0.10, 0.75, 0.38);
uniform vec4 core_color : source_color = vec4(1.0, 0.35, 1.0, 1.0);
uniform vec4 plasma_color : source_color = vec4(0.95, 0.35, 1.0, 1.0);
uniform vec4 hotspot_color : source_color = vec4(1.0, 0.9, 1.0, 1.0);

uniform float sphere_radius = 0.5;

uniform float core_radius = 0.22;
uniform float core_softness = 0.12;

uniform int tendril_count = 14;
uniform float tendril_width = 0.10;
uniform float tendril_softness = 0.10;
uniform float tendril_speed = 2.2;
uniform float tendril_wobble = 1.8;
uniform float tendril_brightness = 8.0;

uniform float shell_fresnel_strength = 3.5;
uniform float shell_glow_strength = 3.0;
uniform float alpha_strength = 0.55;

uniform float noise_scale = 10.0;
uniform float noise_strength = 0.12;

varying vec3 local_pos;
varying vec3 local_normal;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453123);
}

float hash31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

mat2 rot(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat2(
		vec2(c, -s),
		vec2(s, c)
	);
}

float sphere_mask(float dist_val, float radius_val, float softness_val) {
	return 1.0 - smoothstep(radius_val, radius_val + softness_val, dist_val);
}

float line_to_segment(vec3 p, vec3 a, vec3 b) {
	vec3 pa = p - a;
	vec3 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(local_normal);
	vec3 view_dir = normalize(VIEW);

	float fresnel = pow(1.0 - max(dot(n, view_dir), 0.0), 2.4);

	float core_dist = length(local_pos);
	float core_mask_val = sphere_mask(core_dist, core_radius, core_softness);

	float tendril_accum = 0.0;
	float hotspot_accum = 0.0;

	for (int i = 0; i < 24; i++) {
		if (i >= tendril_count) {
			break;
		}

		float fi = float(i);
		float seed = fi * 17.913;
		float t = TIME * tendril_speed;

		float a1 = hash11(seed + 1.7) * 6.28318 + t * (0.6 + hash11(seed + 4.9) * 1.0);
		float a2 = hash11(seed + 8.1) * 6.28318 + t * (0.5 + hash11(seed + 2.3) * 0.9);

		vec3 dir = normalize(vec3(
			cos(a1) * sin(a2),
			sin(a1) * sin(a2),
			cos(a2)
		));

		vec3 end_point = dir * (sphere_radius * 0.93);

		float wobble_phase = TIME * (1.2 + hash11(seed + 6.2)) + fi * 0.7;
		end_point.xz = rot(sin(wobble_phase) * tendril_wobble * 0.16) * end_point.xz;
		end_point.y += sin(wobble_phase * 1.35) * 0.07;

		vec3 start_point = normalize(end_point) * core_radius * 0.7;

		vec3 sample_pos = local_pos;
		float n1 = hash31(floor(sample_pos * noise_scale + vec3(TIME * 2.0)));
		float n2 = hash31(floor(sample_pos.yzx * noise_scale + vec3(TIME * 1.6)));
		sample_pos += normalize(sample_pos + vec3(0.001)) * ((n1 + n2 - 1.0) * noise_strength);

		float d = line_to_segment(sample_pos, start_point, end_point);
		float tendril = 1.0 - smoothstep(tendril_width, tendril_width + tendril_softness, d);

		float pulse = 0.75 + 0.25 * sin(TIME * 5.2 + fi * 1.4);
		tendril *= pulse;

		tendril_accum += tendril;

		float tip_d = distance(local_pos, end_point);
		float tip = 1.0 - smoothstep(0.0, 0.16, tip_d);
		hotspot_accum += tip * (0.8 + 0.2 * pulse);
	}

	tendril_accum = clamp(tendril_accum, 0.0, 1.0);
	hotspot_accum = clamp(hotspot_accum, 0.0, 1.0);

	float shell_mask = smoothstep(0.62, 1.0, length(local_pos) / max(sphere_radius, 0.0001));
	float shell_glow = fresnel * shell_fresnel_strength + shell_mask * shell_glow_strength * 0.55;

	vec3 albedo = glass_color.rgb;
	albedo = mix(albedo, core_color.rgb, core_mask_val * 0.75);
	albedo = mix(albedo, plasma_color.rgb, tendril_accum * 0.45);

	vec3 emission = vec3(0.0);
	emission += core_color.rgb * core_mask_val * 9.0;
	emission += plasma_color.rgb * tendril_accum * tendril_brightness;
	emission += hotspot_color.rgb * hotspot_accum * 7.5;
	emission += glass_color.rgb * shell_glow * 1.2;

	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.9;

	float alpha_val = glass_color.a;
	alpha_val += core_mask_val * 0.30;
	alpha_val += tendril_accum * 0.22;
	alpha_val += fresnel * alpha_strength;
	alpha_val += shell_mask * 0.12;

	ALPHA = clamp(alpha_val, 0.25, 0.92);
}
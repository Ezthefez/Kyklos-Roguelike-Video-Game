shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 color_a : source_color = vec4(0.18, 0.28, 0.75, 1.0);
uniform vec4 color_b : source_color = vec4(0.70, 0.28, 0.85, 1.0);
uniform vec4 color_c : source_color = vec4(1.00, 0.82, 0.62, 1.0);

uniform float brightness : hint_range(0.0, 20.0) = 6.0;
uniform float band_width : hint_range(0.01, 1.0) = 0.30;
uniform float band_softness : hint_range(0.1, 8.0) = 1.7;

uniform float dust_strength : hint_range(0.0, 4.0) = 1.5;
uniform float broad_scale : hint_range(0.1, 20.0) = 3.0;
uniform float detail_scale : hint_range(0.1, 80.0) = 16.0;
uniform float fine_scale : hint_range(0.1, 120.0) = 34.0;

uniform float core_strength : hint_range(0.0, 10.0) = 3.5;
uniform float haze_strength : hint_range(0.0, 5.0) = 0.45;

uniform vec3 band_normal = vec3(0.0, 1.0, 0.0);
uniform vec3 core_direction = vec3(0.8, 0.0, -0.6);

varying vec3 local_dir;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);

	float n000 = hash(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);

	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);

	return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise3(p) * a;
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

float ridged_fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		float n = noise3(p);
		n = 1.0 - abs(n * 2.0 - 1.0);
		v += n * a;
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	local_dir = normalize(VERTEX);
}

void fragment() {
	vec3 dir = normalize(local_dir);
	vec3 n = normalize(band_normal);
	vec3 core_dir = normalize(core_direction);

	vec3 tangent_a = normalize(abs(n.y) < 0.99 ? cross(n, vec3(0.0, 1.0, 0.0)) : cross(n, vec3(1.0, 0.0, 0.0)));
	vec3 tangent_b = normalize(cross(n, tangent_a));

	float plane_dist = dot(dir, n);
	float band_mask = 1.0 - smoothstep(band_width, band_width + 0.15, abs(plane_dist));
	band_mask = pow(max(band_mask, 0.0), band_softness);

	vec2 gal_uv = vec2(dot(dir, tangent_a), dot(dir, tangent_b));

	float broad = fbm(vec3(gal_uv * broad_scale, 1.3));
	float detail = fbm(vec3(gal_uv * detail_scale, 4.7));
	float fine = fbm(vec3(gal_uv * fine_scale, 9.2));
	float dust = ridged_fbm(vec3(gal_uv * 8.0, 2.6));

	float cloud_shape = broad * 0.55 + detail * 0.30 + fine * 0.15;
	float dust_lanes = 1.0 - clamp(dust * dust_strength, 0.0, 0.92);

	float core = pow(max(dot(dir, core_dir), 0.0), 10.0) * core_strength;
	float haze = broad * haze_strength;

	float color_mix_a = clamp(cloud_shape * 1.2, 0.0, 1.0);
	float color_mix_b = clamp(core + detail * 0.45, 0.0, 1.0);

	vec3 col = mix(color_a.rgb, color_b.rgb, color_mix_a);
	col = mix(col, color_c.rgb, color_mix_b);

	float intensity = band_mask * cloud_shape * dust_lanes;
	intensity += core;
	intensity += haze * band_mask * 0.35;
	intensity *= brightness;

	ALBEDO = vec3(0.0);
	EMISSION = col * intensity;
	ALPHA = clamp(intensity * 0.9, 0.0, 1.0);
}
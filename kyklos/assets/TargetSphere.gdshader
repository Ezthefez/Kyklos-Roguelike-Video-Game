shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.03, 0.04, 0.07, 1.0);

uniform vec4 blue_color : source_color = vec4(0.18, 0.65, 1.0, 1.0);
uniform vec4 orange_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);

uniform int blue_line_count = 10;
uniform int orange_line_count = 10;

uniform float blue_line_width = 0.18;
uniform float orange_line_width = 0.18;
uniform float line_softness = 0.025;

uniform float pulse_speed = 2.0;
uniform float hot_emission = 4.5;
uniform float cool_emission = 0.4;

uniform float object_half_size = 0.5;

/* Half of previous 0.16 radius */
uniform float blue_cap_radius = 0.08;
uniform float orange_cap_radius = 0.08;
uniform float cap_softness = 0.02;

uniform float metallic_amount = 0.05;
uniform float roughness_amount = 0.35;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float get_line_mask(float coord_01, float count, float width, float softness) {
	float cell = fract(coord_01 * count);
	float dist_to_center = abs(cell - 0.5);
	float half_width = width * 0.5;
	return 1.0 - smoothstep(half_width, half_width + softness, dist_to_center);
}

float circle_mask(vec2 uv, vec2 center, float radius, float softness) {
	float d = distance(uv, center);
	return 1.0 - smoothstep(radius, radius + softness, d);
}

void fragment() {
	float x01 = (local_pos.x / max(object_half_size, 0.0001) + 1.0) * 0.5;
	float y01 = (local_pos.y / max(object_half_size, 0.0001) + 1.0) * 0.5;
	float z01 = (local_pos.z / max(object_half_size, 0.0001) + 1.0) * 0.5;

	x01 = clamp(x01, 0.0, 0.9999);
	y01 = clamp(y01, 0.0, 0.9999);
	z01 = clamp(z01, 0.0, 0.9999);

	// Blue horizontal lines
	float blue_lines = get_line_mask(y01, float(blue_line_count), blue_line_width, line_softness);

	// Orange vertical lines
	float orange_lines = get_line_mask(x01, float(orange_line_count), orange_line_width, line_softness);

	// Blue circles only at top and bottom
	// Uses XZ plane, gated by Y
	vec2 top_bottom_uv = vec2(x01, z01);
	float blue_top_circle = circle_mask(top_bottom_uv, vec2(0.5, 0.5), blue_cap_radius, cap_softness) * smoothstep(0.72, 0.95, y01);
	float blue_bottom_circle = circle_mask(top_bottom_uv, vec2(0.5, 0.5), blue_cap_radius, cap_softness) * (1.0 - smoothstep(0.05, 0.28, y01));
	float blue_caps = max(blue_top_circle, blue_bottom_circle);

	// Orange circles only at extreme left and right
	// Uses YZ plane, gated by X
	vec2 left_right_uv = vec2(y01, z01);
	float orange_left_circle = circle_mask(left_right_uv, vec2(0.5, 0.5), orange_cap_radius, cap_softness) * (1.0 - smoothstep(0.05, 0.28, x01));
	float orange_right_circle = circle_mask(left_right_uv, vec2(0.5, 0.5), orange_cap_radius, cap_softness) * smoothstep(0.72, 0.95, x01);
	float orange_caps = max(orange_left_circle, orange_right_circle);

	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);

	float blue_energy = mix(cool_emission, hot_emission, pulse);
	float orange_energy = mix(hot_emission, cool_emission, pulse);

	float blue_mask = max(blue_lines, blue_caps);
	float orange_mask = max(orange_lines, orange_caps);

	vec3 albedo = base_color.rgb;
	albedo = mix(albedo, blue_color.rgb, blue_mask);
	albedo = mix(albedo, orange_color.rgb, orange_mask);

	vec3 emission = vec3(0.0);
	emission += blue_color.rgb * blue_mask * blue_energy;
	emission += orange_color.rgb * orange_mask * orange_energy;

	ALBEDO = albedo;
	EMISSION = emission;

	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
}
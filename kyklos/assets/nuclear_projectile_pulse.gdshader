shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_white : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform vec4 edge_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 radioactive_green : source_color = vec4(0.45, 1.0, 0.22, 1.0);

uniform float roughness_amount = 0.12;
uniform float metallic_amount = 0.0;

uniform float base_glow_strength = 0.75;
uniform float fresnel_strength = 1.2;
uniform float fresnel_power = 3.4;

uniform float pulse_interval = 1.0;
uniform float pulse_duration = 0.2;
uniform float green_pulse_strength = 2.4;
uniform float green_pulse_edge_strength = 1.35;

void fragment() {
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), fresnel_power);

	vec3 sphere_color = mix(base_white.rgb, edge_white.rgb, fresnel * 0.85);

	float cycle_time = mod(TIME, pulse_interval);
	float pulse_mask = 1.0 - step(pulse_duration, cycle_time);

	float pulse_t = clamp(cycle_time / max(pulse_duration, 0.0001), 0.0, 1.0);
	float pulse_shape = sin(pulse_t * 3.14159265);
	pulse_shape *= pulse_mask;

	vec3 green_glow = radioactive_green.rgb * pulse_shape * green_pulse_strength;
	vec3 green_edge = radioactive_green.rgb * fresnel * pulse_shape * green_pulse_edge_strength;

	ALBEDO = sphere_color;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	SPECULAR = 0.8;

	EMISSION = sphere_color * base_glow_strength + edge_white.rgb * fresnel * fresnel_strength + green_glow + green_edge;
	ALPHA = 1.0;
}

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_water_color : source_color = vec4(0.02, 0.20, 0.85, 1.0);
uniform vec4 shallow_water_color : source_color = vec4(0.12, 0.55, 1.00, 1.0);
uniform vec4 wave_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float metallic_amount = 0.0;
uniform float roughness_amount = 0.18;

uniform float wave_scale = 12.0;
uniform float wave_speed = 1.8;
uniform float wave_strength = 0.22;
uniform float foam_threshold = 0.72;
uniform float foam_softness = 0.08;

uniform float glow_strength = 0.55;
uniform float fresnel_strength = 0.65;
uniform float fresnel_power = 3.2;

void fragment() {
	vec2 uv = UV * wave_scale;

	float t = TIME * wave_speed;

	float wave_a = sin(uv.x + t);
	float wave_b = sin(uv.y * 1.35 - t * 1.15);
	float wave_c = sin((uv.x + uv.y) * 0.85 + t * 0.75);
	float wave_d = sin(length(uv - vec2(6.0, 6.0)) * 1.3 - t * 1.4);

	float wave_mix = (wave_a + wave_b + wave_c + wave_d) * 0.25;
	wave_mix = wave_mix * 0.5 + 0.5;

	vec3 water_col = mix(deep_water_color.rgb, shallow_water_color.rgb, wave_mix);

	float foam_mask = smoothstep(
		foam_threshold - foam_softness,
		foam_threshold + foam_softness,
		wave_mix + wave_strength * sin((uv.x * 0.7 - uv.y * 0.9) + t * 1.2)
	);

	vec3 final_color = mix(water_col, wave_color.rgb, foam_mask * 0.95);

	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), fresnel_power);

	ALBEDO = final_color;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	SPECULAR = 0.7;

	EMISSION = final_color * glow_strength + shallow_water_color.rgb * fresnel * fresnel_strength;
	ALPHA = 1.0;
}

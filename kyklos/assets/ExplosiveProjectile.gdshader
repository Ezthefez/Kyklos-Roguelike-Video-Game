shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 energy_color : source_color = vec4(1.0, 0.08, 0.72, 0.38);
uniform vec4 edge_color : source_color = vec4(1.0, 0.72, 0.92, 0.95);
uniform float edge_power = 3.0;
uniform float pulse_speed = 4.0;
uniform float pulse_strength = 0.15;

void fragment() {
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), edge_power);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;

	vec3 final_color = mix(energy_color.rgb, edge_color.rgb, fresnel);
	float final_alpha = mix(energy_color.a, edge_color.a, fresnel) * pulse;

	ALBEDO = final_color;
	EMISSION = final_color * 2.4;
	ALPHA = final_alpha;
}

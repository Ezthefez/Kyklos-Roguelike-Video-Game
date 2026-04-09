shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_never, fog_disabled;

uniform vec4 line_color : source_color = vec4(0.55, 0.85, 1.0, 0.85);
uniform vec4 fill_color : source_color = vec4(0.10, 0.20, 0.35, 0.06);

uniform float meridians : hint_range(4.0, 64.0, 1.0) = 16.0;
uniform float parallels : hint_range(2.0, 32.0, 1.0) = 10.0;
uniform float line_width : hint_range(0.001, 0.08, 0.001) = 0.015;
uniform float pulse_speed : hint_range(0.0, 6.0, 0.01) = 1.2;
uniform float pulse_amount : hint_range(0.0, 1.0, 0.01) = 0.10;

float line_mask(float v, float count, float width) {
	float x = fract(v * count);
	float d = min(x, 1.0 - x);
	return 1.0 - smoothstep(width, width * 1.6, d);
}

void fragment() {
	float meridian_line = line_mask(UV.x, meridians, line_width);
	float parallel_line = line_mask(UV.y, parallels, line_width);

	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	float lines = clamp(max(meridian_line, parallel_line) * pulse, 0.0, 1.0);

	vec3 color = mix(fill_color.rgb, line_color.rgb, lines);
	float alpha = mix(fill_color.a, line_color.a, lines);

	ALBEDO = color;
	ALPHA = alpha;
}

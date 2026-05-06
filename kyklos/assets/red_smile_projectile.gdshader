shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_red : source_color = vec4(0.55, 0.03, 0.03, 1.0);
uniform vec4 bright_red : source_color = vec4(1.00, 0.18, 0.14, 1.0);
uniform vec4 dark_red : source_color = vec4(0.14, 0.00, 0.00, 1.0);
uniform vec4 rim_color : source_color = vec4(1.00, 0.25, 0.20, 1.0);

uniform float slime_speed : hint_range(0.0, 5.0) = 1.3;
uniform float line_scale : hint_range(1.0, 40.0) = 18.0;
uniform float blob_scale : hint_range(1.0, 20.0) = 7.0;
uniform float wobble_strength : hint_range(0.0, 0.3) = 0.08;
uniform float glow_strength : hint_range(0.0, 5.0) = 1.4;
uniform float alpha_strength : hint_range(0.0, 1.0) = 0.82;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.24;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) +
		(c - a) * u.y * (1.0 - u.x) +
		(d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;

	for (int i = 0; i < 5; i++) {
		value += noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}

	return value;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * slime_speed;

	vec2 flow = vec2(
		fbm(uv * blob_scale + vec2(0.0, t * 0.80)),
		fbm(uv * blob_scale + vec2(4.3, -t * 0.65))
	);

	vec2 moved_uv = uv + (flow - 0.5) * wobble_strength;

	float vertical_lines = sin((moved_uv.y + t * 0.22 + fbm(moved_uv * 3.0) * 0.15) * line_scale);
	float diagonal_lines = sin((moved_uv.x * 0.75 + moved_uv.y * 1.25 - t * 0.35) * line_scale * 0.60);

	float veins = smoothstep(0.35, 0.90, vertical_lines * 0.5 + 0.5);
	veins += smoothstep(0.55, 0.95, diagonal_lines * 0.5 + 0.5) * 0.45;
	veins = clamp(veins, 0.0, 1.0);

	float blobs = fbm(moved_uv * blob_scale + vec2(t * 0.30, -t * 0.25));
	float cells = smoothstep(0.35, 0.75, blobs);

	float slime_mask = clamp(cells * 0.80 + veins * 0.70, 0.0, 1.0);

	vec3 color = mix(dark_red.rgb, base_red.rgb, cells);
	color = mix(color, bright_red.rgb, veins * 0.75);

	float fresnel = pow(1.0 - max(dot(normalize(VIEW), normalize(NORMAL)), 0.0), 2.5);
	color += rim_color.rgb * fresnel * 0.45;

	ALBEDO = color;
	ROUGHNESS = roughness_amount;
	METALLIC = metallic_amount;
	EMISSION = color * (slime_mask * 0.35 + fresnel * 0.50) * glow_strength;
	ALPHA = alpha_strength;
}

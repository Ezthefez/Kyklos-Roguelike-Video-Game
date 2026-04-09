shader_type canvas_item;

// Grab the screen behind the UI
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Blur strength
uniform float blur_amount : hint_range(0.0, 20.0) = 8.0;

// Grey tint color (RGB = grey, A = strength)
uniform vec4 tint_color : source_color = vec4(0.6, 0.6, 0.6, 0.25);

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 col = vec4(0.0);

    float offset = blur_amount / 1000.0;

    // 9-sample blur (nice and smooth)
    col += texture(screen_texture, uv + vec2(-offset, -offset));
    col += texture(screen_texture, uv + vec2( 0.0,    -offset));
    col += texture(screen_texture, uv + vec2( offset, -offset));
    col += texture(screen_texture, uv + vec2(-offset,  0.0));
    col += texture(screen_texture, uv);
    col += texture(screen_texture, uv + vec2( offset,  0.0));
    col += texture(screen_texture, uv + vec2(-offset,  offset));
    col += texture(screen_texture, uv + vec2( 0.0,     offset));
    col += texture(screen_texture, uv + vec2( offset,  offset));

    col /= 9.0;

    // Apply grey tint
    col.rgb = mix(col.rgb, tint_color.rgb, tint_color.a);

    COLOR = col;
}
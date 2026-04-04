shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.1;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec4 color = vec4(0.0);

	// 9-tap gaussian blur
	float offsets[3] = {0.0, 1.3846153846, 3.2307692308};
	float weights[3] = {0.2270270270, 0.3162162162, 0.0702702703};

	for (int i = 0; i < 3; i++) {
		float w = weights[i];
		float o = offsets[i] * blur_amount;
		color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(o, 0.0) * ps) * w;
		color += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(o, 0.0) * ps) * w;
		color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, o) * ps) * w;
		color += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, o) * ps) * w;
	}
	color /= 4.0;

	color = mix(color, tint_color, tint_strength);
	color.a = tint_color.a;

	COLOR = color;
}

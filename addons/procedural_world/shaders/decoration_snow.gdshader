shader_type spatial;
render_mode cull_back;

// Base albedo color
uniform vec4 base_color : source_color = vec4(0.2, 0.5, 0.15, 1.0);

// Snow settings
uniform float snow_height : hint_range(0.0, 200.0) = 40.0;
uniform float snow_blend : hint_range(1.0, 50.0) = 15.0;
uniform vec4 snow_color : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform float snow_intensity : hint_range(0.0, 1.0) = 0.85;

// Material properties
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying float world_y;

void vertex() {
	// Get world position for snow calculation
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	// Calculate snow blend factor based on world height
	float snow_factor = smoothstep(snow_height - snow_blend, snow_height + snow_blend, world_y);
	snow_factor *= snow_intensity;
	
	// Blend base color with snow
	vec3 final_color = mix(base_color.rgb, snow_color.rgb, snow_factor);
	
	ALBEDO = final_color;
	ROUGHNESS = mix(roughness, 0.7, snow_factor); // Snow is slightly smoother
	METALLIC = metallic;
}

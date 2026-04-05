shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.28, 0.62, 0.72, 0.78);
uniform vec4 deep_color : source_color = vec4(0.03, 0.11, 0.2, 0.9);
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.07;
uniform float wave_speed : hint_range(0.0, 4.0, 0.01) = 0.55;
uniform float wave_height : hint_range(0.0, 0.5, 0.001) = 0.07;

void vertex() {
	VERTEX.x += sin(TIME * wave_speed + VERTEX.z * 0.32) * wave_height;
	VERTEX.z += cos(TIME * wave_speed * 0.85 + VERTEX.x * 0.36) * wave_height;
}

void fragment() {
	vec2 uv = UV * 14.0;
	float w = sin(uv.x + TIME * 0.45) * sin(uv.y - TIME * 0.38) * 0.5 + 0.5;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, w * 0.65 + 0.2);
	ALBEDO = col;
	ALPHA = mix(deep_color.a, shallow_color.a, 0.5);
	METALLIC = 0.0;
	ROUGHNESS = roughness;
	SPECULAR = 0.6;
}

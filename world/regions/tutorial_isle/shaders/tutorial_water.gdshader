shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform float water_level : hint_range(-256.0, 256.0, 0.01) = 1.0;
uniform float depth_fade_distance : hint_range(0.1, 128.0, 0.1) = 18.0;
uniform float depth_deep_boost : hint_range(0.0, 2.0, 0.01) = 0.35;
uniform float sky_depth_threshold : hint_range(0.9, 1.0, 0.0001) = 0.9992;

uniform vec4 shallow_color : source_color = vec4(0.28, 0.62, 0.72, 0.78);
uniform vec4 deep_color : source_color = vec4(0.03, 0.11, 0.2, 0.9);

uniform vec4 foam_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);
uniform float foam_max_underwater : hint_range(0.05, 32.0, 0.05) = 2.2;
uniform float foam_shore_above : hint_range(0.05, 16.0, 0.05) = 1.1;
uniform float foam_noise_scale : hint_range(0.02, 2.0, 0.01) = 0.38;
uniform float foam_noise_speed : hint_range(0.0, 3.0, 0.01) = 0.65;
uniform float foam_intensity : hint_range(0.0, 2.0, 0.01) = 0.85;

uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.07;
uniform float roughness_foam : hint_range(0.0, 1.0, 0.01) = 0.04;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform float fresnel_power : hint_range(0.5, 8.0, 0.05) = 3.2;
uniform float fresnel_intensity : hint_range(0.0, 1.0, 0.01) = 0.45;

uniform float wave_speed : hint_range(0.0, 4.0, 0.01) = 0.55;
uniform float wave_height : hint_range(0.0, 0.5, 0.001) = 0.07;
uniform float wave_steepness : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float wave_scale_2 : hint_range(0.1, 4.0, 0.01) = 1.65;
uniform float wave_scale_3 : hint_range(0.1, 4.0, 0.01) = 2.35;

uniform float ripple_scale : hint_range(1.0, 64.0, 0.5) = 22.0;
uniform float ripple_strength : hint_range(0.0, 0.35, 0.001) = 0.08;

const float TAU = 6.28318530718;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

// --- Gerstner-style wave: returns displacement (xz) and height (y); fills dydxz for normal ---
void gerstner_contrib(vec2 xz, vec2 dir, float amp, float len, float speed, float t,
		inout vec3 disp, inout vec2 dydxz) {
	vec2 d = normalize(dir);
	float k = TAU / max(len, 0.001);
	float phase = k * dot(d, xz) - speed * t * k;
	float s = sin(phase);
	float c = cos(phase);
	float q = wave_steepness / max(k * amp * 3.0, 0.0001);
	q = clamp(q, 0.0, 1.0);
	float qa = q * amp;
	disp.x += d.x * qa * c;
	disp.z += d.y * qa * c;
	disp.y += amp * s;
	float dk = k * amp * c;
	dydxz.x += d.x * dk;
	dydxz.y += d.y * dk;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float foam_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 xz = world.xz;

	float t = TIME * wave_speed;
	vec3 disp = vec3(0.0);
	vec2 dydxz = vec2(0.0);

	float a1 = wave_height;
	float a2 = wave_height * 0.55 / wave_scale_2;
	float a3 = wave_height * 0.35 / wave_scale_3;

	gerstner_contrib(xz, vec2(0.94, 0.34), a1, 14.0, 1.0, t, disp, dydxz);
	gerstner_contrib(xz, vec2(-0.71, 0.71), a2, 7.5, 1.15, t * 1.08 + 1.7, disp, dydxz);
	gerstner_contrib(xz, vec2(0.4, -0.92), a3, 4.2, 1.3, t * 0.92 + 3.1, disp, dydxz);

	vec3 wp = world + disp;
	v_world_pos = wp;

	// Upward normal from height derivatives (small-amplitude approximation)
	vec3 n = normalize(vec3(-dydxz.x, 1.0, -dydxz.y));
	v_world_normal = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);

	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

vec3 world_position_from_depth(vec2 screen_uv, float raw_depth) {
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth * 2.0 - 1.0);
	vec4 clip = vec4(ndc, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * clip;
	view.xyz /= view.w;
	vec4 w = INV_VIEW_MATRIX * vec4(view.xyz, 1.0);
	return w.xyz;
}

void fragment() {
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;

	vec3 seabed_world = world_position_from_depth(SCREEN_UV, raw_depth);
	float terrain_y = seabed_world.y;

	float water_column = water_level - terrain_y;
	float depth_u = max(0.0, water_column);

	bool is_sky = raw_depth > sky_depth_threshold;
	float depth_norm = 1.0 - exp(-depth_u / max(depth_fade_distance, 0.01));
	depth_norm = clamp(depth_norm + depth_deep_boost * depth_norm * depth_norm, 0.0, 1.0);
	if (is_sky) {
		depth_norm = 1.0;
		depth_u = depth_fade_distance * 2.0;
	}

	vec3 base_col = mix(shallow_color.rgb, deep_color.rgb, depth_norm);

	// Foam: shallow underwater + beach where terrain rises above water level
	float shallow_foam = 1.0 - smoothstep(0.0, foam_max_underwater, depth_u);
	float land_above = max(0.0, terrain_y - water_level);
	float shore_foam = 1.0 - smoothstep(0.0, foam_shore_above, land_above);
	float foam_mask = clamp(max(shallow_foam, shore_foam), 0.0, 1.0);

	vec2 fuv = v_world_pos.xz * foam_noise_scale + vec2(TIME * foam_noise_speed * 0.07, TIME * foam_noise_speed * 0.11);
	float fbreak = foam_noise(fuv) * 0.5 + foam_noise(fuv * 2.3 + TIME * 0.2) * 0.35 + 0.15;
	foam_mask *= fbreak;

	vec3 col = mix(base_col, foam_color.rgb, foam_mask * foam_intensity);

	float alpha = mix(shallow_color.a, deep_color.a, depth_norm);
	alpha = mix(alpha, min(1.0, alpha + 0.12), foam_mask * foam_intensity);

	// Small ripple detail on top of wave normals (world space)
	vec2 ruv = v_world_pos.xz * (ripple_scale * 0.05) + vec2(TIME * 0.4, TIME * 0.33);
	float rx = sin(ruv.x * 2.1 + TIME * 1.05) * ripple_strength;
	float rz = cos(ruv.y * 2.0 - TIME * 0.92) * ripple_strength;
	vec3 n_world = normalize(v_world_normal + vec3(rx, 0.0, rz));
	NORMAL = normalize(mat3(VIEW_MATRIX) * n_world);

	float ndotv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndotv, fresnel_power) * fresnel_intensity;
	vec3 horizon = mix(col, vec3(0.75, 0.88, 1.0), 0.35);
	col = mix(col, horizon, fres);

	ALBEDO = col;
	ALPHA = alpha;
	METALLIC = 0.0;
	ROUGHNESS = mix(roughness, roughness_foam, foam_mask * 0.85);
	SPECULAR = specular;
}

shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

uniform float water_level : hint_range(-256.0, 256.0, 0.01) = 1.0;
uniform float depth_fade_distance : hint_range(0.1, 128.0, 0.1) = 18.0;
uniform float depth_deep_boost : hint_range(0.0, 2.0, 0.01) = 0.35;
// Reverse-Z (Forward+): far plane / empty sky is near 0.0, not 1.0
uniform float sky_depth_far_max : hint_range(0.0, 0.05, 0.0001) = 0.0015;

uniform vec4 shallow_color : source_color = vec4(0.1, 0.45, 0.62, 0.58);
uniform vec4 deep_color : source_color = vec4(0.02, 0.09, 0.16, 0.7);
uniform float alpha_depth_boost : hint_range(0.0, 0.35, 0.01) = 0.08;

uniform vec4 foam_color : source_color = vec4(0.82, 0.9, 0.95, 1.0);
// Foam mainly within this underwater depth (world units; ~6-7 ft if 1 unit ~ 1 ft).
uniform float foam_shore_band : hint_range(0.5, 24.0, 0.1) = 7.0;
uniform float foam_shore_above : hint_range(0.05, 16.0, 0.05) = 1.1;
uniform float foam_noise_scale : hint_range(0.02, 2.0, 0.01) = 0.38;
uniform float foam_noise_speed : hint_range(0.0, 3.0, 0.01) = 0.65;
uniform float foam_inward_speed : hint_range(0.0, 2.0, 0.01) = 0.42;
uniform float foam_sharpness : hint_range(0.5, 4.0, 0.05) = 2.35;
uniform float foam_intensity : hint_range(0.0, 2.0, 0.01) = 0.38;
uniform float foam_max_blend : hint_range(0.05, 0.85, 0.01) = 0.42;
uniform float offshore_chop_tint : hint_range(0.0, 0.45, 0.01) = 0.22;
// World XZ: waves / foam drift toward land (set in water_depth_sync).
uniform vec2 toward_land_xz = vec2(0.65, 0.52);
// Approximate island center for wave size falloff (smaller swell offshore).
uniform vec2 shore_reference_xz = vec2(130.0, 115.0);
uniform float shore_wave_falloff_start : hint_range(5.0, 80.0, 0.5) = 22.0;
uniform float shore_wave_falloff_end : hint_range(20.0, 300.0, 1.0) = 140.0;
uniform float wave_far_amplitude : hint_range(0.05, 0.6, 0.01) = 0.2;
uniform float wave_direction_toward_shore : hint_range(0.0, 1.0, 0.01) = 0.62;
uniform float distance_roughness_add : hint_range(0.0, 0.45, 0.01) = 0.2;
// Near/far camera distance (world units) for extra roughness; shader uses min/max so start > end never inverts smoothstep.
uniform float distance_roughness_start : hint_range(10.0, 2000.0, 1.0) = 55.0;
uniform float distance_roughness_end : hint_range(10.0, 2000.0, 1.0) = 220.0;

uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float roughness_foam : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float specular_amount : hint_range(0.0, 1.0, 0.01) = 0.14;
uniform float fresnel_power : hint_range(0.5, 8.0, 0.05) = 3.0;
uniform float fresnel_intensity : hint_range(0.0, 1.0, 0.01) = 0.045;
uniform float horizon_sky_mix : hint_range(0.0, 0.6, 0.01) = 0.07;

uniform float wave_speed : hint_range(0.0, 4.0, 0.01) = 0.55;
uniform float wave_height : hint_range(0.0, 0.5, 0.001) = 0.07;
uniform float wave_steepness : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float wave_scale_2 : hint_range(0.1, 4.0, 0.01) = 1.65;
uniform float wave_scale_3 : hint_range(0.1, 4.0, 0.01) = 2.35;

uniform float ripple_scale : hint_range(1.0, 64.0, 0.5) = 22.0;
uniform float ripple_strength : hint_range(0.0, 0.35, 0.001) = 0.11;
// inv_view_matrix, view_matrix, inv_projection_matrix: set each frame from water_depth_sync.gd
uniform mat4 inv_view_matrix;
uniform mat4 view_matrix;
uniform mat4 inv_projection_matrix;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

// --- Gerstner-style wave: returns displacement (xz) and height (y); fills dydxz for normal ---
void gerstner_contrib(vec2 xz, vec2 dir, float amp, float len, float speed, float t,
		inout vec3 disp, inout vec2 dydxz) {
	vec2 d = normalize(dir);
	float k = TAU / max(len, 0.001); // built-in global TAU (do not redeclare)
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

	// Propagation toward land: negate exported vector so phase matches Gerstner travel direction
	vec2 tl = -normalize(toward_land_xz + vec2(1e-4));
	float dist_ref = length(xz - shore_reference_xz);
	float wave_amp_mul = mix(1.0, wave_far_amplitude, smoothstep(shore_wave_falloff_start, shore_wave_falloff_end, dist_ref));

	float a1 = wave_height * wave_amp_mul;
	float a2 = wave_height * 0.55 / wave_scale_2 * wave_amp_mul;
	float a3 = wave_height * 0.35 / wave_scale_3 * mix(wave_amp_mul, 1.0, 0.4);

	vec2 d1 = normalize(mix(vec2(0.94, 0.34), tl, wave_direction_toward_shore));
	vec2 d2 = normalize(mix(vec2(-0.71, 0.71), tl, wave_direction_toward_shore * 0.85));
	vec2 d3 = normalize(mix(vec2(0.4, -0.92), tl, wave_direction_toward_shore * 0.75));

	gerstner_contrib(xz, d1, a1, 14.0, 1.0, t, disp, dydxz);
	gerstner_contrib(xz, d2, a2, 7.5, 1.15, t * 1.08 + 1.7, disp, dydxz);
	gerstner_contrib(xz, d3, a3, 4.2, 1.3, t * 0.92 + 3.1, disp, dydxz);

	vec3 wp = world + disp;
	v_world_pos = wp;

	// Upward normal from height derivatives (small-amplitude approximation)
	vec3 n = normalize(vec3(-dydxz.x, 1.0, -dydxz.y));
	v_world_normal = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);

	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
}

vec3 world_position_from_depth(vec2 screen_uv, float raw_depth) {
	// NDC: Godot Forward+ uses reverse-Z (depth 0 = far/sky). Unproject to view, then to world.
	vec3 ndc;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
#else
	ndc = vec3(screen_uv.x * 2.0 - 1.0, screen_uv.y * 2.0 - 1.0, raw_depth);
#endif
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= max(view.w, 1e-7);
	vec4 world = inv_view_matrix * vec4(view.xyz, 1.0);
	return world.xyz / max(world.w, 1e-7);
}

void fragment() {
	float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;

	vec3 seabed_world = world_position_from_depth(SCREEN_UV, raw_depth);
	float terrain_y = seabed_world.y;

	float water_column = water_level - terrain_y;
	float depth_u = max(0.0, water_column);

	bool is_sky = raw_depth <= sky_depth_far_max;
	float depth_norm = 1.0 - exp(-depth_u / max(depth_fade_distance, 0.01));
	depth_norm = clamp(depth_norm + depth_deep_boost * depth_norm * depth_norm, 0.0, 1.0);
	if (is_sky) {
		depth_norm = 1.0;
		depth_u = depth_fade_distance * 2.0;
	}

	vec3 base_col = mix(shallow_color.rgb, deep_color.rgb, depth_norm);

	// Foam: tight white band at shore; offshore = separate chop tint (no white foam)
	vec2 tl = -normalize(toward_land_xz + vec2(1e-4));
	float shallow_foam = 1.0 - smoothstep(0.0, foam_shore_band, depth_u);
	float land_above = max(0.0, terrain_y - water_level);
	float shore_foam = 1.0 - smoothstep(0.0, foam_shore_above, land_above);
	float foam_raw = clamp(max(shallow_foam, shore_foam), 0.0, 1.0);
	float foam_mask = pow(foam_raw, foam_sharpness);

	vec2 fuv = v_world_pos.xz * foam_noise_scale + vec2(TIME * foam_noise_speed * 0.07, TIME * foam_noise_speed * 0.11);
	fuv += tl * TIME * foam_inward_speed;
	float fbreak = foam_noise(fuv) * 0.5 + foam_noise(fuv * 2.3 + TIME * 0.2) * 0.35 + 0.15;
	foam_mask *= fbreak;
	float foam_amt = min(foam_mask * foam_intensity, foam_max_blend);

	float offshore = smoothstep(foam_shore_band + 0.8, foam_shore_band + 12.0, depth_u);
	vec3 chop_color = base_col * vec3(0.9, 0.97, 1.06);
	vec3 col = mix(base_col, chop_color, offshore * offshore_chop_tint * (1.0 - foam_amt));
	col = mix(col, foam_color.rgb, foam_amt);

	float alpha = mix(shallow_color.a, deep_color.a, depth_norm);
	alpha = mix(alpha, min(1.0, alpha + 0.08), foam_amt);
	// Deeper water reads a bit more opaque; shallow stays see-through
	alpha = clamp(alpha + depth_norm * alpha_depth_boost, 0.0, 0.88);

	// Ripples stronger past the foam band (small surface chop offshore)
	float deep_chop = smoothstep(foam_shore_band - 0.5, foam_shore_band + 6.0, depth_u);
	vec2 ruv = v_world_pos.xz * (ripple_scale * 0.05) + vec2(TIME * 0.4, TIME * 0.33);
	ruv += tl * TIME * 0.55;
	float ripple_mul = mix(ripple_strength * 0.5, ripple_strength * 1.2, deep_chop);
	float rx = sin(ruv.x * 2.1 + TIME * 1.05 + dot(v_world_pos.xz, tl) * 0.08) * ripple_mul;
	float rz = cos(ruv.y * 2.0 - TIME * 0.92 + dot(v_world_pos.xz, tl) * 0.06) * ripple_mul;
	vec3 n_world = normalize(v_world_normal + vec3(rx, 0.0, rz));
	NORMAL = normalize((view_matrix * vec4(n_world, 0.0)).xyz);

	float ndotv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndotv, fresnel_power) * fresnel_intensity;
	vec3 horizon_tint = vec3(0.2, 0.32, 0.44);
	col = mix(col, horizon_tint, fres * horizon_sky_mix);

	ALBEDO = col;
	ALPHA = alpha;
	METALLIC = 0.0;
	float dist_cam = distance(v_world_pos, CAMERA_POSITION_WORLD);
	float d_near = min(distance_roughness_start, distance_roughness_end);
	float d_far = max(distance_roughness_start, distance_roughness_end);
	float far_detail = smoothstep(d_near, d_far, dist_cam);
	float rgh = mix(roughness, roughness_foam, foam_amt * 0.85);
	rgh = min(1.0, rgh + far_detail * distance_roughness_add);
	ROUGHNESS = rgh;
	SPECULAR = specular_amount;
}

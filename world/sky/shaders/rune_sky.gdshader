shader_type sky;

/* RuneForged — cool teal / slate day, deep indigo night; procedural clouds + stars.
 * sun_direction: world-space unit vector *toward* the sun (set by DayNightController). */

uniform vec3 sun_direction = vec3(0.2, 0.97, 0.12);
uniform vec3 moon_direction = vec3(-0.2, -0.97, -0.12);
uniform float day_factor : hint_range(0.0, 1.0, 0.001) = 0.85;
uniform float sunset_factor : hint_range(0.0, 1.0, 0.001) = 0.0;

uniform vec3 zenith_day : source_color = vec3(0.35, 0.55, 0.78);
/* Deep Norse night: cold blue-black, not flat grey */
uniform vec3 zenith_night : source_color = vec3(0.015, 0.02, 0.042);
uniform vec3 horizon_day : source_color = vec3(0.62, 0.72, 0.82);
uniform vec3 horizon_night : source_color = vec3(0.028, 0.032, 0.048);
uniform vec3 sunset_color : source_color = vec3(0.95, 0.55, 0.32);

uniform float sun_disk_size : hint_range(0.001, 0.05, 0.0001) = 0.00225;
uniform vec3 sun_disk_color : source_color = vec3(1.0, 0.97, 0.88);
uniform float sun_limb_darken : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float sun_corona_size : hint_range(0.0, 0.2, 0.0001) = 0.012;
uniform float sun_corona_intensity : hint_range(0.0, 2.0, 0.01) = 0.55;
uniform vec3 sun_corona_color : source_color = vec3(1.0, 0.92, 0.75);

uniform float moon_disk_size : hint_range(0.001, 0.06, 0.0001) = 0.006;
uniform vec3 moon_disk_color : source_color = vec3(0.82, 0.86, 0.95);
uniform float moon_phase : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float moon_phase_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float moon_detail_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float moon_rim_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float moon_rim_power : hint_range(0.5, 8.0, 0.1) = 2.4;
uniform float moon_earthshine : hint_range(0.0, 0.5, 0.005) = 0.08;
uniform vec3 moon_earthshine_color : source_color = vec3(0.22, 0.28, 0.38);

uniform float star_threshold : hint_range(0.0, 1.0, 0.01) = 0.48;
uniform float star_brightness : hint_range(0.0, 2.5, 0.01) = 1.15;
uniform vec3 star_tint : source_color = vec3(0.72, 0.8, 0.95);
uniform vec2 star_density_uv = vec2(340.0, 175.0);
uniform float star_point_size : hint_range(0.02, 0.35, 0.001) = 0.042;
uniform float star_twinkle_amount : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform float star_bright_boost : hint_range(1.0, 4.0, 0.05) = 2.6;
uniform float star_bright_threshold : hint_range(0.9, 0.999, 0.001) = 0.988;
uniform float star_dim_threshold : hint_range(0.5, 0.95, 0.001) = 0.74;
uniform float star_core_power : hint_range(0.5, 3.0, 0.05) = 1.45;
uniform float star_halo : hint_range(0.0, 0.6, 0.01) = 0.38;

uniform float cloud_coverage : hint_range(0.0, 1.0, 0.01) = 0.36;
uniform float cloud_softness : hint_range(0.01, 0.7, 0.01) = 0.36;
uniform float cloud_warp : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform vec3 cloud_color_day : source_color = vec3(0.92, 0.94, 0.98);
uniform vec3 cloud_color_sunset : source_color = vec3(0.98, 0.72, 0.55);
uniform vec3 cloud_color_night : source_color = vec3(0.05, 0.06, 0.09);
uniform float night_cloud_brightness : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float cloud_wind_speed : hint_range(0.0, 0.05, 0.0001) = 0.008;
uniform float cloud_domain : hint_range(1.0, 12.0, 0.1) = 2.8;

uniform bool milky_way_enabled = true;
uniform float milky_way_intensity : hint_range(0.0, 2.0, 0.01) = 0.12;
uniform float milky_way_width : hint_range(0.02, 1.0, 0.01) = 0.075;
uniform float milky_way_rotation : hint_range(0.0, 6.28318, 0.001) = 0.55;
uniform float milky_way_elevation : hint_range(-0.3, 0.8, 0.01) = 0.28;
uniform vec3 milky_way_tint : source_color = vec3(0.42, 0.56, 0.92);
uniform vec3 milky_way_dust_tint : source_color = vec3(0.95, 0.72, 0.52);

uniform bool aurora_enabled = true;
uniform float aurora_intensity : hint_range(0.0, 2.0, 0.01) = 0.05;
uniform float aurora_speed : hint_range(0.0, 3.0, 0.01) = 0.16;
uniform float aurora_band_height : hint_range(0.0, 1.0, 0.01) = 0.23;
uniform float aurora_band_softness : hint_range(0.01, 0.5, 0.01) = 0.06;
uniform vec3 aurora_color_a : source_color = vec3(0.08, 0.88, 0.62);
uniform vec3 aurora_color_b : source_color = vec3(0.24, 0.66, 1.0);
uniform vec3 aurora_color_c : source_color = vec3(0.66, 0.34, 0.95);
uniform float aurora_moon_exclusion : hint_range(0.0, 1.0, 0.01) = 0.72;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * noise2(p);
		p = rot * p * 2.1 + 17.0;
		a *= 0.5;
	}
	return v;
}

// Multi-scale FBM + domain warp — round, fluffy masses (no square Voronoi grid)
float cloud_fbm_soft(vec2 p) {
	vec2 warp = vec2(fbm(p * 0.55 + 3.1), fbm(p * 0.55 + 9.7)) * cloud_warp * 0.6;
	p += warp;
	float n = fbm(p * 1.05) * 0.5;
	n += fbm(p * 2.15 + vec2(13.7, 8.2)) * 0.28;
	n += fbm(p * 4.2 + vec2(-6.0, 2.5)) * 0.14;
	n += fbm(p * 8.5 + vec2(1.0, 19.0)) * 0.08;
	return clamp(n, 0.0, 1.0);
}

vec3 sky_gradient(vec3 eyedir, float day_f, float sunset_f) {
	float v = clamp(eyedir.y * 0.5 + 0.5, 0.0, 1.0);
	float vp = mix(pow(v, 1.14), pow(v, 0.9), day_f);
	vec3 zenith = mix(zenith_night, zenith_day, day_f);
	vec3 horizon = mix(horizon_night, horizon_day, day_f);
	vec3 grad = mix(horizon, zenith, vp);
	grad = mix(grad, grad * sunset_color, sunset_f * (1.0 - abs(eyedir.y) * 0.5));
	return grad;
}

float stars(vec3 eyedir, float night_amt) {
	if (night_amt < 0.005) {
		return 0.0;
	}
	vec3 p = normalize(eyedir + vec3(0.001, 0.002, 0.001));
	vec2 uv = vec2(atan(p.z, p.x) / 6.2831853 + 0.5, asin(clamp(p.y, -1.0, 1.0)) * 0.5 + 0.5);
	uv *= star_density_uv;
	vec2 id = floor(uv);
	float h = hash21(id);
	vec2 center_jitter = vec2(hash21(id + vec2(13.7, 2.9)), hash21(id + vec2(4.1, 19.3))) - 0.5;
	vec2 f = fract(uv) - (0.5 + center_jitter * 0.6);
	float tw = mix(
		1.0,
		0.86 + 0.14 * (sin(TIME * (0.8 + h * 1.8) + h * 6.28) * 0.5 + 0.5),
		star_twinkle_amount
	);
	float r = length(f);
	float core = pow(smoothstep(star_point_size, 0.0, r), star_core_power);
	float halo = smoothstep(star_point_size * 1.65, star_point_size * 0.55, r) * star_halo;
	float kernel = core + halo;
	float dim = smoothstep(star_dim_threshold, star_bright_threshold, h);
	float bright = smoothstep(star_bright_threshold, 1.0, h);
	float m = kernel * (dim * 0.48 + bright * star_bright_boost) * tw;
	float night_gate = smoothstep(star_threshold, 1.0, night_amt);
	return m * night_gate * star_brightness;
}

vec3 milky_way(vec3 eyedir, float night_amt) {
	if (!milky_way_enabled || night_amt < 0.005) {
		return vec3(0.0);
	}
	vec2 rot = vec2(cos(milky_way_rotation), sin(milky_way_rotation));
	vec3 core_dir = normalize(vec3(rot.x, milky_way_elevation, rot.y));
	vec3 world_up = vec3(0.0, 1.0, 0.0);
	vec3 plane_n = cross(world_up, core_dir);
	float pn2 = dot(plane_n, plane_n);
	if (pn2 < 1e-8) {
		plane_n = vec3(1.0, 0.0, 0.0);
	} else {
		plane_n = normalize(plane_n);
	}
	float plane_d = abs(dot(eyedir, plane_n));
	float w = max(milky_way_width, 0.02);
	float band_core = exp(-plane_d * plane_d / (w * w * 0.055));
	float band_halo = exp(-plane_d * plane_d / (w * w * 0.42));
	float band = band_core + band_halo * 0.48;

	vec3 in_plane = eyedir - plane_n * dot(eyedir, plane_n);
	float ip2 = dot(in_plane, in_plane);
	vec3 along_dir = ip2 > 1e-8 ? normalize(in_plane) : core_dir;
	vec3 core_flat = core_dir - plane_n * dot(core_dir, plane_n);
	float cf2 = dot(core_flat, core_flat);
	vec3 core_u = cf2 > 1e-8 ? normalize(core_flat) : along_dir;
	vec3 plane_v = normalize(cross(plane_n, core_u));
	float along = atan(dot(along_dir, plane_v), dot(along_dir, core_u)) / 6.2831853 + 0.5;
	float across = dot(along_dir, core_u);
	vec2 uv = vec2(along * 6.2, across * 3.4);

	float dust = fbm(uv * 1.75 + vec2(0.6, 1.3));
	float dust2 = fbm(uv * 4.9 + vec2(11.0, 2.5));
	float dust3 = fbm(uv * 10.5 + vec2(-3.0, 7.5));
	float lanes = smoothstep(0.22, 0.58, dust2);
	float bright_clouds = smoothstep(0.38, 0.9, dust);
	float filaments = pow(max(0.0, dust3 - 0.38), 2.0) * 2.1;
	float structure = mix(0.32, 1.0, bright_clouds) * mix(1.0, 0.5, lanes * 0.88) + filaments * 0.62;

	float bulge = pow(max(0.0, dot(eyedir, core_dir)), 10.0) * 2.6;
	float shape = band * structure + bulge * band * (0.28 + 0.72 * bright_clouds);

	float dust_mix = clamp(lanes * 0.65 + (1.0 - bright_clouds) * 0.25, 0.0, 1.0);
	vec3 mw_color = mix(milky_way_tint, milky_way_dust_tint, dust_mix);

	float horizon_fade = smoothstep(0.03, 0.36, eyedir.y);
	float night_gate = smoothstep(0.38, 0.9, night_amt);
	float intensity = max(0.0, shape) * horizon_fade * night_gate * milky_way_intensity;
	return mw_color * intensity;
}

vec3 aurora(vec3 eyedir, vec3 moon_dir, float night_amt) {
	if (!aurora_enabled || night_amt < 0.01) {
		return vec3(0.0);
	}
	float base_h = max(aurora_band_height, 0.08);
	float spread = max(aurora_band_softness * 2.8 + 0.18, 0.22);
	float lower = clamp(base_h - spread, -0.25, 0.8);
	float upper = clamp(base_h + spread * 1.45, -0.2, 1.0);
	float height_mask = smoothstep(lower, upper, eyedir.y);
	float sweep = fbm(vec2(eyedir.x * 4.6 + TIME * aurora_speed, eyedir.z * 1.6 - TIME * aurora_speed * 0.14));
	float curtain = fbm(vec2(eyedir.x * 6.2 - TIME * aurora_speed * 0.22, eyedir.z * 2.0 + TIME * aurora_speed * 0.09));
	float broad = fbm(vec2(eyedir.x * 2.6 + TIME * aurora_speed * 0.08, eyedir.z * 1.2 - TIME * aurora_speed * 0.04));
	float stripes = smoothstep(0.36, 0.88, sweep * 0.4 + curtain * 0.35 + broad * 0.5);
	float flicker = 0.95 + 0.05 * (sin(TIME * 0.4 + eyedir.x * 4.0) * 0.5 + 0.5);
	float hue_shift = sin(TIME * (aurora_speed * 0.72) + eyedir.x * 6.2 + eyedir.z * 3.4) * 0.5 + 0.5;
	vec3 col_ab = mix(aurora_color_a, aurora_color_b, curtain);
	vec3 col = mix(col_ab, aurora_color_c, hue_shift * 0.7);
	float moon_near = smoothstep(1.0 - aurora_moon_exclusion, 1.0, max(dot(eyedir, moon_dir), 0.0));
	float moon_mask = 1.0 - moon_near;
	/* Keep aurora colorful without washing out stars/moon. */
	float night_gate = smoothstep(0.55, 0.97, night_amt);
	return col * stripes * height_mask * flicker * moon_mask * night_gate * aurora_intensity * 0.56;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun_dir = normalize(sun_direction);
	vec3 moon_dir = normalize(moon_direction);
	if (length(moon_dir) < 0.001) {
		moon_dir = -sun_dir;
	}
	float night_amt = 1.0 - day_factor;

	if (AT_CUBEMAP_PASS) {
		vec3 cheap = mix(zenith_night, zenith_day, day_factor);
		COLOR = cheap * (0.75 + 0.15 * day_factor);
	} else {
	vec3 col = sky_gradient(dir, day_factor, sunset_factor);

	float sun_dot = max(dot(dir, sun_dir), 0.0);
	float sun_core = smoothstep(1.0 - sun_disk_size * 8.0, 1.0, sun_dot);
	vec3 sun_col = sun_disk_color;
	sun_col = mix(sun_col, sun_col * vec3(0.92, 0.88, 0.75), sun_limb_darken * (1.0 - pow(sun_dot, 0.35)));
	float sun_disc = sun_core;
	col = mix(col, sun_col, sun_disc * day_factor);
	float corona = smoothstep(1.0 - sun_corona_size, 1.0 - sun_disk_size * 3.0, sun_dot) * (1.0 - sun_core * 0.85);
	col += sun_corona_color * corona * sun_corona_intensity * day_factor;

	float moon_dot = max(dot(dir, moon_dir), 0.0);
	float mw = moon_disk_size * 6.0;
	float moon_disc = smoothstep(1.0 - mw * 0.52, 1.0 - mw * 0.06, moon_dot);
	/* Fade moon in as the sun gets low; opposite-sun placement keeps it above horizon at dusk. */
	float moon_vis = smoothstep(0.08, 0.92, night_amt * 0.85 + (1.0 - day_factor) * 0.55);

	/* Stable moon tangent frame + UV scale tied to disk size to avoid shimmer/flicker while moving. */
	vec3 ref_axis = (abs(moon_dir.y) < 0.94) ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t1 = normalize(cross(ref_axis, moon_dir));
	vec3 t2 = normalize(cross(moon_dir, t1));
	vec2 moon_uv = vec2(dot(dir, t1), dot(dir, t2)) / max(mw, 0.0001);
	moon_uv = clamp(moon_uv, vec2(-1.0), vec2(1.0));
	float mare = fbm(moon_uv * 3.8 + vec2(1.7, 0.9)) * moon_detail_strength;
	float rim = pow(1.0 - moon_dot, moon_rim_power) * moon_rim_strength;
	// Diffuse on sphere: light toward sun from surface is -sun_dir; outward normal ~ dir from moon center.
	float lunar_lit = max(dot(dir, -sun_dir), 0.0);
	float moon_xy2 = dot(moon_uv, moon_uv);
	float moon_z = sqrt(max(0.0, 1.0 - moon_xy2));
	vec3 moon_normal = normalize(vec3(moon_uv, moon_z));
	float phase_angle = moon_phase * 6.2831853;
	vec3 phase_light_local = normalize(vec3(cos(phase_angle), 0.0, sin(phase_angle)));
	float phase_lit = max(dot(moon_normal, phase_light_local), 0.0);
	lunar_lit = mix(lunar_lit, phase_lit, moon_phase_strength);
	vec3 moon_base = moon_disk_color * (0.72 + 0.28 * (1.0 - mare)) * (0.25 + 0.75 * lunar_lit);
	moon_base += vec3(0.06, 0.07, 0.1) * mare * (0.4 + 0.6 * lunar_lit);
	moon_base += vec3(0.15, 0.18, 0.22) * rim * (0.35 + 0.65 * lunar_lit);
	float earth = smoothstep(0.05, 0.55, 1.0 - lunar_lit) * moon_earthshine;
	moon_base += moon_earthshine_color * earth;
	vec3 moon_rgb = moon_base;
	col = mix(col, moon_rgb, moon_disc * moon_vis * 0.95);

	float st = stars(dir, night_amt);
	col += star_tint * st;
	col += milky_way(dir, night_amt);
	col += aurora(dir, moon_dir, night_amt);

	vec2 wind = vec2(TIME * cloud_wind_speed, TIME * cloud_wind_speed * 0.73);
	vec2 cu = dir.xz / max(dir.y + 0.22, 0.08) * cloud_domain + wind * 1.2;
	float n = cloud_fbm_soft(cu + vec2(TIME * cloud_wind_speed * 6.0, 0.0));
	float edge = smoothstep(cloud_coverage, cloud_coverage + cloud_softness, n);
	float puff = edge * edge * (3.0 - 2.0 * edge);
	float dens = puff * smoothstep(0.08, 0.95, n + 0.05 * fbm(cu * 1.3 + wind));
	vec3 ccol = mix(cloud_color_night * night_cloud_brightness, cloud_color_day, day_factor);
	ccol = mix(ccol, cloud_color_sunset, sunset_factor * 0.85);
	float cloud_alpha = dens * (0.1 + 0.38 * day_factor + 0.07 * night_amt);
	col = mix(col, ccol, clamp(cloud_alpha, 0.0, 0.78));

	COLOR = col;
	}
}

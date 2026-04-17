shader_type sky;

/* RuneForged — cool teal / slate day, deep indigo night; procedural clouds + stars.
 * sun_direction: world-space unit vector *toward* the sun (set by DayNightController). */

uniform vec3 sun_direction = vec3(0.2, 0.97, 0.12);
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
uniform float moon_detail_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float moon_rim_strength : hint_range(0.0, 1.0, 0.01) = 0.38;
uniform float moon_rim_power : hint_range(0.5, 8.0, 0.1) = 2.4;
uniform float moon_earthshine : hint_range(0.0, 0.5, 0.005) = 0.08;
uniform vec3 moon_earthshine_color : source_color = vec3(0.22, 0.28, 0.38);

uniform float star_threshold : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float star_brightness : hint_range(0.0, 2.5, 0.01) = 0.88;
uniform vec3 star_tint : source_color = vec3(0.72, 0.8, 0.95);
uniform vec2 star_density_uv = vec2(340.0, 175.0);
uniform float star_point_size : hint_range(0.02, 0.35, 0.001) = 0.042;
uniform float star_twinkle_amount : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float star_bright_boost : hint_range(1.0, 4.0, 0.05) = 2.6;
uniform float star_bright_threshold : hint_range(0.9, 0.999, 0.001) = 0.988;
uniform float star_dim_threshold : hint_range(0.5, 0.95, 0.001) = 0.74;
uniform float star_core_power : hint_range(0.5, 3.0, 0.05) = 1.45;
uniform float star_halo : hint_range(0.0, 0.6, 0.01) = 0.28;

uniform float cloud_coverage : hint_range(0.0, 1.0, 0.01) = 0.36;
uniform float cloud_softness : hint_range(0.01, 0.7, 0.01) = 0.36;
uniform float cloud_warp : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform vec3 cloud_color_day : source_color = vec3(0.92, 0.94, 0.98);
uniform vec3 cloud_color_sunset : source_color = vec3(0.98, 0.72, 0.55);
uniform vec3 cloud_color_night : source_color = vec3(0.05, 0.06, 0.09);
uniform float night_cloud_brightness : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float cloud_wind_speed : hint_range(0.0, 0.05, 0.0001) = 0.008;
uniform float cloud_domain : hint_range(1.0, 12.0, 0.1) = 2.8;

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
	if (night_amt < 0.02) {
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
	return m * night_amt * star_brightness;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun_dir = normalize(sun_direction);
	vec3 moon_dir = -sun_dir;
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
	float moon_vis = smoothstep(0.15, 0.85, night_amt + (1.0 - day_factor) * 0.5);

	vec3 t1 = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)));
	if (length(t1) < 0.08) {
		t1 = normalize(cross(moon_dir, vec3(1.0, 0.0, 0.0)));
	}
	vec3 t2 = normalize(cross(moon_dir, t1));
	float sin_theta = length(cross(dir, moon_dir));
	vec2 moon_uv = vec2(dot(dir, t1), dot(dir, t2)) / max(sin_theta, 0.02);
	float mare = fbm(moon_uv * 3.8 + vec2(1.7, 0.9)) * moon_detail_strength;
	float rim = pow(1.0 - moon_dot, moon_rim_power) * moon_rim_strength;
	// Diffuse on sphere: light toward sun from surface is -sun_dir; outward normal ~ dir from moon center.
	float lunar_lit = max(dot(dir, -sun_dir), 0.0);
	vec3 moon_base = moon_disk_color * (0.72 + 0.28 * (1.0 - mare)) * (0.25 + 0.75 * lunar_lit);
	moon_base += vec3(0.06, 0.07, 0.1) * mare * (0.4 + 0.6 * lunar_lit);
	moon_base += vec3(0.15, 0.18, 0.22) * rim * (0.35 + 0.65 * lunar_lit);
	float earth = smoothstep(0.05, 0.55, 1.0 - lunar_lit) * moon_earthshine;
	moon_base += moon_earthshine_color * earth;
	vec3 moon_rgb = moon_base;
	col = mix(col, moon_rgb, moon_disc * moon_vis * 0.95);

	float st = stars(dir, smoothstep(star_threshold, 1.0, night_amt));
	col += star_tint * st;

	vec2 wind = vec2(TIME * cloud_wind_speed, TIME * cloud_wind_speed * 0.73);
	vec2 cu = dir.xz / max(dir.y + 0.22, 0.08) * cloud_domain + wind * 1.2;
	float n = cloud_fbm_soft(cu + vec2(TIME * cloud_wind_speed * 6.0, 0.0));
	float edge = smoothstep(cloud_coverage, cloud_coverage + cloud_softness, n);
	float puff = edge * edge * (3.0 - 2.0 * edge);
	float dens = puff * smoothstep(0.08, 0.95, n + 0.05 * fbm(cu * 1.3 + wind));
	vec3 ccol = mix(cloud_color_night * night_cloud_brightness, cloud_color_day, day_factor);
	ccol = mix(ccol, cloud_color_sunset, sunset_factor * 0.85);
	float cloud_alpha = dens * (0.22 + 0.36 * day_factor + 0.12 * night_amt);
	col = mix(col, ccol, clamp(cloud_alpha, 0.0, 0.82));

	COLOR = col;
	}
}

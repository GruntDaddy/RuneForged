shader_type sky;

/* RuneForged — cool teal / slate day, deep indigo night; procedural clouds + stars.
 * sun_direction: world-space unit vector *toward* the sun (set by DayNightController). */

uniform vec3 sun_direction = vec3(0.2, 0.97, 0.12);
uniform float day_factor : hint_range(0.0, 1.0, 0.001) = 0.85;
uniform float sunset_factor : hint_range(0.0, 1.0, 0.001) = 0.0;

uniform vec3 zenith_day : source_color = vec3(0.35, 0.55, 0.78);
uniform vec3 zenith_night : source_color = vec3(0.04, 0.06, 0.12);
uniform vec3 horizon_day : source_color = vec3(0.62, 0.72, 0.82);
uniform vec3 horizon_night : source_color = vec3(0.07, 0.08, 0.12);
uniform vec3 sunset_color : source_color = vec3(0.95, 0.55, 0.32);

uniform float sun_disk_size : hint_range(0.001, 0.05, 0.0001) = 0.0045;
uniform vec3 sun_disk_color : source_color = vec3(1.0, 0.97, 0.88);
uniform float moon_disk_size : hint_range(0.001, 0.06, 0.0001) = 0.018;
uniform vec3 moon_disk_color : source_color = vec3(0.82, 0.86, 0.95);

uniform float star_threshold : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float star_brightness : hint_range(0.0, 2.0, 0.01) = 0.65;
uniform vec3 star_tint : source_color = vec3(0.85, 0.9, 1.0);

uniform float cloud_coverage : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float cloud_softness : hint_range(0.01, 0.5, 0.01) = 0.18;
uniform vec3 cloud_color_day : source_color = vec3(0.92, 0.94, 0.98);
uniform vec3 cloud_color_sunset : source_color = vec3(0.98, 0.72, 0.55);
uniform vec3 cloud_color_night : source_color = vec3(0.12, 0.14, 0.2);
uniform float cloud_wind_speed : hint_range(0.0, 0.05, 0.0001) = 0.008;
uniform float cloud_domain : hint_range(1.0, 12.0, 0.1) = 4.5;

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

// Voronoi with per-cell scale variation → varied cloud sizes
float clouds_voronoi(vec2 p, float time_wind) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float md = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 cell = ip + g;
			float h = hash21(cell);
			float sz = 0.45 + h * 0.95;
			vec2 o = vec2(hash21(cell + vec2(13.0, 2.0)), hash21(cell + vec2(7.0, 29.0))) * 0.7 + 0.15;
			o += vec2(time_wind * (0.3 + h), time_wind * (0.2 + h * 0.5)) * sz;
			vec2 r = g + o * sz - fp;
			float d = length(r) / sz;
			if (d < md) {
				second = md;
				md = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return clamp(second - md, 0.0, 1.0);
}

vec3 sky_gradient(vec3 eyedir, float day_f, float sunset_f) {
	float v = clamp(eyedir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 zenith = mix(zenith_night, zenith_day, day_f);
	vec3 horizon = mix(horizon_night, horizon_day, day_f);
	vec3 grad = mix(horizon, zenith, pow(v, 0.9));
	grad = mix(grad, grad * sunset_color, sunset_f * (1.0 - abs(eyedir.y) * 0.5));
	return grad;
}

float stars(vec3 eyedir, float night_amt) {
	if (night_amt < 0.02) {
		return 0.0;
	}
	vec3 p = normalize(eyedir + vec3(0.001, 0.002, 0.001));
	vec2 uv = vec2(atan(p.z, p.x) / 6.2831853 + 0.5, asin(clamp(p.y, -1.0, 1.0)) * 0.5 + 0.5);
	uv *= vec2(120.0, 60.0);
	vec2 id = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float h = hash21(id);
	float tw = sin(TIME * (1.2 + h * 2.0) + h * 6.28) * 0.5 + 0.5;
	float m = smoothstep(0.35, 0.0, length(f)) * step(0.965, h) * tw;
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
		return;
	}

	vec3 col = sky_gradient(dir, day_factor, sunset_factor);

	// Sun disc
	float sun_dot = max(dot(dir, sun_dir), 0.0);
	float sun_disc = smoothstep(1.0 - sun_disk_size * 8.0, 1.0, sun_dot);
	col = mix(col, sun_disk_color, sun_disc * day_factor);

	// Moon disc (visible when sun is below horizon / night side of sky)
	float moon_dot = max(dot(dir, moon_dir), 0.0);
	float moon_disc = smoothstep(1.0 - moon_disk_size * 6.0, 1.0, moon_dot);
	float moon_vis = smoothstep(0.15, 0.85, night_amt + (1.0 - day_factor) * 0.5);
	col = mix(col, moon_disk_color, moon_disc * moon_vis * 0.95);

	// Stars (upper hemisphere, night)
	float st = stars(dir, smoothstep(star_threshold, 1.0, night_amt));
	col += star_tint * st;

	// Clouds: sample on dome
	vec2 wind = vec2(TIME * cloud_wind_speed, TIME * cloud_wind_speed * 0.73);
	vec2 cu = dir.xz / max(dir.y + 0.18, 0.08) * cloud_domain + wind;
	float cv = clouds_voronoi(cu * 3.2 + fbm(cu * 1.7) * 0.4, TIME * cloud_wind_speed * 12.0);
	float dens = smoothstep(cloud_coverage, cloud_coverage + cloud_softness, cv * fbm(cu * 0.9 + wind));
	vec3 ccol = mix(cloud_color_night, cloud_color_day, day_factor);
	ccol = mix(ccol, cloud_color_sunset, sunset_factor * 0.85);
	float cloud_alpha = dens * (0.35 + 0.45 * day_factor + 0.35 * night_amt);
	col = mix(col, ccol, clamp(cloud_alpha, 0.0, 0.92));

	COLOR = col;
}

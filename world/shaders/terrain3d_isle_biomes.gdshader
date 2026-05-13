shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, skip_vertex_transform;

/* Terrain3D fork (from lightweight): optional 5-layer height/slope biomes on full-auto fragments.
 * Sand near sea, dirt→grass inland, rock on steep slopes, snow on high peaks.
 * Painted (non-auto) control-map tiles use the stock two-layer path.
 */

#define SKIP_PASS 0
#define VERTEX_PASS 1
#define FRAGMENT_PASS 2
#define COLOR_MAP vec4(1.0, 1.0, 1.0, 0.5)
#define DIV_255 0.003921568627450

#define DECODE_HOLE(control) bool(control >> 2u & 0x1u)

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	#define fma(a, b, c) ((a) * (b) + (c))
	#define dFdxCoarse(a) dFdx(a)
	#define dFdyCoarse(a) dFdy(a)
#endif

uniform vec3 _camera_pos = vec3(0.f);
uniform float _mesh_size = 48.f;
uniform uint _background_mode = 1u;
uniform uint _mouse_layer = 0x80000000u;
uniform float _vertex_spacing = 1.0;
uniform float _vertex_density = 1.0;
uniform float _region_size = 1024.0;
uniform float _region_texel_size = 0.0009765625;
uniform int _region_map_size = 32;
uniform int _region_map[1024];
uniform vec2 _region_locations[1024];
uniform float _texture_normal_depth_array[32];
uniform float _texture_ao_strength_array[32];
uniform float _texture_roughness_mod_array[32];
uniform float _texture_uv_scale_array[32];
uniform vec2 _texture_detile_array[32];
uniform vec4 _texture_color_array[32];
uniform highp sampler2DArray _height_maps : repeat_disable;
uniform highp sampler2DArray _control_maps : repeat_disable;
uniform highp sampler2DArray _color_maps : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform highp sampler2DArray _texture_array_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform highp sampler2DArray _texture_array_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform bool enable_texturing = true;
uniform float blend_sharpness : hint_range(0, 1) = 0.45;
uniform bool flat_terrain_normals = false;

uniform float auto_slope : hint_range(0, 10) = 1.0;
uniform float auto_height_reduction : hint_range(0, 1) = 0.1;
uniform int auto_base_texture : hint_range(0, 31) = 0;
uniform int auto_overlay_texture : hint_range(0, 31) = 1;

uniform bool use_island_autoshader = true;
uniform float sea_level_y = 0.0;
uniform int sand_texture_id : hint_range(0, 31) = 1;
uniform int dirt_texture_id : hint_range(0, 31) = 3;
uniform int grass_texture_id : hint_range(0, 31) = 0;
uniform int rock_texture_id : hint_range(0, 31) = 2;
uniform int snow_texture_id : hint_range(0, 31) = 4;
// Sand: strong near sea; fades out by ~sand_fade_end_m above sea (meters).
uniform float sand_fade_start_m = 0.0;
uniform float sand_fade_end_m = 1.35;
// Inland dirt → grass (height above sea, meters).
uniform float dirt_grass_blend_low_m = 0.85;
uniform float dirt_grass_blend_high_m = 10.0;
// Rock from slope (1 - normal.y).
uniform float rock_steep_start = 0.11;
uniform float rock_steep_end = 0.36;
// Snow on summits; reduced on sheer rock.
uniform float snow_height_start_m = 18.0;
uniform float snow_height_full_m = 28.0;
uniform float snow_rock_suppression : hint_range(0.0, 1.0) = 0.85;
// Noise steals weight from grass → dirt (inland); avoids relying on spray paint for variation.
uniform float grass_dirt_variation : hint_range(0.0, 1.0) = 0.28;
uniform float grass_dirt_noise_scale = 0.052;
// World XZ patches (xy), radius z (m), strength w — filled by script (e.g. tree trunks).
uniform int tree_dirt_patch_count : hint_range(0, 48) = 0;
uniform vec4 tree_dirt_patches[48];
uniform float tree_dirt_grass_mul : hint_range(0.0, 1.5) = 0.9;

uniform bool enable_macro_variation = true;
uniform vec3 macro_variation1 : source_color = vec3(1.);
uniform vec3 macro_variation2 : source_color = vec3(1.);
uniform float macro_variation_slope : hint_range(0., 1.) = 0.333;
uniform highp sampler2D noise_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float noise1_scale : hint_range(0.001, 1.) = 0.04;
uniform float noise1_angle : hint_range(0, 6.283) = 0.;
uniform vec2 noise1_offset = vec2(0.5);
uniform float noise2_scale : hint_range(0.001, 1.) = 0.076;

varying vec3 v_normal;
varying vec3 v_vertex;
varying mat3 TBN;

ivec3 get_index_coord(const vec2 uv, const int search) {
	vec2 r_uv = round(uv);
	vec2 o_uv = mod(r_uv, _region_size);
	ivec2 pos;
	int bounds, layer_index = -1;
	for (int i = -1; i < clamp(search, SKIP_PASS, FRAGMENT_PASS); i++) {
		if ((layer_index == -1 && _background_mode == 0u) || i < 0) {
			r_uv -= i == -1 ? vec2(0.0) : vec2(float(o_uv.x <= o_uv.y), float(o_uv.y <= o_uv.x));
			pos = ivec2(floor((r_uv) * _region_texel_size)) + (_region_map_size / 2);
			bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
			layer_index = (_region_map[pos.y * _region_map_size + pos.x] * bounds - 1);
		}
	}
	return ivec3(ivec2(mod(r_uv, _region_size)), layer_index);
}

vec3 get_index_uv(const vec2 uv2) {
	ivec2 pos = ivec2(floor(uv2)) + (_region_map_size / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
	int layer_index = _region_map[pos.y * _region_map_size + pos.x] * bounds - 1;
	return vec3(uv2 - _region_locations[layer_index], float(layer_index));
}

void vertex() {
	v_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float v_vertex_xz_dist = length(v_vertex.xz - _camera_pos.xz);
	float scale = MODEL_MATRIX[0][0];
	float vertex_lerp = smoothstep(0.55, 0.95, (v_vertex_xz_dist / scale - _mesh_size - 4.0) / (_mesh_size - 2.0));
	vec2 v_fract = fract(VERTEX.xz * 0.5) * 2.0;
	vec2 shift = (scale < _vertex_spacing + 1e-6) ?
		mix(v_fract, vec2(v_fract.x, -v_fract.y),
			round(fract(round(mod(v_vertex.z * _vertex_density, 4.0)) *
			round(mod(v_vertex.x * _vertex_density, 4.0)) * 0.25))) :
		v_fract * round((fract(v_vertex.xz * 0.25 / scale) - 0.5) * 4.0);
	vec2 start_pos = v_vertex.xz * _vertex_density;
	vec2 end_pos = (v_vertex.xz - shift * scale) * _vertex_density;
	v_vertex.xz -= shift * scale * vertex_lerp;
	UV = v_vertex.xz * _vertex_density;
	UV2 = fma(UV, vec2(_region_texel_size), vec2(0.5 * _region_texel_size));
	ivec3 v_region = get_index_coord(start_pos, VERTEX_PASS);
	uint control = floatBitsToUint(texelFetch(_control_maps, v_region, 0)).r;
	bool hole = DECODE_HOLE(control);
	if (!(CAMERA_VISIBLE_LAYERS == _mouse_layer) &&
			(hole || (_background_mode == 0u && v_region.z == -1))) {
		v_vertex.x = 0.0 / 0.0;
	} else {
		ivec3 uv_a = get_index_coord(start_pos, VERTEX_PASS);
		ivec3 uv_b = get_index_coord(end_pos, VERTEX_PASS);
		float h = mix(texelFetch(_height_maps, uv_a, 0).r, texelFetch(_height_maps, uv_b, 0).r, vertex_lerp);
		v_vertex.y = h;
		float u = mix(texelFetch(_height_maps, get_index_coord(start_pos + vec2(1, 0), VERTEX_PASS), 0).r,
			texelFetch(_height_maps, get_index_coord(end_pos + vec2(1, 0), VERTEX_PASS), 0).r, vertex_lerp);
		float v = mix(texelFetch(_height_maps, get_index_coord(start_pos + vec2(0, 1), VERTEX_PASS), 0).r,
			texelFetch(_height_maps, get_index_coord(end_pos + vec2(0, 1), VERTEX_PASS), 0).r, vertex_lerp);
		v_normal = normalize(vec3(h - u, _vertex_spacing, h - v));
	}
	VERTEX = (VIEW_MATRIX * vec4(v_vertex, 1.0)).xyz;
	vec3 w_tangent = normalize(cross(v_normal, vec3(0.0, 0.0, 1.0)));
	vec3 w_binormal = normalize(cross(v_normal, w_tangent));
	TBN = mat3(w_tangent, w_binormal, v_normal);
	NORMAL = normalize((VIEW_MATRIX * vec4(v_normal, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(w_binormal, 0.0)).xyz);
	TANGENT = normalize((VIEW_MATRIX * vec4(w_tangent, 0.0)).xyz);
}

mat2 rotate_plane(float angle) {
	float c = cos(angle), s = sin(angle);
	return mat2(vec2(c, s), vec2(-s, c));
}

float t3d_hash(vec2 xy) {
	return fract(sin(dot(xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 t3d_rot_vec2(vec2 v, vec2 cs) {
	return vec2(fma(cs.x, v.x, cs.y * v.y), fma(cs.x, v.y, -cs.y * v.x));
}

void t3d_sample_detiled(
		int id,
		vec2 uv_s,
		vec4 base_dd,
		float kw,
		float sharpness,
		mat3 p_tbn,
		vec3 p_vn,
		inout vec4 io_albedo_height,
		inout vec4 io_normal_rough,
		inout float io_normal_map_depth,
		inout float io_ao_strength,
		inout float io_total_weight,
		inout vec4 io_nrm_acc) {
	float s = _texture_uv_scale_array[id];
	float sh = s * 0.5;
	vec2 cs_coord = fma(uv_s, vec2(s), vec2(0.5));
	vec2 cell = floor(cs_coord);
	vec2 f = fract(cs_coord);
	vec2 u0 = fma(uv_s, vec2(sh), vec2(0.5));
	vec2 det = _texture_detile_array[id];
	// Bilinear blend of corner hashes so rotation/shift don't jump at tile edges (avoids square grid).
	float r00 = t3d_hash(cell);
	float r10 = t3d_hash(cell + vec2(1.0, 0.0));
	float r01 = t3d_hash(cell + vec2(0.0, 1.0));
	float r11 = t3d_hash(cell + vec2(1.0, 1.0));
	float rb = mix(mix(r00, r10, f.x), mix(r01, r11, f.x), f.y);
	vec2 hoff = vec2(17.19, 23.71);
	float s00 = t3d_hash(cell + hoff);
	float s10 = t3d_hash(cell + vec2(1.0, 0.0) + hoff);
	float s01 = t3d_hash(cell + vec2(0.0, 1.0) + hoff);
	float s11 = t3d_hash(cell + vec2(1.0, 1.0) + hoff);
	float sb = mix(mix(s00, s10, f.x), mix(s01, s11, f.x), f.y);
	float ang_full = fma(rb, 2.0, -1.0) * det.x * 6.28318530718;
	float shf_full = fma(sb, 2.0, -1.0) * det.y * 6.28318530718;
	// Fade detiling near cell borders → UV matches undetiled u0 on seams (removes visible squares).
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float detile_w = smoothstep(0.0, 0.16, edge);
	float ang = ang_full * detile_w;
	float shf = shf_full * detile_w;
	vec2 cs = vec2(cos(ang), sin(ang));
	vec2 center_uv = fma(cell, vec2(sh), vec2(0.5));
	vec2 id_uv = t3d_rot_vec2(u0 - center_uv, cs) + center_uv + vec2(shf * sh * 0.06);
	vec4 i_dd;
	i_dd.xy = t3d_rot_vec2(base_dd.xy * sh, cs);
	i_dd.zw = t3d_rot_vec2(base_dd.zw * sh, cs);
	vec4 alb = textureGrad(_texture_array_albedo, vec3(id_uv, float(id)), i_dd.xy, i_dd.zw);
	float world_normal = clamp(fma(p_tbn[0], vec3(io_nrm_acc.x), fma(p_tbn[1], vec3(io_nrm_acc.z), p_vn * vec3(io_nrm_acc.y))).y, 0., 1.);
	vec4 nrm = textureGrad(_texture_array_normal, vec3(id_uv, float(id)), i_dd.xy, i_dd.zw);
	alb.rgb *= _texture_color_array[id].rgb;
	nrm.a = clamp(nrm.a + _texture_roughness_mod_array[id], 0., 1.);
	nrm.xyz = fma(nrm.xzy, vec3(2.0), vec3(-1.0));
	nrm.xz = t3d_rot_vec2(nrm.xz, cs);
	float id_weight = exp2(sharpness * log2(kw + alb.a * world_normal));
	io_albedo_height += alb * id_weight;
	io_normal_rough += nrm * id_weight;
	io_normal_map_depth += _texture_normal_depth_array[id] * id_weight;
	io_ao_strength += _texture_ao_strength_array[id] * id_weight;
	io_total_weight += id_weight;
	io_nrm_acc = nrm;
}

void fragment() {
	vec2 uv = UV;
	vec2 uv2 = UV2;
	vec3 region_uv = get_index_uv(uv2);
	const vec3 offsets = vec3(0, 1, 2);
	vec2 index_id = floor(uv);
	vec2 weight = fract(uv);
	vec2 invert = 1.0 - weight;
	vec4 weights = vec4(
		invert.x * weight.y,
		weight.x * weight.y,
		weight.x * invert.y,
		invert.x * invert.y
	);
	ivec3 index[4];
	index[0] = get_index_coord(index_id + offsets.xy, FRAGMENT_PASS);
	index[1] = get_index_coord(index_id + offsets.yy, FRAGMENT_PASS);
	index[2] = get_index_coord(index_id + offsets.yx, FRAGMENT_PASS);
	index[3] = get_index_coord(index_id + offsets.xx, FRAGMENT_PASS);
	vec3 base_ddx = dFdxCoarse(v_vertex);
	vec3 base_ddy = dFdyCoarse(v_vertex);
	vec4 base_dd = vec4(base_ddx.xz, base_ddy.xz);
	float region_mip = log2(max(length(base_ddx.xz), length(base_ddy.xz)) * _vertex_density);
	vec4 color_map = region_uv.z > -1.0 ? textureLod(_color_maps, region_uv, region_mip) : COLOR_MAP;
	if (flat_terrain_normals) {
		NORMAL = normalize(cross(dFdyCoarse(VERTEX), dFdxCoarse(VERTEX)));
		TANGENT = normalize(cross(NORMAL, VIEW_MATRIX[2].xyz));
		BINORMAL = normalize(cross(NORMAL, TANGENT));
	}
	vec4 normal_rough = vec4(0., 1., 0., 0.7);
	vec4 albedo_height = vec4(1.);
	float normal_map_depth = 1.;
	float ao_strength = 0.;

	if (enable_texturing) {
		albedo_height = vec4(0.);
		normal_rough = vec4(0.);
		normal_map_depth = 0.;
		ao_strength = 0.;
		float total_weight = 0.;
		float sharpness = fma(56., blend_sharpness, 8.);

		uvec4 control = uvec4(
			floatBitsToUint(texelFetch(_control_maps, index[0], 0).r),
			floatBitsToUint(texelFetch(_control_maps, index[1], 0).r),
			floatBitsToUint(texelFetch(_control_maps, index[2], 0).r),
			floatBitsToUint(texelFetch(_control_maps, index[3], 0).r)
		);

		uvec4 is_auto = (control & uvec4(0x1u)) | uvec4(uint(region_uv.z < 0.0));
		uint auto_n = uint(is_auto.x > 0u) + uint(is_auto.y > 0u) + uint(is_auto.z > 0u) + uint(is_auto.w > 0u);
		// Procedural island only when all four bilinear corners are still “auto”. If any corner was
		// texture-painted, use the control-map path only — otherwise painted dirt gets overridden by
		// height rules (e.g. sand) and looks like random “plops”.
		bool island_path = use_island_autoshader && auto_n == 4u;

		if (island_path) {
			float h_agl = v_vertex.y - sea_level_y;
			float steep = max(0.0, 1.0 - v_normal.y);
			float rock_w = smoothstep(rock_steep_start, rock_steep_end, steep);
			float snow_w = smoothstep(snow_height_start_m, snow_height_full_m, h_agl);
			snow_w *= 1.0 - snow_rock_suppression * rock_w;
			float open_w = max(0.0, 1.0 - rock_w - snow_w);

			float lowland_sand = 1.0 - smoothstep(sand_fade_start_m, sand_fade_end_m, h_agl);
			float veg_mix = 1.0 - lowland_sand;
			float grass_t = smoothstep(dirt_grass_blend_low_m, dirt_grass_blend_high_m, h_agl);
			float lowland_dirt = veg_mix * (1.0 - grass_t);
			float lowland_grass = veg_mix * grass_t;

			float sand_f = open_w * lowland_sand;
			float dirt_f = open_w * lowland_dirt;
			float grass_f = open_w * lowland_grass;

			vec2 uv_s = uv * _vertex_spacing;
			// Break up uniform grass: steal weight to dirt using macro noise (smooth, not paint-sized blocks).
			float n_coarse = texture(noise_texture, uv_s * grass_dirt_noise_scale + noise1_offset).r;
			float n_fine = texture(noise_texture, uv_s * grass_dirt_noise_scale * 2.65 + noise1_offset + vec2(0.41, 0.17)).r;
			// Soft, high-threshold patch so dirt reads as subtle ground variation, not chunky plops.
			float n_mix = sqrt(max(0.0, n_coarse * n_fine));
			float patch = smoothstep(0.52, 0.86, n_mix);
			patch = patch * patch;
			float steal_noise = patch * grass_dirt_variation * grass_f;
			dirt_f += steal_noise;
			grass_f = max(grass_f - steal_noise, 0.0);
			// Extra dirt at tree bases (positions pushed from GDScript).
			float tree_mask = 0.0;
			for (int ti = 0; ti < 48; ti++) {
				if (ti < tree_dirt_patch_count) {
					vec4 tp = tree_dirt_patches[ti];
					float d = distance(v_vertex.xz, tp.xy);
					tree_mask = max(tree_mask, (1.0 - smoothstep(tp.z * 0.22, tp.z, d)) * tp.w);
				}
			}
			float steal_tree = tree_mask * tree_dirt_grass_mul * grass_f;
			dirt_f += steal_tree;
			grass_f = max(grass_f - steal_tree, 0.0);

			vec4 nrm_acc = vec4(0.0, 1.0, 0.0, 1.0);

			for (int k = 0; k < 5; k++) {
				float kw = k == 0 ? sand_f : k == 1 ? dirt_f : k == 2 ? grass_f : k == 3 ? rock_w : snow_w;
				if (kw < 1e-6) {
					continue;
				}
				int id = k == 0 ? sand_texture_id : k == 1 ? dirt_texture_id : k == 2 ? grass_texture_id : k == 3 ? rock_texture_id : snow_texture_id;
				t3d_sample_detiled(id, uv_s, base_dd, kw, sharpness, TBN, v_normal, albedo_height, normal_rough, normal_map_depth, ao_strength, total_weight, nrm_acc);
			}
			float weight_inv = 1.0 / total_weight;
			albedo_height *= weight_inv;
			normal_rough *= weight_inv;
			normal_map_depth *= weight_inv;
			ao_strength *= weight_inv;
		} else {
			{
				float auto_blend = clamp(fma(auto_slope * 2.0, (v_normal.y - 1.0), 1.0)
					- auto_height_reduction * 0.01 * v_vertex.y, 0.0, 1.0);
				uvec4 u_auto = (control & uvec4(0x1u)) | uvec4(uint(region_uv.z < 0.0));
				uint u_auto_pack =
					((uint(auto_base_texture) & 0x1Fu) << 27u) |
					((uint(auto_overlay_texture) & 0x1Fu) << 22u) |
					((uint(fma(auto_blend, 255.0, 0.5)) & 0xFFu) << 14u);
				control = control * (1u - u_auto) + u_auto_pack * u_auto;
			}
			ivec4 t_id[2] = { ivec4(control >> uvec4(27u) & uvec4(0x1Fu)),
				ivec4(control >> uvec4(22u) & uvec4(0x1Fu)) };
			ivec2 texture_ids[4] = ivec2[4](
				ivec2(t_id[0].x, t_id[1].x),
				ivec2(t_id[0].y, t_id[1].y),
				ivec2(t_id[0].z, t_id[1].z),
				ivec2(t_id[0].w, t_id[1].w));
			vec4 weights_id_1 = vec4(control >> uvec4(14u) & uvec4(0xFFu)) * DIV_255 * weights;
			vec4 weights_id_0 = weights - weights_id_1;
			vec2 t_weights[4] = { vec2(0), vec2(0), vec2(0), vec2(0) };
			for (int i = 0; i < 4; i++) {
				vec2 w_0 = vec2(weights_id_0[i]);
				vec2 w_1 = vec2(weights_id_1[i]);
				ivec2 id_0 = texture_ids[i].xx;
				ivec2 id_1 = texture_ids[i].yy;
				t_weights[0] += fma(w_0, vec2(equal(texture_ids[0], id_0)), w_1 * vec2(equal(texture_ids[0], id_1)));
				t_weights[1] += fma(w_0, vec2(equal(texture_ids[1], id_0)), w_1 * vec2(equal(texture_ids[1], id_1)));
				t_weights[2] += fma(w_0, vec2(equal(texture_ids[2], id_0)), w_1 * vec2(equal(texture_ids[2], id_1)));
				t_weights[3] += fma(w_0, vec2(equal(texture_ids[3], id_0)), w_1 * vec2(equal(texture_ids[3], id_1)));
			}
			uint id_read = 0u;
			vec4 nrm = vec4(0.0, 1.0, 0.0, 1.0);
			uv *= _vertex_spacing;
			for (int i = 0; i < 4; i++) {
				for (int t = 0; t < 2; t++) {
					int id = texture_ids[i][t];
					uint mask = 1u << uint(id);
					if ((id_read & mask) == 0u) {
						id_read |= mask;
						float id_w = t_weights[i][t];
						t3d_sample_detiled(id, uv, base_dd, id_w, sharpness, TBN, v_normal, albedo_height, normal_rough, normal_map_depth, ao_strength, total_weight, nrm);
					}
				}
			}
			float weight_inv = 1.0 / total_weight;
			albedo_height *= weight_inv;
			normal_rough *= weight_inv;
			normal_map_depth *= weight_inv;
			ao_strength *= weight_inv;
		}
	}

	vec3 macrov = vec3(1.);
	if (enable_macro_variation) {
		vec2 uv_macro = UV * _vertex_spacing;
		float noise1 = texture(noise_texture, (uv_macro * noise1_scale * .1 + noise1_offset) * rotate_plane(noise1_angle)).r;
		float noise2 = texture(noise_texture, uv_macro * noise2_scale * .1).r;
		macrov = mix(macro_variation1, vec3(1.), noise1);
		macrov *= mix(macro_variation2, vec3(1.), noise2);
		macrov = mix(vec3(1.0), macrov, clamp(v_normal.y + macro_variation_slope, 0., 1.));
	}
	float roughness = clamp(fma(color_map.a - 0.5, 2.0, normal_rough.a), 0., 1.);
	ALBEDO = albedo_height.rgb * color_map.rgb * macrov;
	ROUGHNESS = roughness;
	SPECULAR = 1. - normal_rough.a;
	NORMAL_MAP = fma(normalize(normal_rough.xzy), vec3(0.5), vec3(0.5));
	NORMAL_MAP_DEPTH = normal_map_depth;
	float ao = (1. - (albedo_height.a * log(2.1 - ao_strength))) * (1. - normal_rough.y);
	AO = clamp(1. - ao * ao_strength, albedo_height.a, 1.0);
	AO_LIGHT_AFFECT = (1.0 - albedo_height.a) * clamp(normal_rough.y, 0., 1.);
}

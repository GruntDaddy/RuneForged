extends Node3D

const _GameState = preload("res://autoload/game_state.gd")
const _PlayerScene: PackedScene = preload("res://entities/characters/player/player.tscn")

const _ORIGIN_SEAFARER := 2
const _LINE_1 := "The north wind takes no prisoners."
const _LINE_2_DEFAULT := "Hold fast — the sea does not forgive."
const _LINE_2_SEAFARER := "You know this rage. The sea still wins."

const _DURATION_SEC := 36.0
## Matches dominant swell in `boujie_ocean.gd` (`height4`, direction 42°).
const _SWELL_DIR_DEG := 42.0
const _PROBE_HALF_LENGTH := 3.8
const _PROBE_HALF_BEAM := 1.9
## Hull origin to waterline (tune in editor if ship sits high/low).
const _SHIP_FLOAT_OFFSET := 1.28
const _WAVE_SCALE_START := 0.8
const _WAVE_SCALE_END := 3.35

@onready var _ship_rig: Node3D = $ShipRig
@onready var _ocean: Node3D = $BoujieOcean
@onready var _deck_anchor: Marker3D = $ShipRig/ShipSailing/DeckPlayerAnchor
@onready var _cutscene_camera: Camera3D = $CutsceneCamera
@onready var _intro_label: Label = $UILayer/Center/IntroLabel
@onready var _world_env: WorldEnvironment = $WorldEnvironment
@onready var _sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var _wind_audio: AudioStreamPlayer = $WindAudio
@onready var _splash_audio: AudioStreamPlayer = $SplashAudio
@onready var _thunder_audio: AudioStreamPlayer = $ThunderAudio
@onready var _lightning_flash: ColorRect = $UILayer/LightningFlash

var _player: CharacterBody3D
var _sky_mat: ShaderMaterial
var _lightning_cooldown := 1.2
var _base_ambient_energy := 0.14
var _elapsed := 0.0
var _line_1_shown := false
var _line_1_hidden := false
var _line_2_shown := false
var _line_2_hidden := false
var _finishing := false
var _env: Environment
var _ship_anchor_xz := Vector2.ZERO
var _smoothed_pitch := 0.0
var _smoothed_roll := 0.0
var _smoothed_ship_y := 0.0
var _swell_forward := Vector3.FORWARD
var _swell_side := Vector3.RIGHT


func _ready() -> void:
	_swell_forward = Vector3(
		sin(deg_to_rad(_SWELL_DIR_DEG)),
		0.0,
		cos(deg_to_rad(_SWELL_DIR_DEG))
	).normalized()
	_swell_side = Vector3(-_swell_forward.z, 0.0, _swell_forward.x)
	_ship_anchor_xz = Vector2(_ship_rig.global_position.x, _ship_rig.global_position.z)
	_smoothed_ship_y = _ship_rig.global_position.y
	_cutscene_camera.current = true
	_intro_label.modulate.a = 0.0
	_intro_label.text = ""
	_setup_storm_environment()
	_setup_player()
	_start_ambience()
	call_deferred("_begin_intro")


func _process(delta: float) -> void:
	if _finishing:
		return
	_elapsed += delta
	_update_ship_wave_motion(delta, _elapsed)
	_update_storm_intensity(_elapsed)
	_update_lightning(delta)
	_update_subtitles(_elapsed)
	if _elapsed >= _DURATION_SEC:
		_finish_intro()


func _setup_storm_environment() -> void:
	_env = _world_env.environment
	if _env == null:
		return
	_env = _env.duplicate()
	_base_ambient_energy = _env.ambient_light_energy
	if _env.sky != null:
		var sky := _env.sky.duplicate()
		if sky.sky_material != null:
			sky.sky_material = sky.sky_material.duplicate()
			if sky.sky_material is ShaderMaterial:
				_sky_mat = sky.sky_material as ShaderMaterial
		_env.sky = sky
	_world_env.environment = _env


func _setup_player() -> void:
	_player = _PlayerScene.instantiate() as CharacterBody3D
	_deck_anchor.add_child(_player)
	_player.position = Vector3.ZERO
	_player.rotation = Vector3.ZERO
	if _player.has_method("set_input_enabled"):
		_player.set_input_enabled(false)
	_player.set_physics_process(false)
	_player.collision_layer = 0
	_player.collision_mask = 0
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs is _GameState:
		var state := gs as _GameState
		var bc: Node = _player.get_node_or_null("BaseCharacter")
		if bc != null and bc.has_method("apply_customization"):
			bc.call("apply_customization", state.head_index, state.shirt_index, state.pants_index)
	for node_name in ["CameraRig", "PlayerHud", "GameMenu", "ModularBuildUi", "GameplayToast", "InteractionPrompt", "Reticle", "RayCast3D"]:
		var n := _player.get_node_or_null(node_name)
		if n != null:
			n.visible = false


func _start_ambience() -> void:
	if _wind_audio.stream != null:
		if not _wind_audio.finished.is_connected(_on_wind_audio_finished):
			_wind_audio.finished.connect(_on_wind_audio_finished)
		_wind_audio.play()
	var tw := create_tween()
	tw.tween_property(_wind_audio, "volume_db", -6.0, 4.0).from(-24.0)


func _on_wind_audio_finished() -> void:
	if _finishing:
		return
	_wind_audio.play()


func _begin_intro() -> void:
	var cam_start := Vector3(14.0, 6.5, 16.0)
	var cam_mid := Vector3(9.0, 4.8, 10.0)
	_cutscene_camera.global_position = _ship_rig.global_position + cam_start
	_cutscene_camera.look_at(_ship_rig.global_position + Vector3(0.0, 2.0, 0.0))
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cutscene_camera, "global_position", _ship_rig.global_position + cam_mid, 10.0)


func _update_ship_wave_motion(delta: float, t: float) -> void:
	var storm_k := clampf((t - 1.5) / 28.0, 0.0, 1.0)
	var wave_scale := lerpf(_WAVE_SCALE_START, _WAVE_SCALE_END, ease(storm_k, 1.35))
	if _ocean != null and _ocean.has_method("set_wave_amplitude_scale"):
		_ocean.call("set_wave_amplitude_scale", wave_scale)

	var center := Vector3(_ship_anchor_xz.x, 0.0, _ship_anchor_xz.y)
	var probe_len := _PROBE_HALF_LENGTH * lerpf(1.0, 1.18, storm_k)
	var probe_beam := _PROBE_HALF_BEAM

	var h_bow := _sample_water_height(center + _swell_forward * probe_len)
	var h_stern := _sample_water_height(center - _swell_forward * probe_len)
	var h_port := _sample_water_height(center + _swell_side * probe_beam)
	var h_starboard := _sample_water_height(center - _swell_side * probe_beam)
	var h_center := _sample_water_height(center)

	# Bow rises on crest first (swell travels along _swell_forward).
	var target_pitch := -atan2(h_bow - h_stern, probe_len * 2.0)
	var target_roll := -atan2(h_port - h_starboard, probe_beam * 2.0)
	var pitch_gain := lerpf(0.55, 1.35, storm_k)
	var roll_gain := lerpf(0.5, 1.25, storm_k)
	target_pitch *= pitch_gain
	target_roll *= roll_gain

	var smooth := clampf(4.5 + storm_k * 5.0, 4.5, 9.5) * delta
	_smoothed_pitch = lerpf(_smoothed_pitch, target_pitch, smooth)
	_smoothed_roll = lerpf(_smoothed_roll, target_roll, smooth)

	var target_y := h_center - _SHIP_FLOAT_OFFSET
	_smoothed_ship_y = lerpf(_smoothed_ship_y, target_y, smooth)
	_ship_rig.global_position = Vector3(_ship_anchor_xz.x, _smoothed_ship_y, _ship_anchor_xz.y)

	var pitch := _smoothed_pitch
	var roll := _smoothed_roll
	if t >= 26.0:
		var cap_t := clampf((t - 26.0) / 10.0, 0.0, 1.0)
		var cap_ease := ease(cap_t, 1.65)
		roll += cap_ease * deg_to_rad(102.0)
		pitch += cap_ease * deg_to_rad(14.0)
	_ship_rig.rotation = Vector3(pitch, 0.0, roll)

	if t >= 26.0:
		var cap_t2 := clampf((t - 26.0) / 10.0, 0.0, 1.0)
		var cam_offset := Vector3(6.0 - cap_t2 * 2.0, 3.5 - cap_t2 * 5.0, 8.0 - cap_t2 * 3.0)
		_cutscene_camera.global_position = _ship_rig.global_position + cam_offset
		_cutscene_camera.look_at(_ship_rig.global_position + Vector3(0.0, 1.5 - cap_t2 * 2.0, 0.0))


func _sample_water_height(world_pos: Vector3) -> float:
	if _ocean != null and _ocean.has_method("get_water_surface_height_at"):
		return float(_ocean.call("get_water_surface_height_at", world_pos))
	return 0.0


func _update_storm_intensity(t: float) -> void:
	var k := clampf((t - 2.0) / 20.0, 0.0, 1.0)
	if _env != null:
		_env.fog_density = lerpf(0.055, 0.125, k)
		_env.fog_light_color = Color(0.14, 0.16, 0.22, 1.0).lerp(Color(0.06, 0.07, 0.11, 1.0), k)
		_env.ambient_light_energy = lerpf(_base_ambient_energy, 0.04, k)
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("cloud_wind_speed", lerpf(0.022, 0.04, k))
		_sky_mat.set_shader_parameter("cloud_coverage", lerpf(0.9, 0.98, k))
	if _sun_light != null:
		_sun_light.light_energy = lerpf(0.22, 0.06, k)


func _update_lightning(delta: float) -> void:
	_lightning_cooldown -= delta
	if _lightning_cooldown > 0.0:
		return
	var storm_k := clampf((_elapsed - 4.0) / 18.0, 0.0, 1.0)
	if storm_k <= 0.0:
		_lightning_cooldown = 0.6
		return
	if randf() < 0.42 * storm_k:
		_trigger_lightning(randf_range(0.5, 1.0))
	else:
		_lightning_cooldown = randf_range(0.9, 2.2)


func _trigger_lightning(strength: float) -> void:
	_lightning_cooldown = randf_range(2.8, 8.5)
	var flash_alpha := lerpf(0.35, 0.85, strength)
	if _lightning_flash != null:
		_lightning_flash.modulate.a = flash_alpha
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(_lightning_flash, "modulate:a", 0.0, randf_range(0.12, 0.28))
	if _sun_light != null:
		_sun_light.light_color = Color(0.75, 0.82, 1.0)
		_sun_light.light_energy = lerpf(1.4, 2.2, strength)
		var tw_light := create_tween()
		tw_light.tween_property(_sun_light, "light_energy", 0.08, randf_range(0.35, 0.7))
		tw_light.tween_callback(func() -> void:
			_sun_light.light_color = Color(0.55, 0.6, 0.72)
		)
	if _env != null:
		var peak_ambient := lerpf(0.22, 0.42, strength)
		_env.ambient_light_color = Color(0.45, 0.5, 0.62)
		_env.ambient_light_energy = peak_ambient
		var tw_amb := create_tween()
		tw_amb.tween_property(_env, "ambient_light_energy", 0.04, randf_range(0.4, 0.85))
		tw_amb.tween_callback(func() -> void:
			_env.ambient_light_color = Color(0.2, 0.22, 0.28)
		)
	if _thunder_audio.stream != null:
		_thunder_audio.volume_db = lerpf(-14.0, -6.0, strength)
		_thunder_audio.pitch_scale = randf_range(0.75, 0.95)
		_thunder_audio.play()


func _update_subtitles(t: float) -> void:
	if not _line_1_shown and t >= 8.0:
		_line_1_shown = true
		_fade_label(_LINE_1, true)
	if _line_1_shown and not _line_1_hidden and t >= 14.0:
		_line_1_hidden = true
		_fade_label("", false)
	if not _line_2_shown and t >= 20.0:
		_line_2_shown = true
		var line_2 := _LINE_2_DEFAULT
		var gs := get_node_or_null("/root/GameState")
		if gs != null and gs is _GameState and (gs as _GameState).origin_id == _ORIGIN_SEAFARER:
			line_2 = _LINE_2_SEAFARER
		_fade_label(line_2, true)
	if _line_2_shown and not _line_2_hidden and t >= 27.0:
		_line_2_hidden = true
		_fade_label("", false)


func _fade_label(text: String, show_in: bool) -> void:
	_intro_label.text = text
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if show_in:
		tw.tween_property(_intro_label, "modulate:a", 1.0, 1.2)
	else:
		tw.tween_property(_intro_label, "modulate:a", 0.0, 1.0)


func _finish_intro() -> void:
	if _finishing:
		return
	_finishing = true
	if _splash_audio.stream != null:
		_splash_audio.play()
	var gs := get_node_or_null("/root/GameState")
	if gs != null and gs is _GameState:
		(gs as _GameState).pending_shore_wake = true
	await get_tree().create_timer(0.6).timeout
	await SceneManager.fade_to_scene(_GameState.OVERWORLD_SCENE_PATH)


extends Node

## Central one-shots, menu/world music, and shared combat streams.
## BGM: duplicate stream → assign → play(), with fade-out before swaps and fade-in on new tracks.

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

const _SFX_3D_POOL_SIZE := 12

const _PATH_BGM_MENU_WAV := "res://assets/audio/Rise of the Dark Lord (LOOP) 24bit.wav"
const _PATH_BGM_CREATOR_WAV := "res://assets/audio/Tranquil Hamlet (LOOP) 24bit.wav"
const _PATH_BGM_WORLD_WAV := "res://assets/audio/The New Kingdom (LOOP) 24bit.wav"

const _PATH_BGM_MENU_MP3 := "res://assets/audio/Rise of the Dark Lord.mp3"
const _PATH_BGM_CREATOR_MP3 := "res://assets/audio/Tranquil Hamlet.mp3"
const _PATH_BGM_WORLD_MP3 := "res://assets/audio/The New Kingdom.mp3"

const _PATH_BGM_FALLBACK_MP3 := "res://assets/audio/Campfire Loop.mp3"

const _PATH_UI_SWITCH := "res://assets/audio/sfx/UI Audio/Audio/switch22.ogg"
const _PATH_UI_CONFIRM := "res://assets/audio/sfx/UI Audio/Audio/switch29.ogg"
const _PATH_UI_TAB := "res://assets/audio/sfx/Interface Sounds/Audio/switch_003.ogg"
const _PATH_BOOK_OPEN := "res://assets/audio/sfx/RPG Audio/Audio/bookOpen.ogg"
const _PATH_BOOK_CLOSE := "res://assets/audio/sfx/RPG Audio/Audio/bookClose.ogg"
const _PATH_BOOK_FLIP := "res://assets/audio/sfx/RPG Audio/Audio/bookFlip2.ogg"

const _PATH_BOW_RELEASE := "res://assets/audio/sfx/Impact Sounds/Audio/impactGeneric_light_000.ogg"
const _PATH_SPELL_CAST := "res://assets/audio/sfx/Impact Sounds/Audio/impactBell_heavy_001.ogg"
const _PATH_MELEE_DEFAULT_HIT := "res://assets/audio/sfx/Impact Sounds/Audio/impactMetal_medium_001.ogg"

const _PATH_BEAST_ROAR := "res://assets/audio/Beast Fury Roar.mp3"

const MUSIC_FADE_OUT_SEC := 0.35
const MUSIC_FADE_IN_SEC := 0.5
const SPLASH_AUDIO_FADE_IN_SEC := 2.0

const _SILENCE_DB := -80.0

var _music: AudioStreamPlayer
var _music_fade_tween: Tween
var _ui_players: Array[AudioStreamPlayer] = []

var _sfx_3d_anchor: Node3D
var _sfx_3d_pool: Array[AudioStreamPlayer3D] = []
var _sfx_3d_i: int = 0

var _music_track_key: String = ""
var _last_scene_path_seen: String = ""
var _last_applied_music_scene: String = ""

var _snd_ui_switch: AudioStream
var _snd_ui_confirm: AudioStream
var _snd_ui_tab: AudioStream
var _snd_book_open: AudioStream
var _snd_book_close: AudioStream
var _snd_book_flip: AudioStream
var _snd_bow: AudioStream
var _snd_spell: AudioStream
var _snd_melee_default: AudioStream
var _snd_beast_roar: AudioStream
## MP3 loop fallback when only 24-bit WAV exists (WAV often silent at runtime; export OGG/MP3 per track).
var _snd_bgm_fallback: AudioStream


func _try_load_stream(path: String, label: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("GameAudio: missing %s — %s" % [label, path])
		return null
	var res: Resource = load(path)
	if res is AudioStream:
		return res as AudioStream
	push_warning("GameAudio: not an AudioStream for %s — %s" % [label, path])
	return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_snd_ui_switch = _try_load_stream(_PATH_UI_SWITCH, "UI hover")
	_snd_ui_confirm = _try_load_stream(_PATH_UI_CONFIRM, "UI confirm")
	_snd_ui_tab = _try_load_stream(_PATH_UI_TAB, "UI tab")
	_snd_book_open = _try_load_stream(_PATH_BOOK_OPEN, "book open")
	_snd_book_close = _try_load_stream(_PATH_BOOK_CLOSE, "book close")
	_snd_book_flip = _try_load_stream(_PATH_BOOK_FLIP, "book flip")
	_snd_bow = _try_load_stream(_PATH_BOW_RELEASE, "bow release")
	_snd_spell = _try_load_stream(_PATH_SPELL_CAST, "spell cast")
	_snd_melee_default = _try_load_stream(_PATH_MELEE_DEFAULT_HIT, "melee hit")
	_snd_beast_roar = _try_load_stream(_PATH_BEAST_ROAR, "beast roar")
	_snd_bgm_fallback = _try_load_stream(_PATH_BGM_FALLBACK_MP3, "BGM fallback (Campfire)")
	_music = AudioStreamPlayer.new()
	# Same routing as other gameplay audio; splash roar uses this node successfully.
	_music.bus = "Master"
	_music.volume_db = -3.0
	add_child(_music)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_UI
		add_child(p)
		_ui_players.append(p)
	_sfx_3d_anchor = Node3D.new()
	_sfx_3d_anchor.name = "Sfx3DPoolAnchor"
	add_child(_sfx_3d_anchor)
	for i in _SFX_3D_POOL_SIZE:
		var s3 := AudioStreamPlayer3D.new()
		s3.bus = BUS_SFX
		s3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		_sfx_3d_anchor.add_child(s3)
		_sfx_3d_pool.append(s3)


func _process(_delta: float) -> void:
	var sc: Node = get_tree().current_scene
	if sc == null:
		return
	var path := String(sc.scene_file_path).replace("\\", "/")
	if path.is_empty():
		return
	if path == _last_scene_path_seen:
		return
	_last_scene_path_seen = path
	apply_music_for_scene_path(path)


func default_melee_impact_sound() -> AudioStream:
	return _snd_melee_default


func apply_music_for_scene_path(scene_path: String) -> void:
	var p := scene_path.replace("\\", "/")
	if p.is_empty():
		return
	if p == _last_applied_music_scene and _music != null and _music.playing:
		return
	if p.contains("splash_boot"):
		_begin_music_transition(func():
			_play_splash_roar_faded()
			_last_applied_music_scene = p
		)
		return
	var mp3_path := ""
	var wav_path := ""
	var track_key := "default"
	var vol := -5.0
	if p.contains("main_menu") or p.contains("options_menu"):
		mp3_path = _PATH_BGM_MENU_MP3
		wav_path = _PATH_BGM_MENU_WAV
		track_key = "menu"
	elif p.contains("character_creator"):
		mp3_path = _PATH_BGM_CREATOR_MP3
		wav_path = _PATH_BGM_CREATOR_WAV
		track_key = "creator"
	elif p.contains("world/regions") or p.contains("jorvik"):
		mp3_path = _PATH_BGM_WORLD_MP3
		wav_path = _PATH_BGM_WORLD_WAV
		track_key = "world"
	else:
		mp3_path = _PATH_BGM_WORLD_MP3
		wav_path = _PATH_BGM_WORLD_WAV
		track_key = "world_fallback"
	var base_stream: AudioStream = _load_bgm_resource(mp3_path, wav_path)
	if base_stream == null or _stream_seems_invalid(base_stream):
		base_stream = _snd_bgm_fallback
	if base_stream == null:
		push_warning("GameAudio: no BGM stream available for \"%s\"." % track_key)
		return
	_begin_music_transition(func():
		_play_loop_music_faded(base_stream, vol, track_key)
		_last_applied_music_scene = p
	)


func _kill_music_fade() -> void:
	if _music_fade_tween != null:
		_music_fade_tween.kill()
		_music_fade_tween = null


func _begin_music_transition(on_swapped: Callable) -> void:
	_kill_music_fade()
	if _music == null:
		on_swapped.call()
		return
	if not _music.playing:
		on_swapped.call()
		return
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music, "volume_db", _SILENCE_DB, MUSIC_FADE_OUT_SEC)
	_music_fade_tween.tween_callback(on_swapped)


func _fade_in_music_current(target_db: float, duration_sec: float) -> void:
	_kill_music_fade()
	if _music == null:
		return
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music, "volume_db", target_db, duration_sec)


func _stream_seems_invalid(s: AudioStream) -> bool:
	if s == null:
		return true
	return s.get_length() <= 0.001


func _load_bgm_resource(mp3_path: String, wav_path: String) -> AudioStream:
	if ResourceLoader.exists(mp3_path):
		var m: AudioStream = load(mp3_path) as AudioStream
		if m != null and not _stream_seems_invalid(m):
			return m
	var ogg_path := wav_path.trim_suffix(".wav") + ".ogg"
	if ResourceLoader.exists(ogg_path):
		var ogg: AudioStream = load(ogg_path) as AudioStream
		if ogg != null and not _stream_seems_invalid(ogg):
			return ogg
	if ResourceLoader.exists(wav_path):
		var w: AudioStream = load(wav_path) as AudioStream
		if w != null and not _stream_seems_invalid(w):
			return w
	push_warning("GameAudio: no MP3/OGG/WAV for %s; using Campfire MP3." % wav_path.get_file())
	return _snd_bgm_fallback


func _make_loop_stream(base_stream: AudioStream, track_key: String) -> AudioStream:
	if base_stream == null:
		push_warning("GameAudio: no BGM resource for \"%s\"." % track_key)
		return null
	var effective: AudioStream = base_stream
	if effective is AudioStreamWAV:
		if _snd_bgm_fallback != null:
			push_warning(
				"GameAudio: WAV loop skipped for \"%s\" — add an OGG or MP3 next to the WAV (same basename) or under optional paths in game_audio.gd."
				% track_key
			)
			effective = _snd_bgm_fallback
		else:
			push_warning("GameAudio: WAV loop unusable and no Campfire fallback.")
			return null
	var s: AudioStream = effective.duplicate()
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return s


func _play_loop_music_faded(base_stream: AudioStream, volume_db: float, track_key: String) -> void:
	if _music == null:
		return
	var s: AudioStream = _make_loop_stream(base_stream, track_key)
	if s == null:
		return
	_music.stop()
	_music.stream = s
	_music.volume_db = _SILENCE_DB
	_music_track_key = track_key
	_music.play()
	_fade_in_music_current(volume_db, MUSIC_FADE_IN_SEC)


func _play_splash_roar_faded() -> void:
	if _music == null:
		return
	if _snd_beast_roar == null:
		push_warning("GameAudio: Beast Fury Roar mp3 missing.")
		return
	var roar: AudioStream = _snd_beast_roar.duplicate()
	if roar is AudioStreamMP3:
		(roar as AudioStreamMP3).loop = false
	const target_db := -2.0
	_music.stop()
	_music.stream = roar
	_music.volume_db = _SILENCE_DB
	_music_track_key = "splash_roar"
	_music.play()
	_fade_in_music_current(target_db, SPLASH_AUDIO_FADE_IN_SEC)


func stop_music() -> void:
	_kill_music_fade()
	if _music != null and _music.playing:
		_music.stop()
	_music_track_key = ""
	_last_applied_music_scene = ""


func play_ui_hover() -> void:
	_play_ui(_snd_ui_switch, -12.0)


func play_ui_confirm() -> void:
	_play_ui(_snd_ui_confirm, -8.0)


func play_ui_tab_change() -> void:
	_play_ui(_snd_ui_tab, -10.0)


func play_book_open() -> void:
	_play_ui(_snd_book_open, -6.0)


func play_book_close() -> void:
	_play_ui(_snd_book_close, -6.0)


func play_book_page_flip() -> void:
	_play_ui(_snd_book_flip, -10.0)


func play_bow_release(world_position: Vector3, volume_db: float = -4.0) -> void:
	play_sfx_3d(_snd_bow, world_position, volume_db, 28.0)


func play_spell_cast(world_position: Vector3, volume_db: float = -3.0) -> void:
	play_sfx_3d(_snd_spell, world_position, volume_db, 32.0)


func play_creature_aggressive_roar(world_position: Vector3, volume_db: float = -2.0) -> void:
	play_sfx_3d(_snd_beast_roar, world_position, volume_db, 38.0)


func play_sfx_3d(stream: AudioStream, world_position: Vector3, volume_db: float = 0.0, max_distance: float = 24.0) -> void:
	if stream == null:
		return
	if _sfx_3d_pool.is_empty():
		return
	var p: AudioStreamPlayer3D = _sfx_3d_pool[_sfx_3d_i]
	_sfx_3d_i = (_sfx_3d_i + 1) % _sfx_3d_pool.size()
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.global_position = world_position
	p.play()


func _play_ui(stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	for player in _ui_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return
	var steal: AudioStreamPlayer = _ui_players[0]
	steal.stop()
	steal.stream = stream
	steal.volume_db = volume_db
	steal.play()

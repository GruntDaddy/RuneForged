extends Node

## Central one-shots, menu/world music, and shared combat streams.
## BGM uses the same AudioStreamPlayer path as the splash roar: duplicate stream → assign → play().

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

const _PATH_UI_SWITCH := "res://assets/sfx/UI Audio/Audio/switch22.ogg"
const _PATH_UI_CONFIRM := "res://assets/sfx/UI Audio/Audio/switch29.ogg"
const _PATH_UI_TAB := "res://assets/sfx/Interface Sounds/Audio/switch_003.ogg"
const _PATH_BOOK_OPEN := "res://assets/sfx/RPG Audio/Audio/bookOpen.ogg"
const _PATH_BOOK_CLOSE := "res://assets/sfx/RPG Audio/Audio/bookClose.ogg"
const _PATH_BOOK_FLIP := "res://assets/sfx/RPG Audio/Audio/bookFlip2.ogg"

const _PATH_BOW_RELEASE := "res://assets/sfx/Impact Sounds/Audio/impactGeneric_light_000.ogg"
const _PATH_SPELL_CAST := "res://assets/sfx/Impact Sounds/Audio/impactBell_heavy_001.ogg"
const _PATH_MELEE_DEFAULT_HIT := "res://assets/sfx/Impact Sounds/Audio/impactMetal_medium_001.ogg"

const _PATH_BEAST_ROAR := "res://assets/audio/Beast Fury Roar.mp3"

var _music: AudioStreamPlayer
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
## Preloaded like splash roar so loop BGM uses the same resource path/cache as one-shots.
var _snd_bgm_menu: AudioStream
var _snd_bgm_creator: AudioStream
var _snd_bgm_world: AudioStream
var _snd_bgm_fallback: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_snd_ui_switch = load(_PATH_UI_SWITCH) as AudioStream
	_snd_ui_confirm = load(_PATH_UI_CONFIRM) as AudioStream
	_snd_ui_tab = load(_PATH_UI_TAB) as AudioStream
	_snd_book_open = load(_PATH_BOOK_OPEN) as AudioStream
	_snd_book_close = load(_PATH_BOOK_CLOSE) as AudioStream
	_snd_book_flip = load(_PATH_BOOK_FLIP) as AudioStream
	_snd_bow = load(_PATH_BOW_RELEASE) as AudioStream
	_snd_spell = load(_PATH_SPELL_CAST) as AudioStream
	_snd_melee_default = load(_PATH_MELEE_DEFAULT_HIT) as AudioStream
	_snd_beast_roar = load(_PATH_BEAST_ROAR) as AudioStream
	_snd_bgm_menu = load(_PATH_BGM_MENU_WAV) as AudioStream
	_snd_bgm_creator = load(_PATH_BGM_CREATOR_WAV) as AudioStream
	_snd_bgm_world = load(_PATH_BGM_WORLD_WAV) as AudioStream
	_snd_bgm_fallback = load(_PATH_BGM_FALLBACK_MP3) as AudioStream
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
		_play_splash_roar()
		_last_applied_music_scene = p
		return
	var mp3_path := ""
	var wav_path := ""
	var preferred: AudioStream = null
	var track_key := "default"
	var vol := -5.0
	if p.contains("main_menu") or p.contains("options_menu"):
		mp3_path = _PATH_BGM_MENU_MP3
		wav_path = _PATH_BGM_MENU_WAV
		preferred = _snd_bgm_menu
		track_key = "menu"
	elif p.contains("character_creator"):
		mp3_path = _PATH_BGM_CREATOR_MP3
		wav_path = _PATH_BGM_CREATOR_WAV
		preferred = _snd_bgm_creator
		track_key = "creator"
	elif p.contains("world/regions") or p.contains("tutorial_isle"):
		mp3_path = _PATH_BGM_WORLD_MP3
		wav_path = _PATH_BGM_WORLD_WAV
		preferred = _snd_bgm_world
		track_key = "world"
	else:
		mp3_path = _PATH_BGM_WORLD_MP3
		wav_path = _PATH_BGM_WORLD_WAV
		preferred = _snd_bgm_world
		track_key = "world_fallback"
	var base_stream: AudioStream = null
	if preferred != null and not _stream_seems_invalid(preferred):
		base_stream = preferred
	else:
		base_stream = _load_bgm_resource(mp3_path, wav_path)
	if base_stream == null or _stream_seems_invalid(base_stream):
		base_stream = _snd_bgm_fallback
	if base_stream == null:
		push_warning("GameAudio: no BGM stream available for \"%s\"." % track_key)
		return
	_play_loop_music_splash_style(base_stream, vol, track_key)
	_last_applied_music_scene = p


func _stream_seems_invalid(s: AudioStream) -> bool:
	if s == null:
		return true
	return s.get_length() <= 0.001


func _load_bgm_resource(mp3_path: String, wav_path: String) -> AudioStream:
	if ResourceLoader.exists(mp3_path):
		var m: AudioStream = load(mp3_path) as AudioStream
		if m != null and not _stream_seems_invalid(m):
			return m
	var w: AudioStream = load(wav_path) as AudioStream
	if w != null and not _stream_seems_invalid(w):
		return w
	push_warning("GameAudio: optional MP3 / WAV missing or invalid (%s); trying Campfire MP3." % wav_path.get_file())
	return _snd_bgm_fallback


## Same pattern as `_play_splash_roar`: duplicate → assign `_music.stream` → `play()`.
func _play_loop_music_splash_style(base_stream: AudioStream, volume_db: float, track_key: String) -> void:
	if _music == null:
		return
	if base_stream == null:
		push_warning("GameAudio: no BGM resource for \"%s\"." % track_key)
		return
	var s: AudioStream = base_stream.duplicate()
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music.stop()
	_music.stream = s
	_music.volume_db = volume_db
	_music_track_key = track_key
	_music.play()


func _play_splash_roar() -> void:
	if _music == null:
		return
	if _snd_beast_roar == null:
		push_warning("GameAudio: Beast Fury Roar mp3 missing.")
		return
	var roar: AudioStream = _snd_beast_roar.duplicate()
	if roar is AudioStreamMP3:
		(roar as AudioStreamMP3).loop = false
	_music.stop()
	_music.stream = roar
	_music.volume_db = -2.0
	_music_track_key = "splash_roar"
	_music.play()


func stop_music() -> void:
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

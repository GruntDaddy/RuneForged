extends Node

## Central one-shots, menu/world music, and shared combat streams.
## Expects `res://default_bus_layout.tres`: Master → Music, SFX, UI (all send to Master).

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

const _SFX_3D_POOL_SIZE := 12

const _PATH_MUSIC_MENU := "res://assets/audio/Tranquil Hamlet (LOOP) 24bit.wav"
const _PATH_MUSIC_CREATOR := "res://assets/audio/Noble Quest (LOOP) 24bit.wav"
const _PATH_MUSIC_WORLD := "res://assets/audio/Wayfarer (LOOP) 24bit.wav"
const _PATH_MUSIC_BOOT := "res://assets/audio/Sanctuary (LOOP) 24bit.wav"

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

var _music_menu: AudioStream
var _music_creator: AudioStream
var _music_world: AudioStream
var _music_boot: AudioStream
var _music_track_key: String = ""

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_menu = _load_stream_loop(_PATH_MUSIC_MENU)
	_music_creator = _load_stream_loop(_PATH_MUSIC_CREATOR)
	_music_world = _load_stream_loop(_PATH_MUSIC_WORLD)
	_music_boot = _load_stream_loop(_PATH_MUSIC_BOOT)
	_warn_if_null(_music_menu, _PATH_MUSIC_MENU)
	_warn_if_null(_music_creator, _PATH_MUSIC_CREATOR)
	_warn_if_null(_music_world, _PATH_MUSIC_WORLD)
	_warn_if_null(_music_boot, _PATH_MUSIC_BOOT)
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
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	_music.volume_db = -4.0
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


func _warn_if_null(stream: AudioStream, path: String) -> void:
	if stream == null:
		push_warning("GameAudio: failed to load music stream: %s" % path)


func default_melee_impact_sound() -> AudioStream:
	return _snd_melee_default


func apply_music_for_scene_path(scene_path: String) -> void:
	var p := scene_path.replace("\\", "/")
	var track_key := "default"
	var stream: AudioStream = _music_world
	var vol := -5.0
	if p.contains("splash_boot"):
		track_key = "boot"
		stream = _music_boot
		vol = -6.0
	elif p.contains("main_menu") or p.contains("options_menu"):
		track_key = "menu"
		stream = _music_menu
		vol = -5.0
	elif p.contains("character_creator"):
		track_key = "creator"
		stream = _music_creator
		vol = -5.0
	elif p.contains("world/regions") or p.contains("tutorial_isle"):
		track_key = "world"
		stream = _music_world
		vol = -5.0
	_play_music_stream(stream, vol, track_key)


func stop_music() -> void:
	if _music != null and _music.playing:
		_music.stop()
	_music_track_key = ""


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


func _play_music_stream(stream: AudioStream, volume_db: float, track_key: String) -> void:
	if stream == null or _music == null:
		return
	if _music_track_key == track_key and _music.playing:
		_music.volume_db = volume_db
		return
	_music.stop()
	_music.stream = stream
	_music.volume_db = volume_db
	_music_track_key = track_key
	_music.play()


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


func _load_stream_loop(path: String) -> AudioStream:
	var s: AudioStream = load(path) as AudioStream
	if s == null:
		return null
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif s is AudioStreamMP3:
		var m := s as AudioStreamMP3
		m.loop = true
	return s

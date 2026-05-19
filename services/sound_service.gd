class_name SoundService
extends Node

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_paused_by_game_pause: bool = false
var _sfx_paused_by_game_pause: bool = false

# key → res:// path; add entries here as you source audio files
const SOUNDS: Dictionary = {
	# Farming
	"till":         "res://assets/audio/farming/till.ogg",
	"water":        "res://assets/audio/sfx/farming/water.ogg",
	"plant":        "res://assets/audio/sfx/farming/plant.ogg",
	"harvest":      "res://assets/audio/sfx/farming/harvest.ogg",
	# Combat
	"sword_swing":  "res://assets/audio/sfx/combat/sword_swing.ogg",
	"zombie_death": "res://assets/audio/sfx/combat/zombie_death.ogg",
	# UI
	"ui_open":      "res://assets/audio/sfx/ui/open.ogg",
	"ui_close":     "res://assets/audio/sfx/ui/close.ogg",
	# Music
	"music_day":    "res://assets/audio/music/day_theme.ogg",
	"music_night":  "res://assets/audio/music/night_theme.ogg",
}

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	EventBus.player_tilled.connect(_on_player_tilled)
	EventBus.player_watered.connect(_on_player_watered)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.player_attack_started.connect(_on_player_attack_started)
	EventBus.zombie_died.connect(_on_zombie_died)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.trade_opened.connect(_on_trade_opened)
	EventBus.trade_closed.connect(_on_trade_closed)
	EventBus.inventory_opened.connect(_on_inventory_opened)
	EventBus.inventory_closed.connect(_on_inventory_closed)


func _on_player_tilled(_tile_pos: Vector2i) -> void:
	play_sfx("till")

func _on_player_watered(_tile_pos: Vector2i) -> void:
	play_sfx("water")

func _on_crop_harvested(_tile_pos: Vector2i, _crop_type) -> void:
	play_sfx("harvest")

func _on_player_attack_started(_dmg, _dir, _origin) -> void:
	play_sfx("sword_swing")

func _on_zombie_died(_zombie: Node) -> void:
	play_sfx("zombie_death")

func _on_day_phase_changed(is_night: bool) -> void:
	play_music("music_night" if is_night else "music_day")

func _on_trade_opened() -> void:
	play_sfx("ui_open")

func _on_trade_closed() -> void:
	play_sfx("ui_close")

func _on_inventory_opened() -> void:
	play_sfx("ui_open")

func _on_inventory_closed() -> void:
	play_sfx("ui_close")


func play_sfx(key: String) -> void:
	if not SOUNDS.has(key):
		return
	var stream: AudioStream = load(SOUNDS[key])
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()

func play_music(key: String) -> void:
	if not SOUNDS.has(key):
		return
	var stream: AudioStream = load(SOUNDS[key])
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()


func pause_audio() -> void:
	if _music_player and _music_player.playing and not _music_player.stream_paused:
		_music_player.stream_paused = true
		_music_paused_by_game_pause = true
	if _sfx_player and _sfx_player.playing and not _sfx_player.stream_paused:
		_sfx_player.stream_paused = true
		_sfx_paused_by_game_pause = true


func resume_audio() -> void:
	if _music_player and _music_paused_by_game_pause:
		_music_player.stream_paused = false
	if _sfx_player and _sfx_paused_by_game_pause:
		_sfx_player.stream_paused = false
	_music_paused_by_game_pause = false
	_sfx_paused_by_game_pause = false

func set_sfx_volume(linear: float) -> void:
	_sfx_player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0))

func set_music_volume(linear: float) -> void:
	_music_player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0))

class_name SoundService
extends Node

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_paused_by_game_pause: bool = false
var _sfx_paused_by_game_pause: bool = false
var _last_player_hp: float = 100.0
var _footstep_timer: float = 0.0
const _FOOTSTEP_COOLDOWN: float = 0.35

const SOUNDS: Dictionary = {
	# Farming
	"till":           "res://assets/audio/sfx/farming/till.ogg",
	"plant":          "res://assets/audio/sfx/farming/plant.ogg",
	"water":          "res://assets/audio/sfx/farming/water.ogg",
	"harvest":        "res://assets/audio/sfx/farming/harve.ogg",
	"crop_grown":     "res://assets/audio/sfx/farming/crop_grown.ogg",
	# Combat
	"sword_swing":    "res://assets/audio/sfx/combat/sword-swing.ogg",
	"zombie_death":   "res://assets/audio/sfx/combat/zombie-gethit.ogg",
	"player_hurt":    "res://assets/audio/sfx/combat/human-gethit.ogg",
	# UI
	"ui_open":        "res://assets/audio/sfx/ui/open.ogg",
	"ui_close":       "res://assets/audio/sfx/ui/close.ogg",
	"buy":            "res://assets/audio/sfx/trading/trade.ogg",
	# World
	"walk_grass":     "res://assets/audio/sfx/world/walk-grass.ogg",
	# Story
	"tribute_paid":   "res://assets/audio/sfx/story/tribute_paid.ogg",
	"tribute_failed": "res://assets/audio/sfx/story/tribute_failed.ogg",
	# Music
	"music_main_menu": "res://assets/audio/music/main-menu.ogg",
	"music_day":       "res://assets/audio/music/day.ogg",
	"music_night":     "res://assets/audio/music/night.ogg",
	"music_boss":      "res://assets/audio/music/boss.ogg",
	"music_victory":   "res://assets/audio/music/victory_theme.ogg",
}

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	# Farming
	EventBus.player_tilled.connect(_on_player_tilled)
	EventBus.player_watered.connect(_on_player_watered)
	EventBus.crop_planted.connect(_on_crop_planted)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.crop_grown.connect(_on_crop_grown)
	# Combat
	EventBus.player_attack_started.connect(_on_player_attack_started)
	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.zombie_died.connect(_on_zombie_died)
	# UI
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.trade_opened.connect(_on_trade_opened)
	EventBus.trade_closed.connect(_on_trade_closed)
	EventBus.inventory_opened.connect(_on_inventory_opened)
	EventBus.inventory_closed.connect(_on_inventory_closed)
	EventBus.seeds_purchased.connect(_on_seeds_purchased)
	# World
	EventBus.player_position_changed.connect(_on_player_position_changed)
	# Story
	EventBus.tribute_paid.connect(_on_tribute_paid_sfx)
	EventBus.tribute_failed.connect(_on_tribute_failed)
	EventBus.final_boss_started.connect(_on_final_boss_started)
	EventBus.game_won.connect(_on_game_won)

	_load_volumes()


func _process(delta: float) -> void:
	if _footstep_timer > 0.0:
		_footstep_timer -= delta


# ── World ─────────────────────────────────────────────────────────────────────

func _on_player_position_changed(_position: Vector2) -> void:
	if _footstep_timer <= 0.0:
		play_sfx("walk_grass")
		_footstep_timer = _FOOTSTEP_COOLDOWN


# ── Farming ───────────────────────────────────────────────────────────────────

func _on_player_tilled(_tile_pos: Vector2i) -> void:
	play_sfx("till")

func _on_player_watered(_tile_pos: Vector2i) -> void:
	play_sfx("water")

func _on_crop_planted(_tile_pos: Vector2i, _crop_type) -> void:
	play_sfx("plant")

func _on_crop_harvested(_tile_pos: Vector2i, _crop_type) -> void:
	play_sfx("harvest")

func _on_crop_grown(_tile_pos: Vector2i, _stage: int, _max_stages: int) -> void:
	play_sfx("crop_grown")


# ── Combat ────────────────────────────────────────────────────────────────────

func _on_player_attack_started(_dmg, _dir, _origin) -> void:
	play_sfx("sword_swing")

func _on_player_hp_changed(current: float, _max_hp: float) -> void:
	if current < _last_player_hp:
		play_sfx("player_hurt")
	_last_player_hp = current

func _on_zombie_died(_zombie: Node) -> void:
	play_sfx("zombie_death")


# ── UI ────────────────────────────────────────────────────────────────────────

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

func _on_seeds_purchased(_crop_type) -> void:
	play_sfx("buy")


# ── Story ─────────────────────────────────────────────────────────────────────

func _on_tribute_paid_sfx(_index: int) -> void:
	play_sfx("tribute_paid")

func _on_tribute_failed(_message: String) -> void:
	play_sfx("tribute_failed")

func _on_final_boss_started(_message: String) -> void:
	play_music("music_boss")

func _on_game_won(_message: String) -> void:
	play_music("music_victory")


# ── Playback ──────────────────────────────────────────────────────────────────

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
	_save_volumes()

func set_music_volume(linear: float) -> void:
	_music_player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0))
	_save_volumes()

func get_sfx_volume() -> float:
	return db_to_linear(_sfx_player.volume_db)

func get_music_volume() -> float:
	return db_to_linear(_music_player.volume_db)

func _save_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", get_sfx_volume())
	cfg.set_value("audio", "music", get_music_volume())
	cfg.save("user://settings.cfg")

func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	set_sfx_volume(cfg.get_value("audio", "sfx", 1.0))
	set_music_volume(cfg.get_value("audio", "music", 1.0))

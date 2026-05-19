class_name Bed
extends Node2D

const INTERACT_RADIUS: float = 20.0
const SLEEP_OVERLAY_PATH: String = "res://ui/menus/sleep_overlay.tscn"

var _player_in_range: bool = false
var _hint_label: Label
var _sleeping: bool = false


func _ready() -> void:
	_build_hint()
	z_index = int(global_position.y)


func _build_hint() -> void:
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 6)
	_hint_label.position = Vector2(-40, -22)
	_hint_label.size = Vector2(80, 20)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	add_child(_hint_label)


func _process(_delta: float) -> void:
	var player_svc := EventBus.services.player as PlayerService
	if not player_svc or not player_svc.has_player():
		return
	var dist: float = global_position.distance_to(player_svc.get_position())
	_player_in_range = dist <= INTERACT_RADIUS
	if _player_in_range:
		var is_night := _is_night()
		var can_sleep := is_night and _count_alive_zombies() == 0
		_hint_label.text = "[E] Sleep" if can_sleep else "[E] Bed"
		_hint_label.visible = true
	else:
		_hint_label.visible = false


func _input(event: InputEvent) -> void:
	if _sleeping or not _player_in_range or EventBus.dialogue_open:
		return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_try_sleep()


func _try_sleep() -> void:
	if not _is_night():
		EventBus.dialogue_requested.emit("Bed", "You can only sleep at night.")
		return
	if _count_alive_zombies() > 0:
		EventBus.dialogue_requested.emit("Bed", "You cannot sleep while there are enemies nearby.")
		return
	var tribute_svc := EventBus.services.tribute as TributeService
	if tribute_svc and not tribute_svc.can_sleep():
		EventBus.dialogue_requested.emit("Bed", tribute_svc.get_sleep_block_message())
		return
	_start_sleep_sequence()


func _is_night() -> bool:
	var day_svc := EventBus.services.day_cycle as DayCycleService
	return day_svc != null and day_svc.is_night


func _count_alive_zombies() -> int:
	return get_tree().get_nodes_in_group("zombies").size()


func _start_sleep_sequence() -> void:
	var save_svc := EventBus.services.save as SaveService
	var day_svc := EventBus.services.day_cycle as DayCycleService
	if not save_svc or not day_svc:
		push_error("Bed: SaveService/DayCycleService unavailable")
		return
	var slot: int = save_svc.active_slot
	if slot <= 0:
		push_error("Bed: no active slot")
		return

	_sleeping = true
	_hint_label.visible = false

	var current_day: int = day_svc.current_day
	var overlay_scene := load(SLEEP_OVERLAY_PATH) as PackedScene
	if overlay_scene == null:
		push_error("Bed: could not load SleepOverlay")
		_sleeping = false
		return
	var overlay := overlay_scene.instantiate() as CanvasLayer
	get_tree().root.add_child(overlay)

	var save_only := func() -> void:
		save_svc.save_day(slot, current_day)

	overlay.completed.connect(_on_sleep_completed)
	overlay.play_sleep_sequence(current_day, save_only)


func _on_sleep_completed() -> void:
	_sleeping = false

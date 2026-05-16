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
	var in_range: bool = dist <= INTERACT_RADIUS
	_player_in_range = in_range
	if in_range:
		_hint_label.text = "[E] Sleep" if _can_sleep() else "Cannot\nsleep now"
		_hint_label.visible = true
	else:
		_hint_label.visible = false


func _input(event: InputEvent) -> void:
	if _sleeping or not _player_in_range or EventBus.dialogue_open:
		return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if not _can_sleep():
			_show_blocked_message()
			return
		_start_sleep_sequence()


func _can_sleep() -> bool:
	var tribute_svc := EventBus.services.tribute as TributeService
	return tribute_svc == null or tribute_svc.can_sleep()


func _show_blocked_message() -> void:
	var tribute_svc := EventBus.services.tribute as TributeService
	var message: String = tribute_svc.get_sleep_block_message() if tribute_svc else "You cannot sleep now."
	EventBus.dialogue_requested.emit("Bed", message)


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

	var next_day: int = day_svc.current_day + 1
	var overlay_scene: PackedScene = load(SLEEP_OVERLAY_PATH) as PackedScene
	if overlay_scene == null:
		push_error("Bed: could not load SleepOverlay")
		_sleeping = false
		return
	var overlay: CanvasLayer = overlay_scene.instantiate() as CanvasLayer
	get_tree().root.add_child(overlay)

	var save_and_advance := func() -> void:
		save_svc.save_day(slot, next_day)
		day_svc.start_cycle(next_day)
		EventBus.night_skipped.emit(next_day)

	overlay.completed.connect(_on_sleep_completed)
	overlay.play_sleep_sequence(next_day, save_and_advance)


func _on_sleep_completed() -> void:
	_sleeping = false

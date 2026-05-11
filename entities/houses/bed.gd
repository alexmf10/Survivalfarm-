## Cama del jugador. Interactuable con E cuando el jugador está cerca.
## Solo permite dormir DE NOCHE. De día muestra mensaje informativo.
##
## Al dormir:
##   1. Lanza SleepOverlay (fade negro tipo Minecraft, ~3s)
##   2. Durante el negro: guarda el día actual+1 + arranca el siguiente ciclo
##   3. Tras el fade-in muestra modal "Partida guardada" con botón Aceptar
##   4. Emite EventBus.night_skipped(new_day)
##
## Patrón calcado del Trader (proximidad por distancia, sin Area2D).
class_name Bed
extends Node2D

const INTERACT_RADIUS: float = 20.0
const SLEEP_OVERLAY_PATH: String = "res://ui/menus/sleep_overlay.tscn"

var _player_in_range: bool = false
var _hint_label: Label
var _sleeping: bool = false


func _ready() -> void:
	_build_hint()
	# z_index para depth-sort: el jugador queda delante/detrás según posición Y
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
		_hint_label.text = "[E] Sleep" if _is_night() else "Solo puedes\ndormir de noche"
		_hint_label.visible = true
	else:
		_hint_label.visible = false


func _input(event: InputEvent) -> void:
	if _sleeping:
		return
	if not _player_in_range:
		return
	if not _is_night():
		return  # No se puede dormir de día
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_start_sleep_sequence()


func _is_night() -> bool:
	var day_svc := EventBus.services.day_cycle as DayCycleService
	return day_svc != null and day_svc.is_night


func _start_sleep_sequence() -> void:
	var save_svc := EventBus.services.save as SaveService
	var day_svc := EventBus.services.day_cycle as DayCycleService
	if not save_svc or not day_svc:
		push_error("Bed: SaveService/DayCycleService no disponibles")
		return
	var slot: int = save_svc.active_slot
	if slot <= 0:
		push_error("Bed: no hay slot activo")
		return

	_sleeping = true
	_hint_label.visible = false

	var next_day: int = day_svc.current_day + 1

	# Cargar overlay y añadirlo al árbol
	var overlay_scene: PackedScene = load(SLEEP_OVERLAY_PATH) as PackedScene
	if overlay_scene == null:
		push_error("Bed: no se pudo cargar SleepOverlay")
		_sleeping = false
		return
	var overlay: CanvasLayer = overlay_scene.instantiate() as CanvasLayer
	get_tree().root.add_child(overlay)

	# Callback que se ejecuta cuando la pantalla está negra
	var save_and_advance := func() -> void:
		save_svc.save_day(slot, next_day)
		day_svc.start_cycle(next_day)
		if EventBus.has_signal("night_skipped"):
			EventBus.emit_signal("night_skipped", next_day)

	overlay.completed.connect(_on_sleep_completed)
	overlay.play_sleep_sequence(next_day, save_and_advance)


func _on_sleep_completed() -> void:
	_sleeping = false

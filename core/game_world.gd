## Escena de juego temporal (placeholder). Muestra un fondo con el HUD del ciclo
## día/noche activo. Sirve como punto de integración hasta que se implemente
## el mundo completo.
##
## Arquitectura
## - Carga la escena DayCycleHUD y la añade como hijo (CanvasLayer).
## - Obtiene DayCycleService del ServiceLocator para arrancar el ciclo.
## - Lee el día guardado del slot activo usando SaveService.get_day().
## - Escucha EventBus.day_started para guardar el día automáticamente.
## - Al pulsar ESC (input "pause") guarda y cierra la aplicación.
##
## Conexiones
## - Recibe: EventBus.day_started → para auto-guardar el día
## - Usa: EventBus.services.day_cycle → DayCycleService.start_cycle()
## - Usa: EventBus.services.save → SaveService.get_day() / save_day()
class_name GameWorld
extends Control

## Slot activo (se establece antes de cambiar a esta escena).
## Se configura desde slots_screen.gd vía 'active_slot' del SaveService.
var active_slot: int = 1


func _ready() -> void:
	# Leer el slot activo desde SaveService (puesto por slots_screen)
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		active_slot = save_svc.active_slot
	_build_ui()

	# Instanciar el HUD del ciclo día/noche
	var hud_scene: PackedScene = load("res://ui/hud/day_cycle_hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	add_child(hud)

	# Arrancar el ciclo con el día guardado
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc and save_svc:
		var saved_day: int = save_svc.get_day(active_slot)
		day_cycle_svc.start_cycle(saved_day)

	# Escuchar cuando avanza el día para auto-guardar
	EventBus.day_started.connect(_on_day_started)


func _exit_tree() -> void:
	# Pausar el ciclo al salir y desconectar señal
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		day_cycle_svc.pause()
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func _build_ui() -> void:
	# Fondo verde (placeholder del mundo)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.25, 0.45, 0.20)  # Verde campo
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Etiqueta central informativa
	var info_label: Label = Label.new()
	info_label.text = "Game World (placeholder)\nPress ESC to return"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.set_anchors_preset(Control.PRESET_CENTER)
	info_label.add_theme_font_size_override("font_size", 8)
	info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8, 0.5))
	add_child(info_label)


## Cuando avanza el día, guardar automáticamente en el slot activo.
func _on_day_started(day_number: int) -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc:
		save_svc.save_day(active_slot, day_number)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Guardar y salir
		var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
		if day_cycle_svc:
			var save_svc: SaveService = EventBus.services.save as SaveService
			if save_svc:
				save_svc.save_day(active_slot, day_cycle_svc.current_day)
			day_cycle_svc.pause()
		get_tree().change_scene_to_file("res://ui/menus/slots_screen.tscn")

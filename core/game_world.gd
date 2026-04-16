## Escena de juego. Contiene el mundo (tilemap + player) y el HUD del ciclo
## día/noche. Gestiona la integración con los servicios del juego.
##
## Arquitectura
## - El mundo visual se carga desde test_scene_tilemap.tscn (instanciado en .tscn).
## - Carga la escena DayCycleHUD y la añade como hijo (CanvasLayer).
## - Obtiene DayCycleService del ServiceLocator para arrancar el ciclo.
## - Lee el día guardado del slot activo usando SaveService.get_day().
## - Escucha EventBus.day_started para guardar el día automáticamente.
## - Al pulsar ESC (input "pause") guarda y vuelve a SlotsScreen.
##
## Conexiones
## - Recibe: EventBus.day_started → para auto-guardar el día
## - Usa: EventBus.services.day_cycle → DayCycleService.start_cycle()
## - Usa: EventBus.services.save → SaveService.get_day() / save_day()
class_name GameWorld
extends Node2D

## Slot activo (se establece antes de cambiar a esta escena).
## Se configura desde slots_screen.gd vía 'active_slot' del SaveService.
var active_slot: int = 1


func _ready() -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		active_slot = save_svc.active_slot

	var hud_scene: PackedScene = load("res://ui/hud/day_cycle_hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	add_child(hud)

	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc and save_svc:
		var saved_day: int = save_svc.get_day(active_slot)
		day_cycle_svc.start_cycle(saved_day)

	EventBus.day_started.connect(_on_day_started)


func _exit_tree() -> void:
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		day_cycle_svc.pause()
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


## Cuando avanza el día, guardar automáticamente en el slot activo.
func _on_day_started(day_number: int) -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc:
		save_svc.save_day(active_slot, day_number)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
		if day_cycle_svc:
			var save_svc: SaveService = EventBus.services.save as SaveService
			if save_svc:
				save_svc.save_day(active_slot, day_cycle_svc.current_day)
			day_cycle_svc.pause()
		get_tree().change_scene_to_file("res://ui/menus/slots_screen.tscn")

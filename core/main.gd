## Escena raíz Bootstrap (punto de entrada de la aplicación al iniciar).
## Aquí se registrarán los servicios en el ServiceLocator.
##
## Servicios registrados:
## "profile"   → ProfileService (byRef) — logros por slot
## "save"      → SaveService (byRef) — gestión de slots de guardado
## "day_cycle" → DayCycleService (Node) — ciclo día/noche
## "input"     → GameInputService (byRef) — lectura de entrada del jugador
extends Node


func _ready() -> void:
	# Servicio de entrada del jugador
	var input_svc: GameInputService = GameInputService.new()
	EventBus.services.register(&"input", input_svc)

	# Servicio del perfil
	var profile_svc: ProfileService = ProfileService.new()
	EventBus.services.register(&"profile", profile_svc)

	# Servicio del guardado
	var save_svc: SaveService = SaveService.new()
	EventBus.services.register(&"save", save_svc)

	# DayCycleService es Node → necesita ser hijo del árbol para _process()
	var day_cycle_svc: DayCycleService = DayCycleService.new()
	day_cycle_svc.name = "DayCycleService"
	EventBus.add_child(day_cycle_svc)
	EventBus.services.register(&"day_cycle", day_cycle_svc)

	# Ir al menú principal 
	get_tree().call_deferred("change_scene_to_file", "res://ui/menus/main_menu.tscn")

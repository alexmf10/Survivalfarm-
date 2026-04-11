## Escena raíz Bootstrap (punto de entrada de la aplicación al iniciar).
## Aquí se registrarán los servicios en el ServiceLocator.
##
## Servicios registrados:
## "profile" → ProfileService (byRef) — logros por slot
## "save"    → SaveService (byRef) — gestión de slots de guardado
extends Node


func _ready() -> void:
	# Servicio del perfil
	var profile_svc: ProfileService = ProfileService.new()
	EventBus.services.register(&"profile", profile_svc)

	# Servicio del guardado
	var save_svc: SaveService = SaveService.new()
	EventBus.services.register(&"save", save_svc)

	# Ir al menú principal 
	get_tree().call_deferred("change_scene_to_file", "res://ui/menus/main_menu.tscn")

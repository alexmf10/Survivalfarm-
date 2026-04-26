## Escena raíz Bootstrap (punto de entrada de la aplicación al iniciar).
## Aquí se registrarán los servicios en el ServiceLocator.
##
## Servicios registrados:
## "profile"   → ProfileService (byRef) — logros por slot
## "save"      → SaveService (byRef) — gestión de slots de guardado
## "day_cycle"  → DayCycleService (Node) — ciclo día/noche
## "player"    → PlayerService (byRef) — directorio del jugador activo
## "crop"      → CropService (byRef) — estado de cultivos
## "farm"      → FarmService (Node) — visuales de cultivos
extends Node


func _ready() -> void:
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

	# PlayerService: directorio fino del jugador activo (RefCounted).
	var player_svc: PlayerService = PlayerService.new()
	EventBus.services.register(&"player", player_svc)

	# CropService: gestiona el estado de los cultivos (arar, plantar, regar, cosechar).
	var crop_svc: CropService = CropService.new()
	crop_svc.connect_signals()
	crop_svc.register_crop(preload("res://data/definition/wheat.tres"))
	crop_svc.register_crop(preload("res://data/definition/beet.tres"))
	EventBus.services.register(&"crop", crop_svc)

	# FarmService: gestiona los visuales del sistema de cultivos (Node, necesita árbol).
	var farm_svc: FarmService = FarmService.new()
	farm_svc.name = "FarmService"
	EventBus.add_child(farm_svc)
	EventBus.services.register(&"farm", farm_svc)

	# TradeService: gestiona inventario del jugador y lógica de compraventa.
	var trade_svc: TradeService = TradeService.new()
	trade_svc.connect_signals()
	EventBus.services.register(&"trade", trade_svc)

	# Ir al menú principal
	get_tree().call_deferred("change_scene_to_file", "res://ui/menus/main_menu.tscn")

## Bus de eventos global (Autoload). Canal central de comunicación.
## Los actores y servicios emiten señales aquí; la UI las escucha sin conocer al emisor.
## También aloja el ServiceLocator para acceso global a servicios.
## Registra todos los servicios en _ready() para que estén disponibles
## independientemente de qué escena se ejecute primero.
##
## Conexiones:
## - ProfileService emite: achievement_unlocked
## - UI screens emiten/escuchan: screen_change_requested, profile_updated
## - DayCycleService emite: day_phase_changed, day_started, time_tick
## - DayCycleHUD escucha: day_phase_changed, day_started, time_tick
extends Node

# Señales globales
signal achievement_unlocked(achievement_id: String)
signal profile_updated()
signal screen_change_requested(screen_name: String)

# Señales del ciclo día/noche
## Emitida por DayCycleService cuando la fase cambia.
## Escuchada por DayCycleHUD.
signal day_phase_changed(is_night: bool)

## Emitida por DayCycleService al inicio de cada nuevo día (cuando termina la noche).
## Escuchada por DayCycleHUD para actualizar el contador.
signal day_started(day_number: int)

## Emitida por DayCycleService cada segundo mientras el reloj corre.
## Escuchada por DayCycleHUD para actualizar la barra de progreso y etiquetas.
signal time_tick(day_number: int, elapsed: float, phase: String)

## Señales de acciones del jugador sobre el mundo (emitidas por player states)
signal player_tilled(world_pos: Vector2, direction: Vector2)
signal player_watered(world_pos: Vector2, direction: Vector2)
signal player_planted(world_pos: Vector2, direction: Vector2, crop_type: CropComponent.CropType)
signal player_harvest_attempted(world_pos: Vector2, direction: Vector2)

## Señales de estado de cultivos (emitidas por CropService)
signal tile_tilled(tile_pos: Vector2i)
signal crop_planted(tile_pos: Vector2i, crop_type: CropComponent.CropType)
signal crop_watered(tile_pos: Vector2i)
signal crop_grown(tile_pos: Vector2i, new_stage: int, max_stages: int)
signal crop_harvested(tile_pos: Vector2i, crop_type: CropComponent.CropType)

# Registro de servicios compartidos.
var services: ServiceLocator = ServiceLocator.new()


func _ready() -> void:
	var input_svc: GameInputService = GameInputService.new()
	services.register(&"input", input_svc)

	var crop_svc: CropService = CropService.new()
	crop_svc.connect_signals()
	crop_svc.register_crop(preload("res://data/definition/wheat.tres"))
	crop_svc.register_crop(preload("res://data/definition/beet.tres"))
	services.register(&"crop", crop_svc)

	var profile_svc: ProfileService = ProfileService.new()
	services.register(&"profile", profile_svc)

	var save_svc: SaveService = SaveService.new()
	services.register(&"save", save_svc)

	var day_cycle_svc: DayCycleService = DayCycleService.new()
	day_cycle_svc.name = "DayCycleService"
	add_child(day_cycle_svc)
	services.register(&"day_cycle", day_cycle_svc)

	var farm_svc: FarmService = FarmService.new()
	farm_svc.name = "FarmService"
	add_child(farm_svc)
	services.register(&"farm", farm_svc)

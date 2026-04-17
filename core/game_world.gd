## Escena de juego. Contiene el mundo (tilemap + player) y el HUD del ciclo
## día/noche. Gestiona la integración con los servicios del juego.
##
## Arquitectura
## - El mundo visual se carga desde test_scene_tilemap.tscn (instanciado en .tscn).
## - Carga la escena DayCycleHUD y la añade como hijo (CanvasLayer).
## - Obtiene DayCycleService del ServiceLocator para arrancar el ciclo.
## - Lee el día guardado del slot activo usando SaveService.get_day().
## - Escucha EventBus.day_started para guardar el día automáticamente.
## - Inyecta TilledDirt TileMapLayer en CropService y escucha señales de cultivo.
## - Al pulsar ESC (input "pause") guarda y vuelve a SlotsScreen.
##
## Conexiones
## - Recibe: EventBus.day_started → para auto-guardar el día
## - Recibe: EventBus.tile_tilled / crop_planted / crop_grown / crop_harvested → actualiza visuals
## - Usa: EventBus.services.day_cycle → DayCycleService.start_cycle()
## - Usa: EventBus.services.save → SaveService.get_day() / save_day()
## - Usa: EventBus.services.crop → CropService.set_tilled_layer()
class_name GameWorld
extends Node2D

## Slot activo (se establece antes de cambiar a esta escena).
## Se configura desde slots_screen.gd vía 'active_slot' del SaveService.
var active_slot: int = 1

var _tilled_layer: TileMapLayer
var _crop_entities: Dictionary = {}  # Vector2i → CropEntity


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

	# Inyectar TileMapLayer en CropService y conectar señales de cultivo
	_tilled_layer = $World/GameTileMap/TilledDirt
	var crop_svc: CropService = EventBus.services.crop as CropService
	if crop_svc:
		crop_svc.set_tilled_layer(_tilled_layer)

	EventBus.tile_tilled.connect(_on_tile_tilled)
	EventBus.crop_planted.connect(_on_crop_planted)
	EventBus.crop_grown.connect(_on_crop_grown)
	EventBus.crop_harvested.connect(_on_crop_harvested)


func _exit_tree() -> void:
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		day_cycle_svc.pause()
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)

	var crop_svc: CropService = EventBus.services.crop as CropService
	if crop_svc:
		crop_svc.set_tilled_layer(null)

	if EventBus.tile_tilled.is_connected(_on_tile_tilled):
		EventBus.tile_tilled.disconnect(_on_tile_tilled)
	if EventBus.crop_planted.is_connected(_on_crop_planted):
		EventBus.crop_planted.disconnect(_on_crop_planted)
	if EventBus.crop_grown.is_connected(_on_crop_grown):
		EventBus.crop_grown.disconnect(_on_crop_grown)
	if EventBus.crop_harvested.is_connected(_on_crop_harvested):
		EventBus.crop_harvested.disconnect(_on_crop_harvested)


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


## Actualiza el TileMap de tierra arada cuando CropService confirma un tile nuevo.
## TODO: reemplaza SOURCE_ID y ATLAS_COORDS con los valores reales del game_tile_set.tres
func _on_tile_tilled(tile_pos: Vector2i) -> void:
	pass  # _tilled_layer.set_cell(tile_pos, SOURCE_ID, ATLAS_COORDS)


## Instancia una entidad visual de cultivo en el tile plantado.
func _on_crop_planted(tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	var crop := CropEntity.new()
	$World.add_child(crop)
	crop.global_position = _tilled_layer.to_global(_tilled_layer.map_to_local(tile_pos))
	crop.setup(crop_type, CropService.CROP_MAX_STAGES.get(crop_type, 4))
	_crop_entities[tile_pos] = crop


## Avanza el sprite del cultivo a la nueva etapa de crecimiento.
func _on_crop_grown(tile_pos: Vector2i, new_stage: int, _max_stages: int) -> void:
	if _crop_entities.has(tile_pos):
		(_crop_entities[tile_pos] as CropEntity).advance_stage(new_stage)


## Elimina la entidad visual del cultivo cosechado.
func _on_crop_harvested(tile_pos: Vector2i, _crop_type: CropComponent.CropType) -> void:
	if _crop_entities.has(tile_pos):
		_crop_entities[tile_pos].queue_free()
		_crop_entities.erase(tile_pos)

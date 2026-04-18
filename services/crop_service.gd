## Gestiona el estado de los cultivos: tiles arados, cultivos plantados y crecimiento.
## Escucha acciones del jugador vía EventBus y emite señales de resultado para que
## la escena visual (GameWorld) actualice el TileMap y las entidades de cultivo.
class_name CropService
extends RefCounted

## Resources por tipo de cultivo — registrar desde EventBus._ready() con register_crop()
var _crop_data: Dictionary = {}  # CropType → CropComponent


func register_crop(data: CropComponent) -> void:
	_crop_data[data.crop_type] = data


func get_crop_data(crop_type: CropComponent.CropType) -> CropComponent:
	return _crop_data.get(crop_type)

## Estado interno de un cultivo plantado
class CropState:
	var crop_type: CropComponent.CropType
	var stage: int = 0
	var watered: bool = false
	var max_stages: int

	func _init(type: CropComponent.CropType, max_s: int) -> void:
		crop_type = type
		max_stages = max_s

var _tilled_layer: TileMapLayer          # inyectado por GameWorld en _ready()
var _tilled_tiles: Dictionary = {}       # Vector2i → bool
var _crops: Dictionary = {}             # Vector2i → CropState


## Conecta las señales de EventBus. Llamado desde main.gd al registrar el servicio.
func connect_signals() -> void:
	EventBus.player_tilled.connect(_on_player_tilled)
	EventBus.player_watered.connect(_on_player_watered)
	EventBus.player_planted.connect(_on_player_planted)
	EventBus.player_harvest_attempted.connect(_on_player_harvest_attempted)
	EventBus.day_started.connect(_on_day_started)


## Inyecta el TileMapLayer necesario para conversión de coordenadas.
## Llamado desde GameWorld._ready() cuando la escena está lista.
func set_tilled_layer(layer: TileMapLayer) -> void:
	_tilled_layer = layer
	for tile: Vector2i in layer.get_used_cells():
		_tilled_tiles[tile] = true


## Convierte posición mundial + dirección al tile objetivo frente al jugador.
func _world_to_target_tile(world_pos: Vector2, direction: Vector2) -> Vector2i:
	var ts: int = _tilled_layer.tile_set.tile_size.x
	var target: Vector2 = world_pos + direction * ts
	return _tilled_layer.local_to_map(_tilled_layer.to_local(target))


func _on_player_tilled(world_pos: Vector2, direction: Vector2) -> void:
	if not _tilled_layer:
		return
	var tile: Vector2i = _world_to_target_tile(world_pos, direction)
	if _tilled_tiles.get(tile, false):
		return  # ya estaba arado
	_tilled_tiles[tile] = true
	EventBus.tile_tilled.emit(tile)


func _on_player_planted(world_pos: Vector2, direction: Vector2, crop_type: CropComponent.CropType) -> void:
	if not _tilled_layer:
		return
	var tile: Vector2i = _world_to_target_tile(world_pos, direction)
	if not _tilled_tiles.get(tile, false):
		return  # no se puede plantar en tierra sin arar
	if _crops.has(tile):
		return  # tile ya ocupado
	var res: CropComponent = _crop_data.get(crop_type)
	var max_s: int = res.max_stages if res else 4
	_crops[tile] = CropState.new(crop_type, max_s)
	EventBus.crop_planted.emit(tile, crop_type)


func _on_player_watered(world_pos: Vector2, direction: Vector2) -> void:
	if not _tilled_layer:
		return
	var tile: Vector2i = _world_to_target_tile(world_pos, direction)
	if not _crops.has(tile):
		return
	var crop: CropState = _crops[tile]
	if crop.stage >= crop.max_stages - 1:
		return  # ya está completamente crecido
	crop.watered = true
	EventBus.crop_watered.emit(tile)


func _on_player_harvest_attempted(world_pos: Vector2, direction: Vector2) -> void:
	if not _tilled_layer:
		return
	var tile: Vector2i = _world_to_target_tile(world_pos, direction)
	if not _crops.has(tile):
		return
	var crop: CropState = _crops[tile]
	if crop.stage < crop.max_stages - 1:
		return  # aún no está listo para cosechar
	var crop_type: CropComponent.CropType = crop.crop_type
	_crops.erase(tile)
	EventBus.crop_harvested.emit(tile, crop_type)


## Avanza el crecimiento de los cultivos regados al inicio de cada nuevo día.
func _on_day_started(_day_number: int) -> void:
	for tile: Vector2i in _crops:
		var crop: CropState = _crops[tile]
		if crop.watered and crop.stage < crop.max_stages - 1:
			crop.stage += 1
			crop.watered = false
			EventBus.crop_grown.emit(tile, crop.stage, crop.max_stages)

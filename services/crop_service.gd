## Gestiona el estado de los cultivos: tiles arados, cultivos plantados y crecimiento.
## Escucha acciones del jugador vía EventBus y emite señales de resultado para que
## FarmService actualice los visuales (TileMap, CropEntity, partículas).
##
## --- Flujo del sistema de cultivos ---
## 1. El mapa tiene tiles de tierra arada pre-colocados (TilledDirt layer).
##    Estos tiles son las parcelas de cultivo válidas.
## 2. El jugador también puede arar nuevos tiles de hierba (azadón + clic).
## 3. El jugador planta semillas en tiles de tierra arada vacíos.
## 4. El jugador riega los cultivos plantados.
## 5. Al inicio de cada nuevo día, los cultivos regados crecen un stage.
## 6. Cuando un cultivo alcanza su max_stages, está listo para cosechar (tecla E).
class_name CropService
extends RefCounted

## Resources por tipo de cultivo — registrar desde main.gd con register_crop()
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

var _tilled_layer: TileMapLayer          # inyectado por FarmService
var _tilled_tiles: Dictionary = {}       # Vector2i → bool  (tiles de tierra arada válidos)
var _tillable_area: Dictionary = {}      # Vector2i → bool  (zona donde SE PUEDE arar — clarito)
var _crops: Dictionary = {}             # Vector2i → CropState


## Conecta las señales de EventBus. Llamado desde main.gd al registrar el servicio.
func connect_signals() -> void:
	EventBus.player_tilled.connect(_on_player_tilled)
	EventBus.player_watered.connect(_on_player_watered)
	EventBus.player_planted.connect(_on_player_planted)
	EventBus.player_harvest_attempted.connect(_on_player_harvest_attempted)
	EventBus.day_started.connect(_on_day_started)


## Inyecta el TileMapLayer necesario.
## Llamado desde FarmService cuando descubre la capa.
## Registra todos los tiles existentes como tiles arados válidos y como
## zona aratable permitida (los dos bloques 3x3 de "clarito" pre-colocados).
func set_tilled_layer(layer: TileMapLayer) -> void:
	_tilled_layer = layer
	_tilled_tiles.clear()
	_tillable_area.clear()


func set_tillable_area(positions: Array[Vector2i]) -> void:
	_tillable_area.clear()
	for pos: Vector2i in positions:
		_tillable_area[pos] = true
		_tilled_tiles[pos] = true


## Comprueba si un tile tiene un cultivo plantado.
func has_crop(tile_pos: Vector2i) -> bool:
	return _crops.has(tile_pos)


## Comprueba si un tile es tierra arada válida.
func is_tilled(tile_pos: Vector2i) -> bool:
	return _tilled_tiles.get(tile_pos, false)


## Comprueba si un tile está dentro de la zona aratable designada
## (los bloques 3x3 de "clarito" que vienen pre-marcados en el mapa).
## Solo estos tiles permiten la acción de arar con la azada.
func is_tillable_area(tile_pos: Vector2i) -> bool:
	return _tillable_area.get(tile_pos, false)


func _on_player_tilled(tile_pos: Vector2i) -> void:
	if _tilled_tiles.get(tile_pos, false):
		return  # ya estaba arado
	_tilled_tiles[tile_pos] = true
	EventBus.tile_tilled.emit(tile_pos)


func _on_player_planted(tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	if not _tilled_tiles.get(tile_pos, false):
		return
	if _crops.has(tile_pos):
		return
	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc and not trade_svc.consume_seed(crop_type):
		return
	var res: CropComponent = _crop_data.get(crop_type)
	var max_s: int = res.max_stages if res else 4
	_crops[tile_pos] = CropState.new(crop_type, max_s)
	EventBus.crop_planted.emit(tile_pos, crop_type)


func _on_player_watered(tile_pos: Vector2i) -> void:
	if not _crops.has(tile_pos):
		return
	var crop: CropState = _crops[tile_pos]
	if crop.stage >= crop.max_stages - 1:
		return  # ya está completamente crecido
	crop.watered = true
	EventBus.crop_watered.emit(tile_pos)


func _on_player_harvest_attempted(tile_pos: Vector2i) -> void:
	if not _crops.has(tile_pos):
		return
	var crop: CropState = _crops[tile_pos]
	if crop.stage < crop.max_stages - 1:
		return  # aún no está listo para cosechar
	var crop_type: CropComponent.CropType = crop.crop_type
	_crops.erase(tile_pos)
	EventBus.crop_harvested.emit(tile_pos, crop_type)


func water_all() -> void:
	for tile: Vector2i in _crops:
		var crop: CropState = _crops[tile]
		if crop.stage < crop.max_stages - 1:
			crop.watered = true
			EventBus.crop_watered.emit(tile)


## Avanza el crecimiento de los cultivos regados al inicio de cada nuevo día.
func _on_day_started(_day_number: int) -> void:
	for tile: Vector2i in _crops:
		var crop: CropState = _crops[tile]
		if crop.watered and crop.stage < crop.max_stages - 1:
			crop.stage += 1
			crop.watered = false
			EventBus.crop_grown.emit(tile, crop.stage, crop.max_stages)


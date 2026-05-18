class_name CropService
extends RefCounted

var _crop_data: Dictionary = {}


class CropState:
	var crop_type: CropComponent.CropType
	var stage: int = 0
	var watered: bool = false
	var max_stages: int

	func _init(type: CropComponent.CropType, max_s: int) -> void:
		crop_type = type
		max_stages = max_s


var _tilled_layer: TileMapLayer
var _tilled_tiles: Dictionary = {}
var _tillable_area: Dictionary = {}
var _crops: Dictionary = {}
var _loading_state: bool = false
var _pending_save_state: Dictionary = {}


func register_crop(data: CropComponent) -> void:
	_crop_data[data.crop_type] = data


func get_crop_data(crop_type: CropComponent.CropType) -> CropComponent:
	return _crop_data.get(crop_type)


func connect_signals() -> void:
	EventBus.player_tilled.connect(_on_player_tilled)
	EventBus.player_watered.connect(_on_player_watered)
	EventBus.player_planted.connect(_on_player_planted)
	EventBus.player_harvest_attempted.connect(_on_player_harvest_attempted)
	EventBus.day_started.connect(_on_day_started)


func set_tilled_layer(layer: TileMapLayer) -> void:
	_tilled_layer = layer
	_tilled_tiles.clear()
	_tillable_area.clear()


func set_tillable_area(positions: Array[Vector2i]) -> void:
	_tillable_area.clear()
	for pos: Vector2i in positions:
		_tillable_area[pos] = true
		_tilled_tiles[pos] = true
	if not _pending_save_state.is_empty():
		_restore_save_state(_pending_save_state)
		_pending_save_state = {}


func has_crop(tile_pos: Vector2i) -> bool:
	return _crops.has(tile_pos)


func can_plant(tile_pos: Vector2i) -> bool:
	return _tilled_tiles.get(tile_pos, false) and not _crops.has(tile_pos)


func can_water(tile_pos: Vector2i) -> bool:
	if not _crops.has(tile_pos):
		return false
	var crop: CropState = _crops[tile_pos]
	return crop.stage < crop.max_stages - 1 and not crop.watered


func can_harvest(tile_pos: Vector2i) -> bool:
	if not _crops.has(tile_pos):
		return false
	var crop: CropState = _crops[tile_pos]
	return crop.stage >= crop.max_stages - 1


func is_tilled(tile_pos: Vector2i) -> bool:
	return _tilled_tiles.get(tile_pos, false)


func is_tillable_area(tile_pos: Vector2i) -> bool:
	return _tillable_area.get(tile_pos, false)


func apply_save_state(state: Dictionary) -> void:
	if _tillable_area.is_empty():
		_pending_save_state = state.duplicate(true)
		return
	_restore_save_state(state)


func get_save_state() -> Dictionary:
	var crops: Array = []
	for tile: Vector2i in _crops:
		var crop: CropState = _crops[tile]
		crops.append({
			"x": tile.x,
			"y": tile.y,
			"crop_type": int(crop.crop_type),
			"stage": crop.stage,
			"watered": crop.watered,
			"max_stages": crop.max_stages,
		})
	return {"crops": crops}


func replay_visual_state() -> void:
	for tile: Vector2i in _crops:
		var crop: CropState = _crops[tile]
		EventBus.crop_planted.emit(tile, crop.crop_type)
		if crop.stage > 0:
			EventBus.crop_grown.emit(tile, crop.stage, crop.max_stages)
		if crop.watered:
			EventBus.crop_watered.emit(tile)


func _on_player_tilled(tile_pos: Vector2i) -> void:
	if _tilled_tiles.get(tile_pos, false):
		return
	_tilled_tiles[tile_pos] = true
	EventBus.tile_tilled.emit(tile_pos)
	_save_state()


func _on_player_planted(tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	if not can_plant(tile_pos):
		return
	var res: CropComponent = _crop_data.get(crop_type)
	var max_s: int = res.max_stages if res else 4
	_crops[tile_pos] = CropState.new(crop_type, max_s)
	EventBus.crop_planted.emit(tile_pos, crop_type)
	_save_state()


func _on_player_watered(tile_pos: Vector2i) -> void:
	if not can_water(tile_pos):
		return
	var crop: CropState = _crops[tile_pos]
	crop.watered = true
	EventBus.crop_watered.emit(tile_pos)
	_save_state()


func _on_player_harvest_attempted(tile_pos: Vector2i) -> void:
	if not can_harvest(tile_pos):
		return
	var crop: CropState = _crops[tile_pos]
	var crop_type: CropComponent.CropType = crop.crop_type
	_crops.erase(tile_pos)
	EventBus.crop_harvested.emit(tile_pos, crop_type)
	_save_state()


func water_all() -> void:
	for tile: Vector2i in _crops:
		var crop: CropState = _crops[tile]
		if crop.stage < crop.max_stages - 1:
			crop.watered = true
			EventBus.crop_watered.emit(tile)
	_save_state()


func _on_day_started(_day_number: int) -> void:
	for tile: Vector2i in _crops:
		var crop: CropState = _crops[tile]
		if crop.watered and crop.stage < crop.max_stages - 1:
			crop.stage += 1
			crop.watered = false
			EventBus.crop_grown.emit(tile, crop.stage, crop.max_stages)
	_save_state()


func get_crops_save_data() -> Array:
	var result: Array = []
	for tile_pos: Vector2i in _crops:
		var crop: CropState = _crops[tile_pos]
		result.append({
			"x": tile_pos.x,
			"y": tile_pos.y,
			"crop_type": crop.crop_type,
			"stage": crop.stage,
			"watered": crop.watered,
		})
	return result


func load_crops_save_data(crops_data: Array) -> void:
	_crops.clear()
	for item: Dictionary in crops_data:
		var tile_pos: Vector2i = Vector2i(item.get("x", 0), item.get("y", 0))
		var crop_type: CropComponent.CropType = item.get("crop_type", 0) as CropComponent.CropType
		var res: CropComponent = _crop_data.get(crop_type)
		var max_s: int = res.max_stages if res else 4
		var state: CropState = CropState.new(crop_type, max_s)
		state.stage = item.get("stage", 0)
		state.watered = item.get("watered", false)
		_crops[tile_pos] = state
		EventBus.crop_planted.emit(tile_pos, crop_type)
		if state.stage > 0:
			EventBus.crop_grown.emit(tile_pos, state.stage, max_s)
		if state.watered:
			EventBus.crop_watered.emit(tile_pos)


func _restore_save_state(state: Dictionary) -> void:
	_loading_state = true
	_crops.clear()
	var crops: Array = state.get("crops", [])
	for crop_data in crops:
		if not (crop_data is Dictionary):
			continue
		var tile := Vector2i(int(crop_data.get("x", 0)), int(crop_data.get("y", 0)))
		var crop_type: CropComponent.CropType = int(crop_data.get("crop_type", CropComponent.CropType.Wheat))
		var res: CropComponent = _crop_data.get(crop_type)
		var max_s: int = int(crop_data.get("max_stages", res.max_stages if res else 4))
		var crop := CropState.new(crop_type, max_s)
		crop.stage = clampi(int(crop_data.get("stage", 0)), 0, max_s - 1)
		crop.watered = bool(crop_data.get("watered", false))
		_crops[tile] = crop
		_tilled_tiles[tile] = true
	_loading_state = false
	replay_visual_state()


func _save_state() -> void:
	if _loading_state:
		return
	var save_svc := EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		save_svc.save_crop_state(save_svc.active_slot, get_save_state())

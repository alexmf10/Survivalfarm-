## Gestiona los visuales del sistema de cultivos.
## Descubre automáticamente el TileMapLayer de tierra arada buscando nodos
## en el grupo "farm_tilled_dirt". No necesita script por escena:
## solo añade el TileMapLayer al grupo desde el editor de Godot.
class_name FarmService
extends Node

var _tilled_layer: TileMapLayer
var _crop_entities: Dictionary = {}  # Vector2i → CropEntity


func _enter_tree() -> void:
	# Conectar aquí (síncrono con add_child) garantiza que node_added
	# esté activo antes de que la escena principal entre al árbol.
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


func _ready() -> void:
	EventBus.tile_tilled.connect(_on_tile_tilled)
	EventBus.crop_planted.connect(_on_crop_planted)
	EventBus.crop_grown.connect(_on_crop_grown)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	# Fallback: si la escena ya cargó antes de que _enter_tree corriera,
	# buscar la capa directamente por grupo.
	for node in get_tree().get_nodes_in_group("farm_tilled_dirt"):
		_on_node_added(node)
		break


## Cuando un TileMapLayer del grupo "farm_tilled_dirt" entra al árbol,
## lo registra como capa activa e inyecta la referencia en CropService.
func _on_node_added(node: Node) -> void:
	if node is TileMapLayer and node.is_in_group("farm_tilled_dirt"):
		_tilled_layer = node
		_crop_entities.clear()
		var crop_svc := EventBus.services.crop as CropService
		if crop_svc:
			crop_svc.set_tilled_layer(_tilled_layer)


## Limpia la referencia cuando la capa sale del árbol (cambio de escena).
func _on_node_removed(node: Node) -> void:
	if node == _tilled_layer:
		_tilled_layer = null
		_crop_entities.clear()
		var crop_svc := EventBus.services.crop as CropService
		if crop_svc:
			crop_svc.set_tilled_layer(null)


func _on_tile_tilled(tile_pos: Vector2i) -> void:
	if not _tilled_layer:
		return
	var existing := _tilled_layer.get_used_cells()
	if existing.is_empty():
		return
	var ref := existing[0]
	_tilled_layer.set_cell(
		tile_pos,
		_tilled_layer.get_cell_source_id(ref),
		_tilled_layer.get_cell_atlas_coords(ref)
	)


func _on_crop_planted(tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	if not _tilled_layer:
		return
	var crop := CropEntity.new()
	get_tree().current_scene.add_child(crop)
	crop.global_position = _tilled_layer.to_global(_tilled_layer.map_to_local(tile_pos))
	crop.setup(crop_type, CropService.CROP_MAX_STAGES.get(crop_type, 4))
	_crop_entities[tile_pos] = crop


func _on_crop_grown(tile_pos: Vector2i, new_stage: int, _max_stages: int) -> void:
	if _crop_entities.has(tile_pos):
		(_crop_entities[tile_pos] as CropEntity).advance_stage(new_stage)


func _on_crop_harvested(tile_pos: Vector2i, _crop_type: CropComponent.CropType) -> void:
	if _crop_entities.has(tile_pos):
		_crop_entities[tile_pos].queue_free()
		_crop_entities.erase(tile_pos)

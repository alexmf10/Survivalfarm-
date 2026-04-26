## Gestiona los visuales del sistema de cultivos.
## Descubre automáticamente el TileMapLayer de tierra arada buscando nodos
## en el grupo "farm_tilled_dirt". No necesita script por escena:
## solo añade el TileMapLayer al grupo desde el editor de Godot.
##
## --- Arquitectura del sistema de arado ---
## El TileMapLayer "farm_tilled_dirt" contiene tiles PRE-COLOCADOS que marcan
## las zonas aratables del mapa (el "clarito" — los dos bloques 3x3). Al cargar:
##   1. Guardamos la posición + atlas original de cada tile (por si hay edges).
##   2. Limpiamos esos tiles visualmente (quedan solo como datos).
##   3. Pasamos esas posiciones a CropService como "zona aratable permitida".
## Cuando el jugador ara un tile, re-pintamos el TileMapLayer en esa posición
## usando el atlas que habíamos guardado para respetar el tileset autotile.
##
## --- Responsabilidades visuales ---
## • Pintar el tile arado en el TileMap cuando el jugador ara.
## • Instanciar/destruir CropEntity al plantar/cosechar.
## • Tinte azul sobre el suelo cuando un cultivo está regado.
## • Generar partículas de feedback al arar, regar, plantar y cosechar.
class_name FarmService
extends Node

const CROP_SCENE: PackedScene = preload("res://entities/crops/Crop.tscn")

# Colores de partículas por acción
const PARTICLE_COLOR_TILL: Color = Color(0.55, 0.35, 0.15)      # Marrón tierra
const PARTICLE_COLOR_WATER: Color = Color(0.3, 0.6, 0.9)        # Azul agua
const PARTICLE_COLOR_PLANT: Color = Color(0.35, 0.55, 0.2)      # Verde semilla
const PARTICLE_COLOR_HARVEST: Color = Color(1.0, 0.85, 0.25)    # Amarillo dorado (cosecha)

var _tilled_layer: TileMapLayer
var _crop_entities: Dictionary = {}  # Vector2i → CropEntity
var _watered_overlays: Dictionary = {}  # Vector2i → ColorRect (indicador de riego)

# Datos por posición aratable para poder re-pintar al arar.
# Vector2i → { "source": int, "atlas": Vector2i }
var _tillable_tile_data: Dictionary = {}


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


func _ready() -> void:
	EventBus.tile_tilled.connect(_on_tile_tilled)
	EventBus.crop_planted.connect(_on_crop_planted)
	EventBus.crop_grown.connect(_on_crop_grown)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.crop_watered.connect(_on_crop_watered)
	EventBus.tool_action_performed.connect(_on_tool_action_performed)
	# Fallback: si la escena ya cargó, buscar por grupo.
	for node in get_tree().get_nodes_in_group("farm_tilled_dirt"):
		_on_node_added(node)
		break


func _on_node_added(node: Node) -> void:
	if node is TileMapLayer and node.is_in_group("farm_tilled_dirt"):
		_tilled_layer = node
		_crop_entities.clear()
		_watered_overlays.clear()
		_tillable_tile_data.clear()
		# Snapshot de tiles pre-colocados = zona aratable permitida.
		# Guardamos el atlas de cada uno (respeta autotile 3x3).
		var tillable_positions: Array[Vector2i] = []
		for pos: Vector2i in _tilled_layer.get_used_cells():
			_tillable_tile_data[pos] = {
				"source": _tilled_layer.get_cell_source_id(pos),
				"atlas": _tilled_layer.get_cell_atlas_coords(pos),
			}
			tillable_positions.append(pos)
		# Inyectar estado en CropService
		var crop_svc := EventBus.services.crop as CropService
		if crop_svc:
			crop_svc.set_tilled_layer(_tilled_layer)
			crop_svc.set_tillable_area(tillable_positions)


func _on_node_removed(node: Node) -> void:
	if node == _tilled_layer:
		_tilled_layer = null
		_crop_entities.clear()
		_watered_overlays.clear()
		_tillable_tile_data.clear()
		var crop_svc := EventBus.services.crop as CropService
		if crop_svc:
			crop_svc.set_tilled_layer(null)
			crop_svc.set_tillable_area([] as Array[Vector2i])


func _on_tile_tilled(tile_pos: Vector2i) -> void:
	if not _tilled_layer:
		return
	var data: Dictionary = _tillable_tile_data.get(tile_pos, {})
	if data.is_empty():
		# Tile outside pre-placed area — use the first known tilled tile appearance as fallback
		if _tillable_tile_data.is_empty():
			return
		data = _tillable_tile_data.values()[0]
	_tilled_layer.set_cell(tile_pos, data["source"], data["atlas"])


func _on_crop_planted(tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	if not _tilled_layer:
		return
	var crop_svc := EventBus.services.crop as CropService
	if not crop_svc:
		return
	var data: CropComponent = crop_svc.get_crop_data(crop_type)
	if not data:
		return
	var crop := CROP_SCENE.instantiate() as CropEntity
	get_tree().current_scene.add_child(crop)
	crop.global_position = _tilled_layer.to_global(_tilled_layer.map_to_local(tile_pos))
	crop.setup(data)
	_crop_entities[tile_pos] = crop


func _on_crop_grown(tile_pos: Vector2i, new_stage: int, _max_stages: int) -> void:
	if _crop_entities.has(tile_pos):
		(_crop_entities[tile_pos] as CropEntity).advance_stage(new_stage)
	# Al crecer, ya no está regado — quitar el overlay de riego
	_remove_watered_overlay(tile_pos)


func _on_crop_harvested(tile_pos: Vector2i, _crop_type: CropComponent.CropType) -> void:
	if _crop_entities.has(tile_pos):
		_crop_entities[tile_pos].queue_free()
		_crop_entities.erase(tile_pos)
	_remove_watered_overlay(tile_pos)


func _on_crop_watered(tile_pos: Vector2i) -> void:
	if not _tilled_layer:
		return
	# Indicar visualmente que el cultivo está regado
	if _crop_entities.has(tile_pos):
		(_crop_entities[tile_pos] as CropEntity).set_watered(true)
	# Añadir overlay azul sobre el tile
	if not _watered_overlays.has(tile_pos):
		var overlay: ColorRect = ColorRect.new()
		overlay.color = Color(0.15, 0.2, 0.4, 0.3)  # Tinte azul suave
		overlay.size = Vector2(16, 16)
		var tile_world: Vector2 = _tilled_layer.to_global(_tilled_layer.map_to_local(tile_pos))
		overlay.global_position = tile_world - Vector2(8, 8)  # Centrar en el tile
		overlay.z_index = -1  # Debajo del cultivo
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().current_scene.add_child(overlay)
		_watered_overlays[tile_pos] = overlay


func _remove_watered_overlay(tile_pos: Vector2i) -> void:
	if _watered_overlays.has(tile_pos):
		if is_instance_valid(_watered_overlays[tile_pos]):
			_watered_overlays[tile_pos].queue_free()
		_watered_overlays.erase(tile_pos)


## Genera partículas en la posición del tile según la acción realizada.
func _on_tool_action_performed(tool: ToolsComponent.Tools, tile_pos: Vector2i) -> void:
	if not _tilled_layer:
		return
	var world_pos: Vector2 = _tilled_layer.to_global(_tilled_layer.map_to_local(tile_pos))

	match tool:
		ToolsComponent.Tools.TillGround:
			_spawn_particles(world_pos, PARTICLE_COLOR_TILL, 8, 30.0)
		ToolsComponent.Tools.WaterCrops:
			_spawn_particles(world_pos, PARTICLE_COLOR_WATER, 6, 20.0)
		ToolsComponent.Tools.PlantWheat, ToolsComponent.Tools.PlantBeet:
			_spawn_particles(world_pos, PARTICLE_COLOR_PLANT, 4, 15.0)
		ToolsComponent.Tools.None:
			# Cosechar
			_spawn_particles(world_pos, PARTICLE_COLOR_HARVEST, 10, 35.0)


## Genera partículas simples (cuadraditos de color) en la posición dada.
## Son nodos ligeros que se auto-destruyen tras la animación.
func _spawn_particles(pos: Vector2, color: Color, count: int, spread: float) -> void:
	for i: int in range(count):
		var particle: ColorRect = ColorRect.new()
		particle.color = color
		var particle_size: float = randf_range(1.5, 3.0)
		particle.size = Vector2(particle_size, particle_size)
		particle.global_position = pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		particle.z_index = 10
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().current_scene.add_child(particle)

		# Animar: mover hacia arriba/lados, reducir y desvanecer
		var target_pos: Vector2 = particle.global_position + Vector2(
			randf_range(-spread, spread),
			randf_range(-spread * 1.2, -spread * 0.3)  # Principalmente hacia arriba
		)
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target_pos, randf_range(0.3, 0.6))\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(particle, "modulate:a", 0.0, randf_range(0.4, 0.7))\
			.set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "scale", Vector2(0.1, 0.1), randf_range(0.3, 0.6))\
			.set_ease(Tween.EASE_IN)
		# Auto-destruir tras la animación
		tween.chain().tween_callback(particle.queue_free)

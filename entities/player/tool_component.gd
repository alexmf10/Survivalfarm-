## ToolComponent — Componente de herramientas reutilizable.
##
## Responsabilidad única: gestionar qué herramienta tiene seleccionada el
## jugador y, cuando se usa con clic izquierdo o E, emitir la señal global correspondiente
## al EventBus para que el CropService reaccione.
##
## --- Targeting ---
## • Usa la posición del ratón para encontrar el tile en el TileMapLayer de
##   tierra arada ("farm_tilled_dirt"). Solo acepta acciones sobre tiles que
##   realmente existen en esa capa (cell_source_id != -1).
## • Valida que el tile esté dentro del radio de acción (5 tiles = 80px).
## • Usa map_to_local() + to_global() para obtener la posición central del
##   tile en coordenadas globales y calcular la distancia con precisión.
## • Para ARAR: comprueba que haya hierba bajo el ratón y que todavía no haya
##   tierra arada en ese tile.
##
## --- Controles ---
## • Teclas 1-4: seleccionan la herramienta activa de la Hotbar.
## • Tecla 7: saca/guarda el arma del slot de equipamiento (índice 19).
## • Clic izquierdo: usa herramienta, planta o cosecha el tile bajo el ratón.
## • Mantener clic izquierdo: repite la acción en cada tile distinto que cruza el ratón.
## • Tecla E: intenta cosechar el cultivo del tile bajo el ratón.
##
## --- Resaltado visual ---
## • Cada frame se comprueba si el tile bajo el ratón es válido para la
##   herramienta actual (rango y tipo de tile). Si lo es, se
##   dibuja un borde 16x16 rojo alrededor del tile como feedback.
class_name ToolComponent
extends Node

# ── Señales LOCALES ─────────────────────────────────────────────────────────
## Emitida cuando el jugador cambia de herramienta seleccionada.
signal tool_changed(new_tool: ToolsComponent.Tools)

## Emitida cuando el jugador usa la herramienta activa.
signal tool_used(tool: ToolsComponent.Tools)

# ── Configuración ──────────────────────────────────────────────────────────
## Radio maximo de accion en pixeles (5 tiles de 16px = 80px).
const TILE_SIZE: float = 16.0
const ACTION_RADIUS: float = TILE_SIZE * 5.0

## Duración de la pausa al usar herramienta (squash/stretch feedback).
const USE_PAUSE_DURATION: float = 0.2

## Marca interna para no repetir acciones sobre el mismo tile mientras se mantiene clic.
const INVALID_ACTION_TILE: Vector2i = Vector2i(999999, 999999)

# ── Estado ──────────────────────────────────────────────────────────────────
var current_tool: ToolsComponent.Tools = ToolsComponent.Tools.None
var _is_weapon_drawn: bool = false

var _body: CharacterBody2D
var _movement: MovementComponent
var _sprite: AnimatedSprite2D
var _tilled_layer: TileMapLayer  # La capa de tierra arada (farm plots)
var _grass_layer: TileMapLayer   # La capa de hierba (para validar tilling)
var _is_using_tool: bool = false
var _highlight: Node2D           # Borde 16x16 que marca el tile objetivo
var _mouse_action_held: bool = false
var _last_held_action_tile: Vector2i = INVALID_ACTION_TILE
var _feedback_tween: Tween


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("ToolComponent: parent is not a CharacterBody2D.")
		set_process_input(false)
		return

	# Buscar componentes hermanos
	for child in _body.get_children():
		if child is MovementComponent:
			_movement = child
		if child is AnimatedSprite2D:
			_sprite = child

	if _movement == null:
		push_warning("ToolComponent: sibling MovementComponent not found.")

	# Descubrir capas del tilemap cuando estén disponibles
	_find_layers.call_deferred()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

	# Crear el resaltado de tile objetivo (borde rojo 16x16)
	_highlight = _build_highlight()
	_body.add_child.call_deferred(_highlight)
	
	# NUEVO: Conectamos las señales del EventBus para el inventario
	EventBus.hotbar_selection_changed.connect(_on_hotbar_changed)
	EventBus.inventory_updated.connect(_on_inventory_updated)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.disconnect(_on_node_removed)
		
	# NUEVO: Desconectamos las señales
	if EventBus.hotbar_selection_changed.is_connected(_on_hotbar_changed):
		EventBus.hotbar_selection_changed.disconnect(_on_hotbar_changed)
	if EventBus.inventory_updated.is_connected(_on_inventory_updated):
		EventBus.inventory_updated.disconnect(_on_inventory_updated)


func _find_layers() -> void:
	for node in get_tree().get_nodes_in_group("farm_tilled_dirt"):
		if node is TileMapLayer:
			_tilled_layer = node
			break
	# Buscar la capa de hierba como hermano del TilledDirt (mismo padre)
	if _tilled_layer and _tilled_layer.get_parent():
		for sibling in _tilled_layer.get_parent().get_children():
			if sibling is TileMapLayer and sibling.name == "Grass":
				_grass_layer = sibling
				break


func _on_node_added(node: Node) -> void:
	if node is TileMapLayer and node.is_in_group("farm_tilled_dirt"):
		_tilled_layer = node
		# Buscar la capa de hierba como hermano
		if node.get_parent():
			for sibling in node.get_parent().get_children():
				if sibling is TileMapLayer and sibling.name == "Grass":
					_grass_layer = sibling
					break


func _on_node_removed(node: Node) -> void:
	if node == _tilled_layer:
		_tilled_layer = null
	if node == _grass_layer:
		_grass_layer = null


func _unhandled_input(event: InputEvent) -> void:
	if not _has_starter_pack():
		return

	# Clic izquierdo → usar la herramienta activa (o cosechar si no hay herramienta)
	# Si la espada está equipada, no consumir el clic — lo gestiona AttackComponent
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if current_tool == ToolsComponent.Tools.Sword:
				return  # Delegar al AttackComponent
			_mouse_action_held = true
			_last_held_action_tile = INVALID_ACTION_TILE
			_try_use_held_action()
			return
		_mouse_action_held = false
		return

	# Solo nos interesan pulsaciones de teclado (no repeticiones)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Tecla E -> Cosechar
	if event.keycode == KEY_E:
		_try_harvest()
		return

	var trade_svc = EventBus.services.trade
	if not trade_svc: return

	# ─── SISTEMA DINÁMICO: HOTBAR (1-4) Y ARMA (7) ───
	match event.keycode:
		KEY_1: trade_svc.set_active_slot(0)
		KEY_2: trade_svc.set_active_slot(1)
		KEY_3: trade_svc.set_active_slot(2)
		KEY_4: trade_svc.set_active_slot(3)
		KEY_5:
			# Alternamos el arma y actualizamos la herramienta
			_is_weapon_drawn = !_is_weapon_drawn
			_refresh_active_tool()


func _process(delta: float) -> void:
	_update_highlight()
	_update_held_mouse_action(delta)


## Datos del tile bajo el ratón — compartido entre las funciones de acción.
## cell_source_id será -1 si no hay tile en esa posición de la capa consultada.
var _last_tile_pos: Vector2i
var _last_tile_world_pos: Vector2
var _last_cell_source_id: int
var _last_distance: float


## Calcula la posición del tile bajo el ratón en la capa de tierra arada.
## Almacena los resultados en las variables _last_*.
## _last_tile_world_pos queda en coordenadas GLOBALES (no locales a la capa).
## Retorna true si el cálculo fue exitoso (la capa existe).
func _calculate_tile_under_mouse() -> bool:
	if not _tilled_layer:
		return false
	var mouse_pos: Vector2 = _tilled_layer.get_local_mouse_position()
	_last_tile_pos = _tilled_layer.local_to_map(mouse_pos)
	_last_cell_source_id = _tilled_layer.get_cell_source_id(_last_tile_pos)
	_last_tile_world_pos = _tilled_layer.to_global(_tilled_layer.map_to_local(_last_tile_pos))
	_last_distance = _body.global_position.distance_to(_last_tile_world_pos)
	return true


## Valida que el tile bajo el ratón sea un tile de tierra arada válido
## (existe en la capa) y esté dentro del radio de acción.
func _is_valid_farm_tile() -> bool:
	if not _calculate_tile_under_mouse():
		return false
	if _last_cell_source_id == -1:
		return false
	if _last_distance > ACTION_RADIUS:
		return false
	return true


## Valida que un tile de hierba bajo el ratón sea válido para arar.
func _is_valid_grass_tile_for_tilling() -> bool:
	if not _tilled_layer or not _grass_layer:
		return false
	var mouse_pos: Vector2 = _grass_layer.get_local_mouse_position()
	var grass_tile: Vector2i = _grass_layer.local_to_map(mouse_pos)
	var grass_source_id: int = _grass_layer.get_cell_source_id(grass_tile)
	if grass_source_id == -1:
		return false
	var tilled_source_id: int = _tilled_layer.get_cell_source_id(grass_tile)
	if tilled_source_id != -1:
		return false
	var tile_world: Vector2 = _grass_layer.to_global(_grass_layer.map_to_local(grass_tile))
	if _body.global_position.distance_to(tile_world) > ACTION_RADIUS:
		return false
	_last_tile_pos = grass_tile
	_last_tile_world_pos = tile_world
	return true


## Intenta cosechar el tile bajo el ratón (tecla E).
func _try_harvest() -> bool:
	if not _is_valid_farm_tile():
		return false
	var crop_svc := EventBus.services.crop as CropService
	if crop_svc and not crop_svc.can_harvest(_last_tile_pos):
		return false
	EventBus.player_harvest_attempted.emit(_last_tile_pos)
	_perform_feedback(ToolsComponent.Tools.None, _last_tile_pos)
	return true


## Usa la herramienta actualmente seleccionada, emitiendo la señal global
## correspondiente al EventBus. Si la herramienta es None, intenta cosechar.
func _use_tool() -> bool:
	match current_tool:
		ToolsComponent.Tools.TillGround:
			if _is_valid_grass_tile_for_tilling():
				EventBus.player_tilled.emit(_last_tile_pos)
				_perform_feedback(current_tool, _last_tile_pos)
				return true
			return false 
			
		ToolsComponent.Tools.WaterCrops:
			if _is_valid_farm_tile() and _can_water_tile(_last_tile_pos):
				EventBus.player_watered.emit(_last_tile_pos)
				_perform_feedback(current_tool, _last_tile_pos)
				return true
			return false 

	if current_tool == ToolsComponent.Tools.None:
		var trade_svc = EventBus.services.trade
		var seed_to_plant = trade_svc.get_active_seed()
		
		if seed_to_plant != null and _is_valid_farm_tile() and _can_plant_tile(_last_tile_pos):
			EventBus.player_planted.emit(_last_tile_pos, seed_to_plant.crop_type)
			trade_svc.consume_active_item()
			_perform_feedback(ToolsComponent.Tools.PlantWheat, _last_tile_pos)
			return true
		else:
			return _try_harvest()
	return false


func _update_held_mouse_action(_delta: float) -> void:
	if not _mouse_action_held:
		return
	if current_tool == ToolsComponent.Tools.Sword:
		return
	_try_use_held_action()


func _try_use_held_action() -> void:
	var current_tile := _get_current_action_tile()
	if current_tile == _last_held_action_tile:
		return
	_last_held_action_tile = current_tile
	if current_tile == INVALID_ACTION_TILE:
		return
	_use_tool()


func _get_current_action_tile() -> Vector2i:
	if current_tool == ToolsComponent.Tools.TillGround:
		if _is_valid_grass_tile_for_tilling():
			return _last_tile_pos
	elif _is_valid_farm_tile():
		return _last_tile_pos
	return INVALID_ACTION_TILE


## Aplica feedback visual al usar una herramienta:
## - Pausa breve de movimiento (200ms)
## - Squash & stretch en el sprite del jugador
## - Emite señal global para que FarmService lance partículas
func _perform_feedback(tool: ToolsComponent.Tools, tile_pos: Vector2i) -> void:
	tool_used.emit(tool)
	EventBus.tool_action_performed.emit(tool, tile_pos)

	_is_using_tool = true

	# Detener movimiento durante la acción
	if _movement:
		_movement.stop()

	# Squash & stretch según la herramienta
	if _sprite:
		if _feedback_tween and _feedback_tween.is_running():
			_feedback_tween.kill()
		_sprite.scale = Vector2.ONE
		var tween: Tween = create_tween()
		_feedback_tween = tween
		match tool:
			ToolsComponent.Tools.TillGround:
				tween.tween_property(_sprite, "scale", Vector2(0.85, 1.2), 0.08)
				tween.tween_property(_sprite, "scale", Vector2(1.15, 0.85), 0.06)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.06)
			ToolsComponent.Tools.WaterCrops:
				tween.tween_property(_sprite, "scale", Vector2(1.1, 0.9), 0.1)
				tween.tween_property(_sprite, "scale", Vector2(0.95, 1.05), 0.05)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.05)
			ToolsComponent.Tools.PlantWheat, ToolsComponent.Tools.PlantBeet:
				tween.tween_property(_sprite, "scale", Vector2(1.1, 0.8), 0.1)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)
			ToolsComponent.Tools.None:
				tween.tween_property(_sprite, "scale", Vector2(1.15, 0.8), 0.08)
				tween.tween_property(_sprite, "scale", Vector2(0.9, 1.15), 0.08)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.04)

	# Timer para desbloquear el movimiento
	await get_tree().create_timer(USE_PAUSE_DURATION).timeout
	_is_using_tool = false


func _has_starter_pack() -> bool:
	var trade_svc := EventBus.services.trade as TradeService
	return trade_svc == null or trade_svc.starter_pack_granted


func _can_plant_tile(tile_pos: Vector2i) -> bool:
	var crop_svc := EventBus.services.crop as CropService
	return crop_svc == null or crop_svc.can_plant(tile_pos)


func _can_water_tile(tile_pos: Vector2i) -> bool:
	var crop_svc := EventBus.services.crop as CropService
	return crop_svc == null or crop_svc.can_water(tile_pos)

# ── Resaltado del tile objetivo ─────────────────────────────────────────────

## Construye un Node2D con 4 ColorRect formando un borde rojo 16x16
## (hueco por dentro). Vive en top_level para posicionarse en coords globales.
func _build_highlight() -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = "TileHighlight"
	root.top_level = true
	root.z_index = 20
	root.visible = false

	const SIZE: float = 16.0
	const THICK: float = 1.0
	var color: Color = Color(1.0, 0.15, 0.15, 0.95)

	var half: float = SIZE / 2.0
	var sides := [
		{"pos": Vector2(-half, -half), "size": Vector2(SIZE, THICK)},
		{"pos": Vector2(-half, half - THICK), "size": Vector2(SIZE, THICK)},
		{"pos": Vector2(-half, -half), "size": Vector2(THICK, SIZE)},
		{"pos": Vector2(half - THICK, -half), "size": Vector2(THICK, SIZE)},
	]
	for s: Dictionary in sides:
		var rect: ColorRect = ColorRect.new()
		rect.color = color
		rect.position = s["pos"]
		rect.size = s["size"]
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(rect)
	return root


## Recalcula cada frame si el tile bajo el ratón es un objetivo válido para
## la herramienta actual. Si lo es, mueve el resaltado a ese tile y lo muestra.
## En caso contrario, oculta el resaltado.
func _update_highlight() -> void:
	if _highlight == null:
		return
	if not _has_starter_pack():
		_highlight.visible = false
		return
	var valid: bool = false
	match current_tool:
		ToolsComponent.Tools.Sword:
			valid = false  # La espada no tiene resaltado de tile
		ToolsComponent.Tools.TillGround:
			valid = _is_valid_grass_tile_for_tilling()
		ToolsComponent.Tools.WaterCrops, \
		ToolsComponent.Tools.PlantWheat, \
		ToolsComponent.Tools.PlantBeet, \
		ToolsComponent.Tools.None:
			valid = _is_valid_farm_tile()
	if valid:
		_highlight.global_position = _last_tile_world_pos
		_highlight.visible = true
	else:
		_highlight.visible = false


# ── NUEVO: SINCRONIZACIÓN DE INVENTARIO ─────────────────────────────────────

func _on_hotbar_changed(_index: int) -> void:
	# Si el jugador cambia de slot en la hotbar, enfundamos el arma automáticamente
	_is_weapon_drawn = false
	_refresh_active_tool()

func _on_inventory_updated(_slots: Array, _coins: int) -> void:
	_refresh_active_tool()

## Lee el inventario y actualiza la herramienta de las manos
func _refresh_active_tool() -> void:
	var trade_svc = EventBus.services.trade
	if not trade_svc: return

	var slot_data = null
	
	# Si hemos pulsado el 7, ignoramos la hotbar y leemos tu slot de arma (Índice 19)
	if _is_weapon_drawn:
		if trade_svc._slots.size() > 19:
			slot_data = trade_svc._slots[19]
	else:
		# Si no, leemos la hotbar normal (0 al 3)
		slot_data = trade_svc.get_active_slot_data()

	var new_tool = ToolsComponent.Tools.None

	if slot_data != null:
		var item_resource = slot_data["item"] if typeof(slot_data) == TYPE_DICTIONARY else slot_data
		if item_resource is ToolsComponent:
			new_tool = item_resource.tool_type

	# Si ha cambiado, avisamos al juego
	if new_tool != current_tool:
		current_tool = new_tool
		tool_changed.emit(current_tool)
		EventBus.player_tool_changed.emit(current_tool)

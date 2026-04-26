## ToolComponent — Componente de herramientas reutilizable.
##
## Responsabilidad única: gestionar qué herramienta tiene seleccionada el
## jugador y, cuando se usa (tecla E), emitir la señal global correspondiente
## al EventBus para que el CropService reaccione.
##
## --- Targeting ---
## • Usa la posición del ratón para encontrar el tile en el TileMapLayer de
##   tierra arada ("farm_tilled_dirt"). Solo acepta acciones sobre tiles que
##   realmente existen en esa capa (cell_source_id != -1).
## • Valida que el tile esté dentro del radio de acción (1.5 tiles = 24px).
## • Valida que el tile esté en la dirección a la que mira el jugador
##   (usa MovementComponent.get_facing() con un cono frontal generoso).
## • Usa map_to_local() + to_global() para obtener la posición central del
##   tile en coordenadas globales y calcular la distancia con precisión.
## • Para ARAR: además comprueba que el tile esté dentro de la zona aratable
##   designada ("clarito" — los dos bloques 3x3 pre-marcados en el mapa).
##   Esto lo gestiona CropService.is_tillable_area().
##
## --- Controles ---
## • Teclas 1-5: seleccionan la herramienta activa.
## • Tecla E: usa la herramienta seleccionada. Si la herramienta es None,
##   intenta cosechar el cultivo del tile bajo el ratón.
##
## --- Resaltado visual ---
## • Cada frame se comprueba si el tile bajo el ratón es válido para la
##   herramienta actual (rango, dirección, tipo de tile). Si lo es, se
##   dibuja un borde 16x16 rojo alrededor del tile como feedback.
class_name ToolComponent
extends Node

# ── Señales LOCALES ─────────────────────────────────────────────────────────
## Emitida cuando el jugador cambia de herramienta seleccionada.
signal tool_changed(new_tool: ToolsComponent.Tools)

## Emitida cuando el jugador usa la herramienta activa.
signal tool_used(tool: ToolsComponent.Tools)

# ── Configuración ──────────────────────────────────────────────────────────
## Radio máximo de acción en píxeles (1.5 tiles de 16px = 24px).
const ACTION_RADIUS: float = 24.0

## Tolerancia (px) por detrás del jugador para el cono frontal.
## Permite actuar sobre tiles que están ligeramente "debajo" (misma fila/columna
## que el jugador) cuando miras en una dirección cardinal — sin permitir tiles
## claramente a la espalda.
const FACING_TOLERANCE: float = 4.0

## Duración de la pausa al usar herramienta (squash/stretch feedback).
const USE_PAUSE_DURATION: float = 0.2

# ── Estado ──────────────────────────────────────────────────────────────────
var current_tool: ToolsComponent.Tools = ToolsComponent.Tools.None

var _body: CharacterBody2D
var _movement: MovementComponent
var _sprite: AnimatedSprite2D
var _tilled_layer: TileMapLayer  # La capa de tierra arada (farm plots)
var _grass_layer: TileMapLayer   # La capa de hierba (para validar tilling)
var _is_using_tool: bool = false
var _highlight: Node2D           # Borde 16x16 que marca el tile objetivo


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("ToolComponent: el padre no es un CharacterBody2D.")
		set_process_input(false)
		return

	# Buscar componentes hermanos
	for child in _body.get_children():
		if child is MovementComponent:
			_movement = child
		if child is AnimatedSprite2D:
			_sprite = child

	if _movement == null:
		push_warning("ToolComponent: no se encontró MovementComponent hermano.")

	# Descubrir capas del tilemap cuando estén disponibles
	_find_layers.call_deferred()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

	# Crear el resaltado de tile objetivo (borde rojo 16x16)
	_highlight = _build_highlight()
	_body.add_child(_highlight)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.disconnect(_on_node_removed)


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
	if _is_using_tool:
		return  # Bloqueado durante la pausa de uso

	# Solo nos interesan pulsaciones de teclado (no repeticiones).
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Selección de herramienta con teclas numéricas
	var new_tool: ToolsComponent.Tools = _key_to_tool(event.keycode)
	if new_tool >= 0:
		if new_tool != current_tool:
			current_tool = new_tool
			tool_changed.emit(current_tool)
			EventBus.player_tool_changed.emit(current_tool)
		return

	# Tecla E → usar la herramienta activa (o cosechar si no hay herramienta)
	if event.keycode == KEY_E:
		_use_tool()


func _process(_delta: float) -> void:
	_update_highlight()


## Datos del tile bajo el ratón — compartido entre las funciones de acción.
## cell_source_id será -1 si no hay tile en esa posición de la capa consultada.
var _last_tile_pos: Vector2i
var _last_tile_world_pos: Vector2
var _last_cell_source_id: int
var _last_distance: float


## Devuelve la dirección cardinal a la que mira el jugador.
## Si no hay MovementComponent, asume DOWN (valor por defecto).
func _get_facing() -> Vector2:
	if _movement:
		return _movement.get_facing()
	return Vector2.DOWN


## Comprueba si un tile (en coords globales) cae dentro del cono frontal del
## jugador — es decir, está delante en la dirección a la que mira. Admite
## una pequeña tolerancia hacia atrás (FACING_TOLERANCE) para que el tile
## directamente bajo los pies no quede excluido por error de redondeo.
func _is_in_facing_direction(tile_global: Vector2) -> bool:
	var facing: Vector2 = _get_facing()
	if facing == Vector2.ZERO:
		return true  # sin facing definido → no restringir
	var diff: Vector2 = tile_global - _body.global_position
	return diff.dot(facing) >= -FACING_TOLERANCE


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
## (existe en la capa), esté dentro del radio de acción y dentro del cono
## frontal a la dirección a la que mira el jugador.
func _is_valid_farm_tile() -> bool:
	if not _calculate_tile_under_mouse():
		return false
	# El tile debe existir en la capa de tierra arada (source_id != -1)
	if _last_cell_source_id == -1:
		return false
	# El tile debe estar dentro del radio de acción
	if _last_distance > ACTION_RADIUS:
		return false
	# El tile debe estar delante del jugador (en la dirección a la que mira)
	if not _is_in_facing_direction(_last_tile_world_pos):
		return false
	return true


## Valida que un tile de hierba bajo el ratón sea válido para arar:
## - existe en la capa de hierba
## - no tiene ya tierra arada encima
## - está dentro de la zona aratable designada (clarito — 3x3 bloques)
## - está dentro del radio de acción
## - está en la dirección a la que mira el jugador
func _is_valid_grass_tile_for_tilling() -> bool:
	if not _tilled_layer or not _grass_layer:
		return false
	var mouse_pos: Vector2 = _grass_layer.get_local_mouse_position()
	var grass_tile: Vector2i = _grass_layer.local_to_map(mouse_pos)
	var grass_source_id: int = _grass_layer.get_cell_source_id(grass_tile)
	if grass_source_id == -1:
		return false  # No hay hierba aquí
	# Comprobar que no haya ya tierra arada en esta posición
	var tilled_source_id: int = _tilled_layer.get_cell_source_id(grass_tile)
	if tilled_source_id != -1:
		return false  # Ya está arado
	# Posición global del centro del tile (no solo local a la capa)
	var tile_world: Vector2 = _grass_layer.to_global(_grass_layer.map_to_local(grass_tile))
	if _body.global_position.distance_to(tile_world) > ACTION_RADIUS:
		return false
	if not _is_in_facing_direction(tile_world):
		return false
	# Guardar la posición para usar luego
	_last_tile_pos = grass_tile
	_last_tile_world_pos = tile_world
	return true


## Intenta cosechar el tile bajo el ratón (tecla E).
func _try_harvest() -> void:
	if not _is_valid_farm_tile():
		return
	EventBus.player_harvest_attempted.emit(_last_tile_pos)
	_perform_feedback(ToolsComponent.Tools.None, _last_tile_pos)


## Usa la herramienta actualmente seleccionada, emitiendo la señal global
## correspondiente al EventBus. Si la herramienta es None, intenta cosechar.
func _use_tool() -> void:
	if current_tool == ToolsComponent.Tools.None:
		_try_harvest()
		return

	match current_tool:
		ToolsComponent.Tools.TillGround:
			# Arar: solo funciona sobre hierba válida (no sobre tierra ya arada)
			if not _is_valid_grass_tile_for_tilling():
				return
			EventBus.player_tilled.emit(_last_tile_pos)
			_perform_feedback(current_tool, _last_tile_pos)

		ToolsComponent.Tools.WaterCrops:
			# Regar: solo sobre tiles de tierra arada que tengan cultivo
			if not _is_valid_farm_tile():
				return
			EventBus.player_watered.emit(_last_tile_pos)
			_perform_feedback(current_tool, _last_tile_pos)

		ToolsComponent.Tools.PlantWheat:
			# Plantar: solo sobre tiles de tierra arada válidos
			if not _is_valid_farm_tile():
				return
			EventBus.player_planted.emit(_last_tile_pos, CropComponent.CropType.Wheat)
			_perform_feedback(current_tool, _last_tile_pos)

		ToolsComponent.Tools.PlantBeet:
			# Plantar: solo sobre tiles de tierra arada válidos
			if not _is_valid_farm_tile():
				return
			EventBus.player_planted.emit(_last_tile_pos, CropComponent.CropType.Beet)
			_perform_feedback(current_tool, _last_tile_pos)


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
		var tween: Tween = create_tween()
		match tool:
			ToolsComponent.Tools.TillGround:
				# Azada: elevarse y bajar (golpe hacia abajo)
				tween.tween_property(_sprite, "scale", Vector2(0.85, 1.2), 0.08)
				tween.tween_property(_sprite, "scale", Vector2(1.15, 0.85), 0.06)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.06)
			ToolsComponent.Tools.WaterCrops:
				# Regadera: inclinarse hacia adelante
				tween.tween_property(_sprite, "scale", Vector2(1.1, 0.9), 0.1)
				tween.tween_property(_sprite, "scale", Vector2(0.95, 1.05), 0.05)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.05)
			ToolsComponent.Tools.PlantWheat, ToolsComponent.Tools.PlantBeet:
				# Plantar: agacharse
				tween.tween_property(_sprite, "scale", Vector2(1.1, 0.8), 0.1)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)
			ToolsComponent.Tools.None:
				# Cosechar (E): agacharse y levantarse con estirón
				tween.tween_property(_sprite, "scale", Vector2(1.15, 0.8), 0.08)
				tween.tween_property(_sprite, "scale", Vector2(0.9, 1.15), 0.08)
				tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.04)

	# Timer para desbloquear el movimiento
	await get_tree().create_timer(USE_PAUSE_DURATION).timeout
	_is_using_tool = false


## Convierte un keycode numérico al enum de herramienta.
func _key_to_tool(keycode: int) -> ToolsComponent.Tools:
	match keycode:
		KEY_1: return ToolsComponent.Tools.None
		KEY_2: return ToolsComponent.Tools.TillGround
		KEY_3: return ToolsComponent.Tools.WaterCrops
		KEY_4: return ToolsComponent.Tools.PlantWheat
		KEY_5: return ToolsComponent.Tools.PlantBeet
	return -1  # Tecla no mapeada


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
		# top
		{"pos": Vector2(-half, -half), "size": Vector2(SIZE, THICK)},
		# bottom
		{"pos": Vector2(-half, half - THICK), "size": Vector2(SIZE, THICK)},
		# left
		{"pos": Vector2(-half, -half), "size": Vector2(THICK, SIZE)},
		# right
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
	var valid: bool = false
	match current_tool:
		ToolsComponent.Tools.TillGround:
			valid = _is_valid_grass_tile_for_tilling()
		ToolsComponent.Tools.WaterCrops, \
		ToolsComponent.Tools.PlantWheat, \
		ToolsComponent.Tools.PlantBeet, \
		ToolsComponent.Tools.None:
			# Planta/riega/cosecha: todas actúan sobre tiles de tierra arada.
			valid = _is_valid_farm_tile()
	if valid:
		_highlight.global_position = _last_tile_world_pos
		_highlight.visible = true
	else:
		_highlight.visible = false

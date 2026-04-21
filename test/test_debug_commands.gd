## [TEST] Comandos de debug para probar el ciclo de cultivos.
##
## Teclas:
## • P            — Avanza el crecimiento del cultivo más cercano al ratón.
## • Shift + P    — Avanza TODOS los cultivos un stage.
##
## Para eliminar: borrar la carpeta test/ y las líneas marcadas con # [TEST]
## en game_world.gd y event_bus.gd.
class_name TestDebugCommands
extends Node

var _tilled_layer: TileMapLayer


func _ready() -> void:
	# Descubrir TileMapLayer por grupo
	_find_tilled_layer.call_deferred()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.disconnect(_on_node_removed)


func _find_tilled_layer() -> void:
	for node in get_tree().get_nodes_in_group("farm_tilled_dirt"):
		if node is TileMapLayer:
			_tilled_layer = node
			break


func _on_node_added(node: Node) -> void:
	if node is TileMapLayer and node.is_in_group("farm_tilled_dirt"):
		_tilled_layer = node


func _on_node_removed(node: Node) -> void:
	if node == _tilled_layer:
		_tilled_layer = null


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode != KEY_P:
		return

	if event.shift_pressed:
		# Shift + P → avanzar TODOS los cultivos
		var crop_svc := EventBus.services.crop as CropService
		if crop_svc:
			crop_svc.debug_advance_all()
			print("[TEST] Avanzados todos los cultivos un stage.")
	else:
		# P → avanzar el cultivo bajo el ratón
		_advance_nearest_crop()


func _advance_nearest_crop() -> void:
	if not _tilled_layer:
		print("[TEST] No hay TileMapLayer de tierra arada.")
		return
	var mouse_pos: Vector2 = _tilled_layer.get_local_mouse_position()
	var tile_pos: Vector2i = _tilled_layer.local_to_map(mouse_pos)
	# Verificar que hay un cultivo en esta posición
	var crop_svc := EventBus.services.crop as CropService
	if crop_svc and crop_svc.has_crop(tile_pos):
		EventBus.debug_advance_crop.emit(tile_pos)
		print("[TEST] Avanzar cultivo en tile: ", tile_pos)
	else:
		print("[TEST] No hay cultivo en tile: ", tile_pos)

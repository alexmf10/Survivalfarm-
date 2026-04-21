## Entidad visual de un cultivo plantado en el mundo.
## Muestra el sprite correspondiente a la etapa de crecimiento actual.
## Escucha señales globales para reaccionar a riego y madurez.
class_name CropEntity
extends Node2D

var _sprite: Sprite2D
var _data: CropComponent
var stage: int = 0
var _is_mature: bool = false
var _glow_tween: Tween


func _ready() -> void:
	_sprite = $Sprite2D
	_sprite.region_enabled = true


func setup(data: CropComponent) -> void:
	_data = data
	_update_visual()


func advance_stage(new_stage: int) -> void:
	stage = new_stage
	_update_visual()
	# Comprobar si ha alcanzado la madurez
	if _data and stage >= _data.max_stages - 1:
		_show_maturity_effect()
	# Al crecer, quitar tinte de riego
	_set_watered_visual(false)


func set_watered(watered: bool) -> void:
	_set_watered_visual(watered)


func _update_visual() -> void:
	if not _sprite or not _data:
		return
	_sprite.texture = _data.spritesheet
	var col: int = _data.seed_col + 1 + stage
	_sprite.region_rect = Rect2(
		col * _data.frame_width,
		_data.spritesheet_row * _data.frame_height,
		_data.frame_width,
		_data.frame_height
	)


## Indicador visual de riego: tinte ligeramente azulado.
func _set_watered_visual(watered: bool) -> void:
	if not _sprite:
		return
	if watered:
		_sprite.modulate = Color(0.75, 0.8, 1.0)  # Tinte azul suave
	else:
		_sprite.modulate = Color(1.0, 1.0, 1.0)    # Color normal


## Efecto visual de madurez: pulsación de brillo (glow suave que se repite).
func _show_maturity_effect() -> void:
	_is_mature = true
	if _glow_tween and _glow_tween.is_running():
		_glow_tween.kill()

	_glow_tween = create_tween()
	_glow_tween.set_loops()  # Loop infinito hasta que se coseche
	_glow_tween.tween_property(_sprite, "modulate", Color(1.2, 1.2, 0.9), 0.8)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0), 0.8)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _exit_tree() -> void:
	if _glow_tween and _glow_tween.is_running():
		_glow_tween.kill()

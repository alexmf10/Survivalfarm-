## Entidad visual de un cultivo plantado en el mundo.
class_name CropEntity
extends Node2D

var _sprite: Sprite2D
var _data: CropComponent
var stage: int = 0


func _ready() -> void:
	_sprite = $Sprite2D
	_sprite.region_enabled = true


func setup(data: CropComponent) -> void:
	_data = data
	_update_visual()


func advance_stage(new_stage: int) -> void:
	stage = new_stage
	_update_visual()


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

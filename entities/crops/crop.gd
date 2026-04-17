## Entidad visual de un cultivo plantado en el mundo.
## GameWorld instancia este nodo y lo posiciona en el tile correspondiente.
## Ajusta FRAME_WIDTH/FRAME_HEIGHT según el layout real de basic_plants.png.
class_name CropEntity
extends Node2D

const CROP_TEXTURE: Texture2D = preload("res://assets/textures/test/objects/basic_plants.png")

## Tamaño de cada frame en basic_plants.png — ajustar al layout real del spritesheet.
## Fila = tipo de cultivo (0=Corn, 1=Tomato), Columna = etapa de crecimiento (0..max_stages-1)
const FRAME_WIDTH: int = 16
const FRAME_HEIGHT: int = 16

var _sprite: Sprite2D
var crop_type: CropComponent.CropType
var stage: int = 0
var max_stages: int = 4


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = CROP_TEXTURE
	_sprite.region_enabled = true
	add_child(_sprite)


func setup(type: CropComponent.CropType, max_s: int) -> void:
	crop_type = type
	max_stages = max_s
	_update_visual()


func advance_stage(new_stage: int) -> void:
	stage = new_stage
	_update_visual()


func _update_visual() -> void:
	if not _sprite:
		return
	var col: int = stage
	var row: int = crop_type
	_sprite.region_rect = Rect2(col * FRAME_WIDTH, row * FRAME_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT)

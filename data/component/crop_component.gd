## Componente de datos que define la estructura de un tipo de cultivo.
## Las instancias concretas (.tres) se crean en data/definition/.
class_name CropComponent
extends Resource

enum CropType {
	Wheat,
	Beet,
}

@export var crop_name: String = ""
@export var crop_type: CropType = CropType.Wheat
@export var max_stages: int = 4
@export var days_per_stage: int = 1

@export_group("Visuals")
@export var spritesheet: Texture2D
@export var frame_width: int = 16
@export var frame_height: int = 16
@export var spritesheet_row: int = 0
@export var seed_col: int = 0
@export var drop_col: int = 5

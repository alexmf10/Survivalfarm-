## Componente de datos que define la estructura de un tipo de cultivo.
## Las instancias concretas (.tres) se crean en data/definition/.
class_name CropComponent
extends Resource

enum CropType {
	Corn,
	Tomato,
	Wheat
}

@export var crop_name: String = ""
@export var crop_type: CropType = CropType.Corn
@export var max_stages: int = 4
@export var days_per_stage: int = 1

class_name ToolsComponent
extends Resource

enum Tools {
	None,
	TillGround,
	WaterCrops,
	PlantWheat,
	PlantBeet,
	Sword
}

## Qué herramienta activa esto al tenerlo en la mano
@export var tool_type: Tools

## Datos visuales para que el inventario pueda dibujarlo
@export var spritesheet: Texture2D
@export var drop_col: int = 0
@export var spritesheet_row: int = 0
@export var frame_width: int = 16  
@export var frame_height: int = 16
@export var is_seed: bool = false

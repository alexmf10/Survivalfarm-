extends CanvasLayer

@onready var tool_label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/ToolNameLabel

func _ready() -> void:
	EventBus.player_tool_changed.connect(_on_player_tool_changed)
	_update_tool_label(ToolsComponent.Tools.None) # Default starting tool


func _on_player_tool_changed(tool_type: ToolsComponent.Tools) -> void:
	_update_tool_label(tool_type)


func _update_tool_label(tool_type: ToolsComponent.Tools) -> void:
	var tool_name = "Manos (1) — E para cosechar"
	match tool_type:
		ToolsComponent.Tools.None: tool_name = "Manos (1) — E para cosechar"
		ToolsComponent.Tools.TillGround: tool_name = "Azadón (2)"
		ToolsComponent.Tools.WaterCrops: tool_name = "Regadera (3)"
		ToolsComponent.Tools.PlantWheat: tool_name = "Semillas de Trigo (4)"
		ToolsComponent.Tools.PlantBeet: tool_name = "Semillas de Remolacha (5)"
		
	tool_label.text = "Herramienta: " + tool_name

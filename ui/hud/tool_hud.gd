extends CanvasLayer

const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_PARCHMENT_DARK: Color = Color(0.68, 0.61, 0.48)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT: Color = Color(0.35, 0.25, 0.15)
const COLOR_TEXT_LIGHT: Color = Color(0.55, 0.42, 0.28)

var _font: Font
var _tool_label: Label
var _current_tool: ToolsComponent.Tools = ToolsComponent.Tools.None


func _ready() -> void:
	layer = 10
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()
	EventBus.player_tool_changed.connect(_on_player_tool_changed)
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
	_update_label()


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_top = -36
	panel.offset_bottom = -8
	panel.offset_left = 8
	panel.offset_right = 8

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_color = COLOR_BORDER
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.set_corner_radius_all(0)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	_tool_label = Label.new()
	if _font:
		_tool_label.add_theme_font_override("font", _font)
	_tool_label.add_theme_font_size_override("font_size", 6)
	_tool_label.add_theme_color_override("font_color", COLOR_TEXT)
	_tool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_tool_label)


func _on_hotbar_selection_changed(_index: int) -> void:
	_update_label()

func _on_player_tool_changed(tool_type: ToolsComponent.Tools) -> void:
	_current_tool = tool_type
	_update_label()

func _on_inventory_updated(_slots: Array, _coins: int) -> void:
	_update_label()

##Leemos el item en el slot seleccionado para imprimir sus datos por la hud
func _update_label() -> void:
	if not _tool_label:
		return
	# Accedemos al trade svc para leer el slot que está usando el jugador
	var trade_svc := EventBus.services.trade as TradeService
	var text_to_show: String = ""
	
	if _current_tool == ToolsComponent.Tools.Sword:
		text_to_show = _get_tool_text(_current_tool)
	else:
		if trade_svc:
			var slot_data = trade_svc.get_active_slot_data()
			
			if slot_data != null:
				var item = slot_data["item"]
				var amount: int = slot_data["amount"]
				
				# Si el objeto tiene la propiedad "crop_name", es una semilla o cultivo
				if "crop_name" in item:
					text_to_show = "%s (x%d)" % [item.crop_name.to_upper(), amount]
				else:
					# Si no la tiene, asumimos que es una herramienta
					text_to_show = _get_tool_text(_current_tool)
			else:
				# Si el slot está completamente vacío
				text_to_show = ""

	_tool_label.text = text_to_show

func _get_tool_text(tool_type: ToolsComponent.Tools) -> String:
	match tool_type:
		ToolsComponent.Tools.TillGround:
			return "HOE"
		ToolsComponent.Tools.WaterCrops:
			return "WATERING CAN"
		ToolsComponent.Tools.Sword:
			return "SWORD (5)  LMB:ATTACK"
		ToolsComponent.Tools.Helm:
			return "HELM"
		ToolsComponent.Tools.Chest:
			return "CHESTPLATE"
		ToolsComponent.Tools.Bot:
			return "BOOTS"
			
	return ""

func _get_seed_count(crop_type: CropComponent.CropType) -> int:
	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc:
		return trade_svc.get_seed_count(crop_type)
	return 0

## [TEST] Mini-inventario de prueba para validar el flujo de cultivos.
## Muestra una barra horizontal inferior con slots para herramientas y cosechas.
## Estilo visual: tonalidad madera, alineado con el diseño del menú principal.
##
## Para eliminar: borrar la carpeta test/ y las líneas marcadas con # [TEST] en
## game_world.gd y event_bus.gd.
class_name TestToolbarHUD
extends CanvasLayer

# ── Constantes de estilo (wooden theme — igual que MainMenu) ────────────────
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_PARCHMENT_DARK: Color = Color(0.72, 0.66, 0.53)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT_BROWN: Color = Color(0.35, 0.25, 0.15)
const COLOR_HIGHLIGHT: Color = Color(0.95, 0.85, 0.55)
const COLOR_SLOT_BG: Color = Color(0.65, 0.58, 0.45)
const COLOR_SLOT_ACTIVE: Color = Color(0.9, 0.75, 0.35)

# ── Datos de los slots ──────────────────────────────────────────────────────
# Formato: { tool_enum, label, emoji, count (solo para cosechas) }
var _tool_slots: Array = [
	{ "tool": ToolsComponent.Tools.None, "label": "Manos", "emoji": "✋" },
	{ "tool": ToolsComponent.Tools.TillGround, "label": "Azadón", "emoji": "⛏" },
	{ "tool": ToolsComponent.Tools.WaterCrops, "label": "Regadera", "emoji": "💧" },
	{ "tool": ToolsComponent.Tools.PlantWheat, "label": "Trigo", "emoji": "🌾" },
	{ "tool": ToolsComponent.Tools.PlantBeet, "label": "Remolacha", "emoji": "🥬" },
]

var _harvest_counts: Dictionary = {}  # CropType → int
var _harvest_labels: Dictionary = {}  # CropType → Label

var _slot_panels: Array = []  # PanelContainer por cada tool slot
var _current_tool: ToolsComponent.Tools = ToolsComponent.Tools.None
var _font: Font


func _ready() -> void:
	layer = 11  # Por encima del DayCycleHUD

	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font

	# Inicializar contadores de cosecha
	_harvest_counts[CropComponent.CropType.Wheat] = 0
	_harvest_counts[CropComponent.CropType.Beet] = 0

	_build_ui()

	# Conectar señales
	EventBus.player_tool_changed.connect(_on_player_tool_changed)
	EventBus.crop_harvested.connect(_on_crop_harvested)


func _exit_tree() -> void:
	if EventBus.player_tool_changed.is_connected(_on_player_tool_changed):
		EventBus.player_tool_changed.disconnect(_on_player_tool_changed)
	if EventBus.crop_harvested.is_connected(_on_crop_harvested):
		EventBus.crop_harvested.disconnect(_on_crop_harvested)


func _build_ui() -> void:
	# Root control que cubre toda la pantalla
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Panel principal en la parte inferior central
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_top = -52
	panel.offset_bottom = -8
	panel.offset_left = -180
	panel.offset_right = 180

	# Estilo de madera del panel principal
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT_DARK
	style.border_width_bottom = 3
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	# HBox para los slots
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 3)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	# Crear slots de herramientas (5 slots)
	for i: int in range(_tool_slots.size()):
		var slot: PanelContainer = _create_tool_slot(_tool_slots[i], i + 1)
		hbox.add_child(slot)
		_slot_panels.append(slot)

	# Separador visual
	var separator: VSeparator = VSeparator.new()
	separator.custom_minimum_size = Vector2(2, 0)
	separator.add_theme_stylebox_override("separator", StyleBoxFlat.new())
	var sep_style: StyleBoxFlat = separator.get_theme_stylebox("separator") as StyleBoxFlat
	if sep_style:
		sep_style.bg_color = COLOR_BORDER
		sep_style.content_margin_left = 1
		sep_style.content_margin_right = 1
	hbox.add_child(separator)

	# Slots de cosechas (2 slots)
	var wheat_slot: PanelContainer = _create_harvest_slot("🌾", CropComponent.CropType.Wheat)
	hbox.add_child(wheat_slot)
	var beet_slot: PanelContainer = _create_harvest_slot("🥬", CropComponent.CropType.Beet)
	hbox.add_child(beet_slot)

	# Highlight del slot activo inicial
	_update_active_highlight()


func _create_tool_slot(data: Dictionary, key_num: int) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(42, 36)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var slot_style: StyleBoxFlat = StyleBoxFlat.new()
	slot_style.bg_color = COLOR_SLOT_BG
	slot_style.border_width_bottom = 2
	slot_style.border_width_top = 1
	slot_style.border_width_left = 1
	slot_style.border_width_right = 1
	slot_style.border_color = COLOR_BORDER
	slot_style.corner_radius_top_left = 3
	slot_style.corner_radius_top_right = 3
	slot_style.corner_radius_bottom_left = 3
	slot_style.corner_radius_bottom_right = 3
	slot_style.content_margin_left = 2
	slot_style.content_margin_right = 2
	slot_style.content_margin_top = 1
	slot_style.content_margin_bottom = 1
	slot.add_theme_stylebox_override("panel", slot_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)

	# Emoji del icono
	var icon_lbl: Label = Label.new()
	icon_lbl.text = data["emoji"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(icon_lbl)

	# Número de tecla
	var key_lbl: Label = Label.new()
	key_lbl.text = str(key_num)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		key_lbl.add_theme_font_override("font", _font)
	key_lbl.add_theme_font_size_override("font_size", 5)
	key_lbl.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	vbox.add_child(key_lbl)

	return slot


func _create_harvest_slot(emoji: String, crop_type: CropComponent.CropType) -> PanelContainer:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(42, 36)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var slot_style: StyleBoxFlat = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.55, 0.48, 0.38)
	slot_style.border_width_bottom = 2
	slot_style.border_width_top = 1
	slot_style.border_width_left = 1
	slot_style.border_width_right = 1
	slot_style.border_color = COLOR_BORDER
	slot_style.corner_radius_top_left = 3
	slot_style.corner_radius_top_right = 3
	slot_style.corner_radius_bottom_left = 3
	slot_style.corner_radius_bottom_right = 3
	slot_style.content_margin_left = 2
	slot_style.content_margin_right = 2
	slot_style.content_margin_top = 1
	slot_style.content_margin_bottom = 1
	slot.add_theme_stylebox_override("panel", slot_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)

	# Emoji
	var icon_lbl: Label = Label.new()
	icon_lbl.text = emoji
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(icon_lbl)

	# Contador
	var count_lbl: Label = Label.new()
	count_lbl.text = "x0"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		count_lbl.add_theme_font_override("font", _font)
	count_lbl.add_theme_font_size_override("font_size", 5)
	count_lbl.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	vbox.add_child(count_lbl)

	_harvest_labels[crop_type] = count_lbl

	return slot


func _update_active_highlight() -> void:
	for i: int in range(_slot_panels.size()):
		var slot_panel: PanelContainer = _slot_panels[i]
		var slot_style: StyleBoxFlat = slot_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if slot_style:
			if _tool_slots[i]["tool"] == _current_tool:
				slot_style.bg_color = COLOR_SLOT_ACTIVE
				slot_style.border_color = Color(0.6, 0.45, 0.15)
			else:
				slot_style.bg_color = COLOR_SLOT_BG
				slot_style.border_color = COLOR_BORDER


func _on_player_tool_changed(tool: ToolsComponent.Tools) -> void:
	_current_tool = tool
	_update_active_highlight()


func _on_crop_harvested(_tile_pos: Vector2i, crop_type: CropComponent.CropType) -> void:
	_harvest_counts[crop_type] = _harvest_counts.get(crop_type, 0) + 1
	if _harvest_labels.has(crop_type):
		var lbl: Label = _harvest_labels[crop_type]
		lbl.text = "x%d" % _harvest_counts[crop_type]

		# Feedback visual: bounce el label
		var tween: Tween = create_tween()
		tween.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)

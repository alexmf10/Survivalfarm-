## SwordHUD — Indicador de la espada en la esquina inferior derecha.
##
## CanvasLayer que muestra un icono de espada pixel-art y el estado
## actual (equipada/no equipada) en la esquina inferior derecha.
##
## --- Arquitectura ---
## - Escucha: EventBus.player_tool_changed → actualiza el estado visual.
## - No emite señales (solo lectura).
## - Se construye por código, sin assets ni sprites externos.
class_name SwordHUD
extends CanvasLayer

# ── Paleta de colores ────────────────────────────────────────────────────────
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_PARCHMENT_DARK: Color = Color(0.68, 0.61, 0.48)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT: Color = Color(0.35, 0.25, 0.15)
const COLOR_TEXT_LIGHT: Color = Color(0.55, 0.42, 0.28)
const COLOR_EQUIPPED: Color = Color(0.18, 0.80, 0.25)
const COLOR_UNEQUIPPED: Color = Color(0.55, 0.42, 0.28, 0.5)

var _font: Font
var _status_label: Label
var _sword_icon: Control
var _panel: PanelContainer
var _is_equipped: bool = false


func _ready() -> void:
	layer = 10
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()
	EventBus.player_tool_changed.connect(_on_tool_changed)
	_update_display(false)


func _exit_tree() -> void:
	if EventBus.player_tool_changed.is_connected(_on_tool_changed):
		EventBus.player_tool_changed.disconnect(_on_tool_changed)


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_top = -36
	_panel.offset_bottom = -8
	_panel.offset_right = -96
	_panel.offset_left = -88

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_color = COLOR_BORDER
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.set_corner_radius_all(0)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)

	# Layout horizontal: icono espada + estado
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(hbox)

	# Icono espada dibujado por código
	_sword_icon = SwordIcon.new()
	_sword_icon.custom_minimum_size = Vector2(10, 10)
	_sword_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_sword_icon)

	# Label de estado
	_status_label = Label.new()
	if _font:
		_status_label.add_theme_font_override("font", _font)
	_status_label.add_theme_font_size_override("font_size", 6)
	_status_label.add_theme_color_override("font_color", COLOR_TEXT)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_status_label)


func _on_tool_changed(tool: ToolsComponent.Tools) -> void:
	var equipped: bool = (tool == ToolsComponent.Tools.Sword)
	_update_display(equipped)


func _update_display(equipped: bool) -> void:
	_is_equipped = equipped
	if _status_label:
		if equipped:
			_status_label.text = "SWORD [6]"
			_status_label.add_theme_color_override("font_color", COLOR_EQUIPPED)
		else:
			_status_label.text = "SWORD [6]"
			_status_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	if _sword_icon:
		_sword_icon.queue_redraw()


# ── Subclase: icono espada pixel-art ─────────────────────────────────────────

class SwordIcon extends Control:
	const BLADE_COLOR: Color = Color(0.75, 0.78, 0.82)
	const GUARD_COLOR: Color = Color(0.55, 0.40, 0.20)
	const GRIP_COLOR: Color = Color(0.45, 0.30, 0.15)
	const PX: float = 2.0

	# Mapa 5x5 de la espada (0=vacío, 1=hoja, 2=guarda, 3=empuñadura)
	const SWORD_MAP: Array = [
		[0, 0, 0, 0, 1],
		[0, 0, 0, 1, 0],
		[0, 0, 1, 0, 0],
		[0, 2, 2, 2, 0],
		[0, 0, 3, 0, 0],
	]

	func _draw() -> void:
		for y in range(SWORD_MAP.size()):
			for x in range(SWORD_MAP[y].size()):
				var cell: int = SWORD_MAP[y][x]
				if cell == 0:
					continue
				var color: Color
				match cell:
					1: color = BLADE_COLOR
					2: color = GUARD_COLOR
					3: color = GRIP_COLOR
				draw_rect(Rect2(x * PX, y * PX, PX, PX), color)

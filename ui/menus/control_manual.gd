## Popup con el manual de usuario. Muestra instrucciones del juego.
##
## Arquitectura:
## • Señal personalizada: back_pressed — emitida al pulsar el botón "X".
## • Instanciado como popup overlay desde main_menu.gd.
## • No accede ni usa ningún servicio.
## • Emite back_pressed al cerrar, que MainMenu escucha para limpiar el overlay.
class_name ControlManual
extends Control

signal back_pressed

var _font: Font

const COLOR_SKY: Color = Color(0.53, 0.77, 0.93)
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT_BROWN: Color = Color(0.35, 0.25, 0.15)


func _ready() -> void:
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()


func _build_ui() -> void:
	# Panel central
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_top = -140
	panel.offset_right = 250
	panel.offset_bottom = 140

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_width_bottom = 4
	style.border_width_top = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Título + botón cerrar
	var top_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "USER MANUAL"
	title_lbl.add_theme_font_override("font", _font)
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_lbl)

	var btn_close: Button = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(24, 24)
	btn_close.add_theme_font_override("font", _font)
	btn_close.add_theme_font_size_override("font_size", 8)
	btn_close.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	btn_close.pressed.connect(func() -> void: back_pressed.emit())

	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_PARCHMENT
	btn_style.border_width_bottom = 2
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_color = COLOR_BORDER
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn_close.add_theme_stylebox_override("normal", btn_style)
	btn_close.add_theme_stylebox_override("hover", btn_style)
	btn_close.add_theme_stylebox_override("pressed", btn_style)
	top_hbox.add_child(btn_close)

	# ScrollContainer para el contenido
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)

	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(content_vbox)

	# Secciones
	_add_section(content_vbox, "HOW TO PLAY",
		"Survive and grow your farm! Plant crops, harvest them,\nsell at market, and defend against monsters at night.\nUpgrade your equipment and unlock achievements.")

	_add_section(content_vbox, "CONTROLS",
		"W A S D — Move\nE — Interact\nLeft Click — Attack\nI / Tab — Inventory\nEsc — Pause")

	_add_section(content_vbox, "OBJECTIVES",
		"• Plant and harvest crops\n• Trade with merchants\n• Equip armor and weapons\n• Survive the night monsters\n• Complete all achievements")


func _add_section(parent: VBoxContainer, header: String, body: String) -> void:
	var header_lbl: Label = Label.new()
	header_lbl.text = header
	header_lbl.add_theme_font_override("font", _font)
	header_lbl.add_theme_font_size_override("font_size", 8)
	header_lbl.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	parent.add_child(header_lbl)

	var body_lbl: Label = Label.new()
	body_lbl.text = body
	body_lbl.add_theme_font_override("font", _font)
	body_lbl.add_theme_font_size_override("font_size", 6)
	body_lbl.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(body_lbl)

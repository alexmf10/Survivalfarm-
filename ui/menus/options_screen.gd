## Pantalla de Opciones.
## Muestra 4 cajas de opciones en una fila, sin lógica (stub).
class_name OptionsScreen
extends Control

# Constantes
const COLOR_SKY: Color = Color(0.53, 0.77, 0.93)
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT_BROWN: Color = Color(0.35, 0.25, 0.15)

var _font: Font


func _ready() -> void:
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()


func _build_ui() -> void:
	# Fondo cielo
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_SKY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.offset_left = -200
	main_vbox.offset_top = -100
	main_vbox.offset_right = 200
	main_vbox.offset_bottom = 100
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 24)
	add_child(main_vbox)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(hbox)

	for i: int in range(1, 5):
		var btn: Button = Button.new()
		btn.text = "Opcion %d" % i
		btn.custom_minimum_size = Vector2(80, 80)
		
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 6)
		btn.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
		btn.add_theme_color_override("font_hover_color", COLOR_TEXT_BROWN)

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = COLOR_PARCHMENT
		style.border_width_bottom = 6
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = COLOR_BORDER
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6

		var style_hover: StyleBoxFlat = style.duplicate()
		style_hover.bg_color = Color(0.88, 0.84, 0.72)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("focus", style_hover)
		hbox.add_child(btn)

	# Botón Volver
	var btn_back: Button = Button.new()
	btn_back.text = "VOLVER"
	btn_back.custom_minimum_size = Vector2(120, 36)
	btn_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	btn_back.add_theme_font_override("font", _font)
	btn_back.add_theme_font_size_override("font_size", 8)
	btn_back.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_width_bottom = 4
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn_back.add_theme_stylebox_override("normal", style)
	btn_back.add_theme_stylebox_override("hover", style.duplicate())
	btn_back.add_theme_stylebox_override("focus", style.duplicate())

	btn_back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn"))
	main_vbox.add_child(btn_back)
	btn_back.grab_focus()

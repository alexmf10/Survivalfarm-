## Menú Inicial (Pantalla Principal).
## Muestra 4 opciones en columna: Jugar, Opciones, User Manual, Salir.
class_name MainMenu
extends Control

# Constantes de estilo
const COLOR_SKY: Color = Color(0.53, 0.77, 0.93)
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT_BROWN: Color = Color(0.35, 0.25, 0.15)

# Escenas de sub-pantallas
const SLOTS_SCENE: String = "res://ui/menus/slots_screen.tscn"
const OPTIONS_SCENE: String = "res://ui/menus/options_screen.tscn"
const CONTROL_SCENE: String = "res://ui/menus/control_manual.tscn"

# Nodos
var overlay_container: Control
var _font: Font
var btn_play: Button


func _ready() -> void:
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()
	btn_play.grab_focus()


func _build_ui() -> void:
	# Fondo cielo
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_SKY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# VBox Central
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -100
	vbox.offset_top = -120
	vbox.offset_right = 100
	vbox.offset_bottom = 120
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Título
	var title_lbl: Label = Label.new()
	title_lbl.text = "FARM SURVIVAL"
	title_lbl.add_theme_font_override("font", _font)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Botones
	btn_play = _create_menu_button("JUGAR")
	btn_play.pressed.connect(func() -> void: get_tree().change_scene_to_file(SLOTS_SCENE))
	vbox.add_child(btn_play)

	var btn_options: Button = _create_menu_button("OPCIONES")
	btn_options.pressed.connect(func() -> void: get_tree().change_scene_to_file(OPTIONS_SCENE))
	vbox.add_child(btn_options)

	var btn_manual: Button = _create_menu_button("USER MANUAL")
	btn_manual.pressed.connect(_on_manual_pressed)
	vbox.add_child(btn_manual)

	var btn_quit: Button = _create_menu_button("SALIR")
	btn_quit.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(btn_quit)

	# Overlay container (para el manual popup) 
	overlay_container = Control.new()
	overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.visible = false
	overlay_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay_container)

	var overlay_bg: ColorRect = ColorRect.new()
	overlay_bg.color = Color(0, 0, 0, 0.4)
	overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.add_child(overlay_bg)


func _create_menu_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 40)
	
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 8)
	btn.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT_BROWN)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_BROWN)
	btn.add_theme_color_override("font_focus_color", COLOR_TEXT_BROWN)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_width_bottom = 6 # Línea doble de sombra
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	var style_hover: StyleBoxFlat = style.duplicate()
	style_hover.bg_color = Color(0.88, 0.84, 0.72) # Más claro al pasar el ratón

	var style_pressed: StyleBoxFlat = style.duplicate()
	style_pressed.border_width_bottom = 2 # Se "hunde" al pulsar
	style_pressed.content_margin_top = 4 # Desplaza el contenido hacia abajo al pulsar

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_hover)

	return btn


func _on_manual_pressed() -> void:
	var scene: PackedScene = load(CONTROL_SCENE)
	var instance: Control = scene.instantiate()
	instance.connect("back_pressed", func() -> void:
		for child: Node in overlay_container.get_children():
			if not (child is ColorRect):
				child.queue_free()
		overlay_container.visible = false
		btn_play.grab_focus()
	)
	overlay_container.visible = true
	overlay_container.add_child(instance)

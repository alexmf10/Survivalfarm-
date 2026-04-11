## Pantalla de Perfil
## Accede a ProfileService ÚNICAMENTE vía EventBus.services.
class_name ProfileScreen
extends Control

signal back_pressed

# Constantes de estilo
const COLOR_SKY: Color = Color(0.53, 0.77, 0.93)
const COLOR_WOOD_LIGHT: Color = Color(0.85, 0.75, 0.60) # Fondo panel principal
const COLOR_WOOD_DARK: Color = Color(0.65, 0.50, 0.35) # Inputs y fondo lista
const COLOR_ACHIEVEMENT_BOX: Color = Color(0.15, 0.12, 0.10) # Cajas casi negras
const COLOR_TEXT_BROWN: Color = Color(0.35, 0.20, 0.10)
const COLOR_BORDER_FRAME: Color = Color(0.45, 0.30, 0.15)


var _font: Font
var _nick_input: LineEdit
var _achievements_vbox: VBoxContainer


func _ready() -> void:
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()


func _build_ui() -> void:
	# Fondo cielo para toda la pantalla
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_SKY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Panel principal con marco madera
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_top = -140
	panel.offset_right = 200
	panel.offset_bottom = 140

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_WOOD_LIGHT
	panel_style.border_width_bottom = 4
	panel_style.border_width_top = 4
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.border_color = COLOR_BORDER_FRAME
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Fila título + botón X
	var title_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(title_row)

	var title_spacer: Control = Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_spacer)

	# Botón X cerrar
	var btn_close: Button = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(20, 20)
	btn_close.add_theme_font_override("font", _font)
	btn_close.add_theme_font_size_override("font_size", 7)
	btn_close.add_theme_color_override("font_color", COLOR_BORDER_FRAME)
	var close_style: StyleBoxFlat = StyleBoxFlat.new()
	close_style.bg_color = COLOR_WOOD_LIGHT
	close_style.border_width_bottom = 2
	close_style.border_width_top = 2
	close_style.border_width_left = 2
	close_style.border_width_right = 2
	close_style.border_color = COLOR_BORDER_FRAME
	close_style.corner_radius_top_left = 2
	close_style.corner_radius_top_right = 2
	close_style.corner_radius_bottom_left = 2
	close_style.corner_radius_bottom_right = 2
	btn_close.add_theme_stylebox_override("normal", close_style)
	btn_close.add_theme_stylebox_override("hover", close_style)
	btn_close.add_theme_stylebox_override("pressed", close_style)
	btn_close.add_theme_stylebox_override("focus", close_style)
	btn_close.pressed.connect(_on_close)
	title_row.add_child(btn_close)

	# USERNAME label
	var username_label: Label = Label.new()
	username_label.text = "USERNAME"
	username_label.add_theme_font_override("font", _font)
	username_label.add_theme_font_size_override("font_size", 7)
	username_label.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	vbox.add_child(username_label)

	# Fila input nickname + check
	var nick_row: HBoxContainer = HBoxContainer.new()
	nick_row.add_theme_constant_override("separation", 4)
	vbox.add_child(nick_row)

	_nick_input = LineEdit.new()
	_nick_input.max_length = 16
	_nick_input.placeholder_text = "Your name..."
	_nick_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nick_input.add_theme_font_override("font", _font)
	_nick_input.add_theme_font_size_override("font_size", 6)
	_nick_input.add_theme_color_override("font_color", COLOR_WOOD_LIGHT) # Light text on dark bg
	_nick_input.add_theme_color_override("font_placeholder_color", Color(0.85, 0.75, 0.60, 0.5))

	var input_style: StyleBoxFlat = StyleBoxFlat.new()
	input_style.bg_color = COLOR_WOOD_DARK
	input_style.border_width_bottom = 1
	input_style.border_width_top = 1
	input_style.border_width_left = 1
	input_style.border_width_right = 1
	input_style.border_color = COLOR_BORDER_FRAME
	input_style.content_margin_left = 4
	input_style.content_margin_right = 4
	input_style.content_margin_top = 4
	input_style.content_margin_bottom = 4
	_nick_input.add_theme_stylebox_override("normal", input_style)
	_nick_input.add_theme_stylebox_override("focus", input_style)
	nick_row.add_child(_nick_input)

	# Botón guardar (checkmark)
	var btn_save: Button = Button.new()
	btn_save.text = "OK"
	btn_save.custom_minimum_size = Vector2(28, 0)
	btn_save.add_theme_font_override("font", _font)
	btn_save.add_theme_font_size_override("font_size", 6)
	btn_save.add_theme_color_override("font_color", COLOR_BORDER_FRAME)
	btn_save.add_theme_stylebox_override("normal", close_style.duplicate())
	btn_save.add_theme_stylebox_override("hover", close_style.duplicate())
	btn_save.add_theme_stylebox_override("pressed", close_style.duplicate())
	btn_save.add_theme_stylebox_override("focus", close_style.duplicate())
	btn_save.pressed.connect(_on_save_nick)
	nick_row.add_child(btn_save)

	# ACHIEVEMENTS label
	var achiev_label: Label = Label.new()
	achiev_label.text = "ACHIEVEMENTS"
	achiev_label.add_theme_font_override("font", _font)
	achiev_label.add_theme_font_size_override("font_size", 7)
	achiev_label.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	vbox.add_child(achiev_label)

	# Scroll + lista de achievements
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(scroll)

	_achievements_vbox = VBoxContainer.new()
	_achievements_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievements_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_achievements_vbox)

	# Cargar datos
	_load_data()


func _load_data() -> void:
	var profile_svc: ProfileService = EventBus.services.profile as ProfileService
	var save_svc: SaveService = EventBus.services.save as SaveService
	if not profile_svc or not save_svc:
		return

	var info: Dictionary = save_svc.get_slot_info(profile_svc.current_slot)
	_nick_input.text = info.get("nickname", "")

	# Limpiar achievements previos
	for child: Node in _achievements_vbox.get_children():
		child.queue_free()

	# Construir filas de achievements
	var achievements: Dictionary = profile_svc.get_achievements()
	for id: String in achievements:
		var achiev: Dictionary = achievements[id]
		_add_achievement_row(achiev)


func _add_achievement_row(achiev: Dictionary) -> void:
	var is_unlocked: bool = achiev.get("unlocked", false)

	var row: PanelContainer = PanelContainer.new()
	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.bg_color = COLOR_ACHIEVEMENT_BOX if not is_unlocked else COLOR_WOOD_DARK
	row_style.border_width_bottom = 2
	row_style.border_width_top = 2
	row_style.border_width_left = 2
	row_style.border_width_right = 2
	row_style.border_color = Color(0.1, 0.1, 0.1) if not is_unlocked else COLOR_BORDER_FRAME
	row_style.corner_radius_top_left = 3
	row_style.corner_radius_top_right = 3
	row_style.corner_radius_bottom_left = 3
	row_style.corner_radius_bottom_right = 3
	row_style.content_margin_left = 6
	row_style.content_margin_right = 6
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", row_style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	# Icono
	var icon: Label = Label.new()
	icon.text = "★" if is_unlocked else "☆"
	icon.add_theme_font_size_override("font_size", 8)
	icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_unlocked else Color(0.5, 0.5, 0.5))
	icon.custom_minimum_size = Vector2(14, 0)
	hbox.add_child(icon)

	# Título + descripción
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 0)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = achiev.get("title", "???")
	title_lbl.add_theme_font_override("font", _font)
	title_lbl.add_theme_font_size_override("font_size", 5)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7) if is_unlocked else Color(0.6, 0.6, 0.6))
	info_vbox.add_child(title_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = achiev.get("description", "")
	desc_lbl.add_theme_font_override("font", _font)
	desc_lbl.add_theme_font_size_override("font_size", 4)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55) if is_unlocked else Color(0.45, 0.45, 0.45))
	info_vbox.add_child(desc_lbl)

	_achievements_vbox.add_child(row)


func _on_save_nick() -> void:
	var profile_svc: ProfileService = EventBus.services.profile as ProfileService
	var save_svc: SaveService = EventBus.services.save as SaveService
	if not profile_svc or not save_svc:
		return
	var new_nick: String = _nick_input.text.strip_edges()
	if new_nick == "":
		_nick_input.placeholder_text = "Write a name!"
		return
	save_svc.update_nickname(profile_svc.current_slot, new_nick)
	
	# También actualizar el título de la UI anterior si es necesario
	var slots: Node = get_tree().current_scene
	if slots and slots.has_method("_refresh_slots"):
		slots._refresh_slots()
		slots._update_action_area()


func _on_close() -> void:
	back_pressed.emit()
	queue_free()

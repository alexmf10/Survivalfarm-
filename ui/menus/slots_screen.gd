## Pantalla de Slots (anteriormente MainMenu).
## Permite seleccionar, nombrar, crear, jugar y borrar partidas.
class_name SlotsScreen
extends Control

# Constantes
const COLOR_SKY: Color = Color(0.53, 0.77, 0.93)
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_PARCHMENT_SELECTED: Color = Color(0.90, 0.85, 0.75) # Mucho más claro
const COLOR_PARCHMENT_EMPTY: Color = Color(0.78, 0.72, 0.60) # Ligeramente más oscuro
const COLOR_PARCHMENT_DARK: Color = Color(0.70, 0.64, 0.52)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_BORDER_SELECTED: Color = Color(1.0, 0.95, 0.8) # Borde blanco/dorado
const COLOR_TEXT_BROWN: Color = Color(0.35, 0.25, 0.15)
const COLOR_DISABLED: Color = Color(0.4, 0.35, 0.3)

var _font: Font
var _font_small: Font

# Nodos
var _slot_buttons: Array[Button] = []
var _action_vbox: VBoxContainer
var _nick_input: LineEdit
var _btn_ok_nick: Button
var _btn_profile: Button
var _btn_play_create: Button
var _btn_delete: Button
var _title_label: Label
var _overlay: Control

var _selected_slot: int = -1
var _slot_is_new: bool = false
var _nick_changed: bool = false
var _saved_nickname_for_slot: String = ""


func _ready() -> void:
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()
	_refresh_slots()
	_update_action_area()


func _build_ui() -> void:
	# Fondo (+ Deseleccionar al clickar fondo)
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_SKY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _selected_slot > 0:
				_selected_slot = -1
				_refresh_slots()
				_update_action_area()
				_title_label.text = "GAME"
	)
	add_child(bg)

	# Botón Volver e iconos superiores
	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_hbox.offset_top = 8
	top_hbox.offset_left = 12
	top_hbox.offset_right = -12
	add_child(top_hbox)

	var btn_back: Button = _create_icon_button("<", Vector2(32, 32))
	btn_back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn"))
	top_hbox.add_child(btn_back)
	
	var spacer_top: Control = Control.new()
	spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer_top)
	
	_btn_profile = _create_icon_button("P", Vector2(32, 32))
	_btn_profile.pressed.connect(_on_profile_pressed)
	top_hbox.add_child(_btn_profile)

	# Título
	_title_label = Label.new()
	_title_label.text = "GAME"
	_title_label.add_theme_font_override("font", _font)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = 35
	add_child(_title_label)

	# Contenedor de slots
	var slot_container: HBoxContainer = HBoxContainer.new()
	slot_container.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_container.add_theme_constant_override("separation", 8)
	slot_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	slot_container.set_anchor(SIDE_LEFT, 0.0)
	slot_container.set_anchor(SIDE_RIGHT, 1.0)
	slot_container.offset_top = 85
	slot_container.offset_bottom = 230
	slot_container.offset_left = 16
	slot_container.offset_right = -16
	add_child(slot_container)

	for i: int in range(1, 6):
		var slot_btn: Button = Button.new()
		slot_btn.custom_minimum_size = Vector2(100, 130)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.add_theme_font_override("font", _font)
		slot_btn.add_theme_font_size_override("font_size", 7)
		slot_btn.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
		slot_btn.add_theme_color_override("font_hover_color", COLOR_TEXT_BROWN)
		slot_btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_BROWN)
		slot_btn.add_theme_color_override("font_focus_color", COLOR_TEXT_BROWN) # Evitar que sea blanco al quedarse con el foco
		slot_btn.pressed.connect(_on_slot_pressed.bind(i))
		slot_container.add_child(slot_btn)
		_slot_buttons.append(slot_btn)

	# Zona de acciones (inferior)
	_action_vbox = VBoxContainer.new()
	_action_vbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_action_vbox.offset_top = -120
	_action_vbox.offset_bottom = -10
	_action_vbox.offset_left = -150
	_action_vbox.offset_right = 150
	_action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_vbox.add_theme_constant_override("separation", 6)
	add_child(_action_vbox)

	# Fila Nickname
	var nick_hbox: HBoxContainer = HBoxContainer.new()
	nick_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nick_hbox.add_theme_constant_override("separation", 8)
	_action_vbox.add_child(nick_hbox)

	var nick_lbl: Label = Label.new()
	nick_lbl.text = "NAME:"
	nick_lbl.add_theme_font_override("font", _font)
	nick_lbl.add_theme_font_size_override("font_size", 7)
	nick_lbl.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	nick_hbox.add_child(nick_lbl)

	_nick_input = LineEdit.new()
	_nick_input.custom_minimum_size = Vector2(120, 24)
	_nick_input.max_length = 16
	_nick_input.add_theme_font_override("font", _font)
	_nick_input.add_theme_font_size_override("font_size", 6)
	_nick_input.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	var input_style: StyleBoxFlat = StyleBoxFlat.new()
	input_style.bg_color = COLOR_PARCHMENT
	input_style.border_width_bottom = 2
	input_style.border_width_top = 1
	input_style.border_width_left = 1
	input_style.border_width_right = 1
	input_style.border_color = COLOR_BORDER
	input_style.content_margin_left = 6
	_nick_input.add_theme_stylebox_override("normal", input_style)
	_nick_input.add_theme_stylebox_override("focus", input_style)
	_nick_input.text_changed.connect(_on_nick_text_changed)
	nick_hbox.add_child(_nick_input)

	_btn_ok_nick = _create_icon_button("OK", Vector2(36, 24))
	_btn_ok_nick.pressed.connect(_on_ok_nick_pressed)
	nick_hbox.add_child(_btn_ok_nick)

	# Fila Botones (PLAY/CREATE + DEL)
	var btn_hbox: HBoxContainer = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 8)
	_action_vbox.add_child(btn_hbox)

	_btn_play_create = Button.new()
	_btn_play_create.custom_minimum_size = Vector2(160, 36)
	_btn_play_create.add_theme_font_override("font", _font)
	_btn_play_create.add_theme_font_size_override("font_size", 10)
	_btn_play_create.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	_btn_play_create.add_theme_color_override("font_hover_color", COLOR_TEXT_BROWN)
	_apply_thick_button_style(_btn_play_create)
	_btn_play_create.pressed.connect(_on_play_create_pressed)
	btn_hbox.add_child(_btn_play_create)

	_btn_delete = _create_icon_button("DEL", Vector2(40, 36))
	_apply_thick_button_style(_btn_delete)
	_btn_delete.pressed.connect(_on_delete_pressed)
	btn_hbox.add_child(_btn_delete)

	# Overlay para popups y confirmaciones
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var overlay_bg: ColorRect = ColorRect.new()
	overlay_bg.color = Color(0, 0, 0, 0.5)
	overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(overlay_bg)


func _create_icon_button(text: String, min_size: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 8)
	btn.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT_BROWN)

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

	var style_hover: StyleBoxFlat = style.duplicate()
	style_hover.bg_color = Color(0.88, 0.84, 0.72)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style_hover)
	return btn


func _apply_thick_button_style(btn: Button) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_width_bottom = 6 # Efecto 3D
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	var style_hover: StyleBoxFlat = style.duplicate()
	style_hover.bg_color = Color(0.88, 0.84, 0.72)

	var style_pressed: StyleBoxFlat = style.duplicate()
	style_pressed.border_width_bottom = 2
	style_pressed.content_margin_top = 4

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_hover)


func _refresh_slots() -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	if not save_svc: return

	for i: int in range(5):
		var slot_num: int = i + 1
		var info: Dictionary = save_svc.get_slot_info(slot_num)
		var btn: Button = _slot_buttons[i]
		
		var is_selected: bool = (slot_num == _selected_slot)

		if info["exists"]:
			var d_str: String = info.get("date_string", "")
			var d_parts: PackedStringArray = d_str.split("T")
			var date_only: String = d_parts[0] if d_parts.size() > 0 else ""
			var time_only: String = d_parts[1] if d_parts.size() > 1 else ""
			btn.text = "SLOT %d\n\n%s\n\n%s\n\n%s" % [slot_num, info.get("nickname", "???"), date_only, time_only]
		else:
			btn.text = "SLOT %d\n\n\nEMPTY\n\n\n" % slot_num
			
		btn.clip_text = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# Estilo de slot (doble linea 3D y resaltado si está seleccionado)
		var s_normal: StyleBoxFlat = StyleBoxFlat.new()
		
		# Color base
		if is_selected:
			s_normal.bg_color = COLOR_PARCHMENT_SELECTED
		elif info["exists"]:
			s_normal.bg_color = COLOR_PARCHMENT
		else:
			s_normal.bg_color = COLOR_PARCHMENT_EMPTY
			
		s_normal.border_width_bottom = 8 # 3D effect para el slot
		s_normal.border_width_top = 4 if is_selected else 3
		s_normal.border_width_left = 4 if is_selected else 3
		s_normal.border_width_right = 4 if is_selected else 3
		
		# Borde
		if is_selected:
			s_normal.border_color = COLOR_BORDER_SELECTED
		else:
			s_normal.border_color = COLOR_BORDER
			
		s_normal.corner_radius_top_left = 6
		s_normal.corner_radius_top_right = 6
		s_normal.corner_radius_bottom_left = 6
		s_normal.corner_radius_bottom_right = 6
		
		var s_hover: StyleBoxFlat = s_normal.duplicate()
		s_hover.bg_color = COLOR_PARCHMENT_SELECTED if is_selected else COLOR_PARCHMENT
		s_hover.border_color = COLOR_BORDER_SELECTED if is_selected else COLOR_TEXT_BROWN

		btn.add_theme_stylebox_override("normal", s_normal)
		btn.add_theme_stylebox_override("hover", s_hover)
		btn.add_theme_stylebox_override("pressed", s_hover)
		btn.add_theme_stylebox_override("focus", s_hover)


func _update_action_area() -> void:
	if _selected_slot <= 0:
		_action_vbox.visible = false
		if _btn_profile: _btn_profile.visible = false
		return
	
	_action_vbox.visible = true
	var save_svc: SaveService = EventBus.services.save as SaveService
	var info: Dictionary = save_svc.get_slot_info(_selected_slot)
	
	_slot_is_new = not info["exists"]
	
	if _btn_profile:
		_btn_profile.visible = not _slot_is_new # Ocultar Perfil si el slot está vacío
	
	if _slot_is_new:
		_btn_play_create.text = "CREATE"
		_btn_delete.visible = false
		_saved_nickname_for_slot = ""
	else:
		_btn_play_create.text = "PLAY"
		_btn_delete.visible = true
		_saved_nickname_for_slot = info.get("nickname", "")
		
	_nick_input.text = _saved_nickname_for_slot
	_on_nick_text_changed(_nick_input.text)


func _on_slot_pressed(slot: int) -> void:
	_selected_slot = slot
	var prof: ProfileService = EventBus.services.profile as ProfileService
	if prof:
		prof.load_profile(slot) # Cargar perfil de este slot
	_refresh_slots()
	_update_action_area()
	_title_label.text = "GAME"


# Lógica Nickname OK

func _on_nick_text_changed(new_text: String) -> void:
	new_text = new_text.strip_edges()
	_nick_changed = (new_text != "" and new_text != _saved_nickname_for_slot)
	
	var style: StyleBoxFlat = _btn_ok_nick.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if _nick_changed:
		_btn_ok_nick.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
		style.bg_color = COLOR_PARCHMENT
	else:
		_btn_ok_nick.add_theme_color_override("font_color", COLOR_DISABLED)
		style.bg_color = COLOR_PARCHMENT_DARK
		
	_btn_ok_nick.add_theme_stylebox_override("normal", style)


func _on_ok_nick_pressed() -> void:
	if not _nick_changed: return
	
	var new_name: String = _nick_input.text.strip_edges()
	_saved_nickname_for_slot = new_name
	_on_nick_text_changed(new_name)
	
	# Guardamos el nickname en el save del slot si la partida ya existe
	if not _slot_is_new:
		var save_svc: SaveService = EventBus.services.save as SaveService
		if save_svc:
			save_svc.update_nickname(_selected_slot, new_name)
		_title_label.text = "Nombre actualizado a %s" % new_name
		_refresh_slots() # Refrescar la UI del slot para mostrar el nuevo nombre
	else:
		_title_label.text = "Se usara al crear"


# Play / Create / Delete

func _on_play_create_pressed() -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	
	if _slot_is_new:
		# Create
		var nick: String = _nick_input.text.strip_edges()
		if nick == "":
			_title_label.text = "Ingresa un nombre primero!"
			return
		save_svc.create_new_game(_selected_slot, nick)
		_title_label.text = "Partida creada!"
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			_title_label.text = "GAME"
		)
		# Se refresca el slot y area
		_selected_slot = _selected_slot # Mantiene el mismo
		_refresh_slots()
		_update_action_area()
	else:
		# Play — guardar el slot activo para que GameWorld lo lea, luego navegar
		var save_svc_play: SaveService = EventBus.services.save as SaveService
		if save_svc_play:
			save_svc_play.active_slot = _selected_slot
		get_tree().change_scene_to_file("res://core/game_world.tscn")


func _on_delete_pressed() -> void:
	# Mostrar dialogo de Confirmation
	for child: Node in _overlay.get_children():
		if not (child is ColorRect):
			child.queue_free()
			
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_width_bottom = 4
	style.border_width_top = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_color = COLOR_BORDER
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.content_margin_left = 20
	style.content_margin_right = 20
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var lbl: Label = Label.new()
	lbl.text = "Seguro que quieres eliminar\nesta partida?"
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var btn_ok: Button = _create_icon_button("OK", Vector2(80, 30))
	btn_ok.pressed.connect(_confirm_delete)
	hbox.add_child(btn_ok)

	var btn_cancel: Button = _create_icon_button("Cancelar", Vector2(80, 30))
	btn_cancel.pressed.connect(_hide_overlay)
	hbox.add_child(btn_cancel)

	_overlay.visible = true


func _confirm_delete() -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	save_svc.delete_slot(_selected_slot)
	_hide_overlay()
	_refresh_slots()
	_update_action_area()
	_title_label.text = "GAME"


func _hide_overlay() -> void:
	_overlay.visible = false
	for child: Node in _overlay.get_children():
		if not (child is ColorRect):
			child.queue_free()


func _on_profile_pressed() -> void:
	if _selected_slot <= 0 or _slot_is_new: return
	var scene: PackedScene = load("res://ui/menus/profile_screen.tscn")
	var inst: Control = scene.instantiate()
	inst.connect("back_pressed", _hide_overlay)
	_overlay.visible = true
	_overlay.add_child(inst)

## Pantalla de Login / Registro con Supabase Auth.
## Permite al jugador iniciar sesión, registrarse, o continuar como invitado.
class_name AuthScreen
extends Control

const COLOR_SKY: Color = Color(0.53, 0.77, 0.93)
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_PARCHMENT_DARK: Color = Color(0.70, 0.64, 0.52)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT_BROWN: Color = Color(0.35, 0.25, 0.15)
const COLOR_DISABLED: Color = Color(0.4, 0.35, 0.3)
const COLOR_ERROR: Color = Color(0.75, 0.2, 0.2)

var _font: Font
var _mode: String = "login"  # "login" or "register"

var _email_input: LineEdit
var _password_input: LineEdit
var _confirm_input: LineEdit
var _confirm_row: HBoxContainer
var _btn_submit: Button
var _btn_toggle: Button
var _status_label: Label
var _title_label: Label


func _ready() -> void:
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_SKY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Back / guest button (top-left)
	var btn_back: Button = _create_button("<", Vector2(32, 32))
	btn_back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn_back.offset_top = 8
	btn_back.offset_left = 12
	btn_back.offset_right = 44
	btn_back.offset_bottom = 40
	btn_back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/menus/slots_screen.tscn"))
	add_child(btn_back)

	# Center panel
	var panel: PanelContainer = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PARCHMENT
	panel_style.border_width_bottom = 6
	panel_style.border_width_top = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = COLOR_BORDER
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = -140
	panel.offset_bottom = 140
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "LOGIN"
	_title_label.add_theme_font_override("font", _font)
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Toggle tab row
	var tab_hbox: HBoxContainer = HBoxContainer.new()
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(tab_hbox)

	var btn_login_tab: Button = _create_button("LOGIN", Vector2(80, 24))
	btn_login_tab.pressed.connect(func() -> void: _set_mode("login"))
	tab_hbox.add_child(btn_login_tab)

	var btn_register_tab: Button = _create_button("REGISTER", Vector2(90, 24))
	btn_register_tab.pressed.connect(func() -> void: _set_mode("register"))
	tab_hbox.add_child(btn_register_tab)

	# Email row
	var email_row: HBoxContainer = _create_field_row("EMAIL:")
	_email_input = _create_line_edit()
	email_row.add_child(_email_input)
	vbox.add_child(email_row)

	# Password row
	var pass_row: HBoxContainer = _create_field_row("PASS: ")
	_password_input = _create_line_edit()
	_password_input.secret = true
	pass_row.add_child(_password_input)
	vbox.add_child(pass_row)

	# Confirm password row (register only)
	_confirm_row = _create_field_row("CONF: ")
	_confirm_input = _create_line_edit()
	_confirm_input.secret = true
	_confirm_row.add_child(_confirm_input)
	_confirm_row.visible = false
	vbox.add_child(_confirm_row)

	# Submit button
	_btn_submit = _create_button("ENTRAR", Vector2(160, 36))
	_btn_submit.add_theme_font_size_override("font_size", 10)
	_btn_submit.pressed.connect(_on_submit_pressed)
	vbox.add_child(_btn_submit)

	# Guest button
	var btn_guest: Button = _create_button("JUGAR SIN CUENTA", Vector2(200, 28))
	btn_guest.add_theme_font_size_override("font_size", 6)
	btn_guest.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/menus/slots_screen.tscn"))
	vbox.add_child(btn_guest)

	# Status label
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_override("font", _font)
	_status_label.add_theme_font_size_override("font_size", 5)
	_status_label.add_theme_color_override("font_color", COLOR_ERROR)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(240, 0)
	vbox.add_child(_status_label)


func _set_mode(mode: String) -> void:
	_mode = mode
	_confirm_row.visible = (mode == "register")
	_title_label.text = "LOGIN" if mode == "login" else "REGISTER"
	_btn_submit.text = "ENTRAR" if mode == "login" else "CREAR"
	_status_label.text = ""


func _on_submit_pressed() -> void:
	var email: String = _email_input.text.strip_edges()
	var password: String = _password_input.text
	var confirm: String = _confirm_input.text

	if email == "" or password == "":
		_show_error("Rellena todos los campos.")
		return
	if _mode == "register" and password != confirm:
		_show_error("Las contraseñas no coinciden.")
		return

	_btn_submit.disabled = true
	_btn_submit.text = "..."
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_BROWN)

	var auth: AuthService = EventBus.services.auth as AuthService
	if not auth:
		_show_error("AuthService no disponible.")
		_btn_submit.disabled = false
		return

	var callback: Callable = func(ok: bool, error: String) -> void:
		_btn_submit.disabled = false
		_btn_submit.text = "ENTRAR" if _mode == "login" else "CREAR"
		if ok:
			get_tree().change_scene_to_file("res://ui/menus/slots_screen.tscn")
		else:
			_show_error(error)

	if _mode == "login":
		auth.sign_in(email, password, callback)
	else:
		auth.sign_up(email, password, callback)


func _show_error(msg: String) -> void:
	_status_label.add_theme_color_override("font_color", COLOR_ERROR)
	_status_label.text = msg


func _create_field_row(label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	lbl.custom_minimum_size = Vector2(52, 0)
	row.add_child(lbl)
	return row


func _create_line_edit() -> LineEdit:
	var le: LineEdit = LineEdit.new()
	le.custom_minimum_size = Vector2(160, 24)
	le.add_theme_font_override("font", _font)
	le.add_theme_font_size_override("font_size", 6)
	le.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.88, 0.76)
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.content_margin_left = 6
	le.add_theme_stylebox_override("normal", style)
	le.add_theme_stylebox_override("focus", style)
	return le


func _create_button(text: String, min_size: Vector2) -> Button:
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
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	var style_hover: StyleBoxFlat = style.duplicate()
	style_hover.bg_color = Color(0.88, 0.84, 0.72)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style_hover)
	return btn

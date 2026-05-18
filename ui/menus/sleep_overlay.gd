extends CanvasLayer

signal completed

const FADE_TIME: float = 1.0
const HOLD_TIME: float = 1.0
const UI_FONT_PATH: String = "res://ui/theme/PressStart2P-Regular.ttf"
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT: Color = Color(0.35, 0.25, 0.15)

@onready var black: ColorRect = $BlackScreen

var _font: Font
var _panel: PanelContainer
var _body_label: Label
var _can_close: bool = false
var _new_day: int = 1


func _ready() -> void:
	_font = load(UI_FONT_PATH) as Font
	black.modulate.a = 0.0
	_build_message_panel()


func play_sleep_sequence(new_day: int, save_callback: Callable) -> void:
	_new_day = new_day
	_can_close = false
	_panel.visible = false

	var tween: Tween = create_tween()
	tween.tween_property(black, "modulate:a", 1.0, FADE_TIME)
	tween.tween_callback(save_callback)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(black, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_show_message)


func _build_message_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(340, 116)
	_panel.offset_left = -170
	_panel.offset_top = -58
	_panel.offset_right = 170
	_panel.offset_bottom = 58
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_gui_input)
	_panel.add_theme_stylebox_override("panel", _make_wood_panel_style(14))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "YOU SLEPT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.23, 0.15, 0.08))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.70, 0.62, 0.45))
	box.add_child(title)

	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font:
		_body_label.add_theme_font_override("font", _font)
	_body_label.add_theme_font_size_override("font_size", 8)
	_body_label.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(_body_label)

	var hint := Label.new()
	hint.text = "E / ENTER / ESC"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 6)
	hint.add_theme_color_override("font_color", Color(0.47, 0.34, 0.20))
	box.add_child(hint)


func _make_wood_panel_style(content_margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_color = COLOR_BORDER
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_bottom = 6
	style.set_corner_radius_all(4)
	style.set_content_margin_all(content_margin)
	return style


func _show_message() -> void:
	_body_label.text = "Game saved\nDay %d" % _new_day
	_panel.visible = true
	_panel.modulate.a = 0.0
	_can_close = true

	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2)


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_accept()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_close:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()
			_accept()


func _accept() -> void:
	if not _can_close:
		return
	_can_close = false
	completed.emit()
	queue_free()

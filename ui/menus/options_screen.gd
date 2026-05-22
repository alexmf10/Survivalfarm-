class_name OptionsScreen
extends Control

const COLOR_SKY: Color = Color(0.53, 0.77, 0.93)
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT_BROWN: Color = Color(0.35, 0.25, 0.15)

var _font: Font
var _sfx_slider: HSlider
var _music_slider: HSlider


func _ready() -> void:
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()
	_connect_sound_service()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_SKY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.offset_left = -260
	main_vbox.offset_top = -120
	main_vbox.offset_right = 260
	main_vbox.offset_bottom = 120
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	_sfx_slider = _add_volume_row(main_vbox, "SFX VOLUME")
	_music_slider = _add_volume_row(main_vbox, "MUSIC VOLUME")

	var btn_back: Button = Button.new()
	btn_back.text = "BACK"
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


func _add_volume_row(parent: VBoxContainer, label_text: String) -> HSlider:
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", COLOR_TEXT_BROWN)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(400, 24)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(slider)

	return slider


func _connect_sound_service() -> void:
	var sound_svc := EventBus.services.get_service(&"sound") as SoundService
	if sound_svc == null:
		return
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		sound_svc.set_sfx_volume(v / 100.0))
	_music_slider.value_changed.connect(func(v: float) -> void:
		sound_svc.set_music_volume(v / 100.0))

## UI de comercio con estilo pixel art (tonalidad madera, fuente PressStart2P).
## Se muestra al pulsar E cerca del comerciante. Cierre con ESC.
class_name TradeHUD
extends CanvasLayer

# ── Paleta de colores (misma que MainMenu / TestToolbarHUD) ────────────────
const COLOR_PARCHMENT:      Color = Color(0.82, 0.76, 0.63)
const COLOR_PARCHMENT_DARK: Color = Color(0.68, 0.61, 0.48)
const COLOR_PARCHMENT_LIGHT:Color = Color(0.90, 0.85, 0.74)
const COLOR_BORDER:         Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT:           Color = Color(0.35, 0.25, 0.15)
const COLOR_TEXT_LIGHT:     Color = Color(0.55, 0.42, 0.28)
const COLOR_GOLD:           Color = Color(0.82, 0.62, 0.08)
const COLOR_SELL:           Color = Color(0.38, 0.60, 0.28)
const COLOR_BUY:            Color = Color(0.28, 0.42, 0.68)
const COLOR_DISABLED:       Color = Color(0.52, 0.48, 0.42)

var _font: Font
var _coins_label: Label
var _sell_rows: Dictionary = {}  # CropType → { label, button }
var _buy_rows:  Dictionary = {}  # CropType → { label, button }


func _ready() -> void:
	layer = 20
	visible = false
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()
	EventBus.trade_opened.connect(_on_trade_opened)
	EventBus.inventory_updated.connect(_on_inventory_updated)


# ── Construcción de la UI ──────────────────────────────────────────────────

func _build_ui() -> void:
	# Fondo semitransparente
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.10, 0.07, 0.04, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Panel principal centrado
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left  = -150
	panel.offset_right =  150
	panel.offset_top   = -185
	panel.offset_bottom =  185

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PARCHMENT
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_top    = 3
	panel_style.border_width_left   = 3
	panel_style.border_width_right  = 3
	panel_style.border_width_bottom = 6
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# ── Cabecera ──────────────────────────────────────────────────────────
	var title: Label = _make_label("[ TRADER ]", 10, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_coins_label = _make_label("COINS: 50", 7, COLOR_GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_coins_label)

	vbox.add_child(_make_separator())

	# ── Sección venta ─────────────────────────────────────────────────────
	vbox.add_child(_make_label("-- SELL --", 7, COLOR_SELL))
	_add_sell_row(vbox, CropComponent.CropType.Wheat, 5)
	_add_sell_row(vbox, CropComponent.CropType.Beet,  8)

	vbox.add_child(_make_separator())

	# ── Sección compra ────────────────────────────────────────────────────
	vbox.add_child(_make_label("-- BUY SEEDS --", 7, COLOR_BUY))
	_add_buy_row(vbox, CropComponent.CropType.Wheat, 3)
	_add_buy_row(vbox, CropComponent.CropType.Beet,  5)

	vbox.add_child(_make_separator())

	# ── Pie ───────────────────────────────────────────────────────────────
	var close_hint: Label = _make_label("[ ESC ] CLOSE", 5, COLOR_TEXT_LIGHT)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(close_hint)


func _add_sell_row(parent: VBoxContainer, crop_type: CropComponent.CropType, price: int) -> void:
	var crop_name: String = TradeService.CROP_NAMES.get(crop_type, "?").to_upper()
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var lbl: Label = _make_label("%s  x0" % crop_name, 6, COLOR_TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn: Button = _make_button("+%dg" % price, COLOR_SELL)
	btn.pressed.connect(func() -> void: _on_sell_pressed(crop_type))
	hbox.add_child(btn)

	_sell_rows[crop_type] = {"label": lbl, "button": btn}


func _add_buy_row(parent: VBoxContainer, crop_type: CropComponent.CropType, cost: int) -> void:
	var crop_name: String = TradeService.CROP_NAMES.get(crop_type, "?").to_upper()
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var lbl: Label = _make_label("%s x0" % crop_name, 6, COLOR_TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn: Button = _make_button("-%dg" % cost, COLOR_BUY)
	btn.pressed.connect(func() -> void: _on_buy_pressed(crop_type))
	hbox.add_child(btn)

	_buy_rows[crop_type] = {"label": lbl, "button": btn}


# ── Helpers de estilo ──────────────────────────────────────────────────────

func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_button(text: String, color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 6)
	btn.add_theme_color_override("font_color", COLOR_PARCHMENT_LIGHT)
	btn.add_theme_color_override("font_hover_color",   COLOR_PARCHMENT_LIGHT)
	btn.add_theme_color_override("font_pressed_color", COLOR_PARCHMENT_LIGHT)
	btn.add_theme_color_override("font_disabled_color", COLOR_PARCHMENT_DARK)

	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = COLOR_BORDER
	s.border_width_top    = 2
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_width_bottom = 4
	s.set_corner_radius_all(0)
	s.set_content_margin_all(5)
	btn.add_theme_stylebox_override("normal", s)

	var h: StyleBoxFlat = s.duplicate()
	h.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)

	var p: StyleBoxFlat = s.duplicate()
	p.border_width_bottom = 2
	p.content_margin_top = 4
	btn.add_theme_stylebox_override("pressed", p)

	var d: StyleBoxFlat = s.duplicate()
	d.bg_color = COLOR_DISABLED
	d.border_color = COLOR_BORDER.darkened(0.2)
	btn.add_theme_stylebox_override("disabled", d)

	return btn


func _make_separator() -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	var sep_style: StyleBoxFlat = StyleBoxFlat.new()
	sep_style.bg_color = COLOR_BORDER
	sep_style.content_margin_top    = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


# ── Lógica ────────────────────────────────────────────────────────────────

func _on_trade_opened() -> void:
	visible = true
	_refresh_ui()


func _on_inventory_updated(_coins: int) -> void:
	if visible:
		_refresh_ui()


func _refresh_ui() -> void:
	var trade_svc := EventBus.services.trade as TradeService
	if not trade_svc:
		return

	_coins_label.text = "COINS: %d" % trade_svc.coins

	for crop_type: int in _sell_rows:
		var row: Dictionary = _sell_rows[crop_type]
		var count: int = trade_svc.get_crop_count(crop_type)
		var crop_name: String = TradeService.CROP_NAMES.get(crop_type, "?").to_upper()
		(row["label"] as Label).text = "%s  x%d" % [crop_name, count]
		(row["button"] as Button).disabled = count <= 0

	for crop_type: int in _buy_rows:
		var row: Dictionary = _buy_rows[crop_type]
		var seeds: int = trade_svc.get_seed_count(crop_type)
		var cost: int  = TradeService.SEED_PRICES.get(crop_type, 0)
		var crop_name: String = TradeService.CROP_NAMES.get(crop_type, "?").to_upper()
		(row["label"] as Label).text = "%s x%d" % [crop_name, seeds]
		(row["button"] as Button).disabled = trade_svc.coins < cost


func _on_sell_pressed(crop_type: CropComponent.CropType) -> void:
	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc:
		trade_svc.sell_crop(crop_type)


func _on_buy_pressed(crop_type: CropComponent.CropType) -> void:
	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc:
		trade_svc.buy_seeds(crop_type)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		get_viewport().set_input_as_handled()
		visible = false
		EventBus.trade_closed.emit()

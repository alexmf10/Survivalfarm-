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
var _equipment_rows: Dictionary = {}  # Tools → { label, button }
var _armor_upgrade_rows: Dictionary = {} # Tools -> { label, button }


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

	# Contenedor principal (Todo lo fijo va aquí)
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# ── Cabecera ───────────────────────────────────────────────────
	var title: Label = _make_label("[ TRADER ]", 10, COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	_coins_label = _make_label("COINS: 0", 7, COLOR_GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_coins_label)

	main_vbox.add_child(_make_separator())

	# Contenedor con Scroll 
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL 
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var v_bar: VScrollBar = scroll.get_v_scroll_bar()
	v_bar.custom_minimum_size.x = 5 
	
	# Desplazamiento en píxeles hacia la derecha
	var pixels_to_right: int = 6 

	# Estilo del Canal de fondo (Track)
	var track_style: StyleBoxFlat = StyleBoxFlat.new()
	track_style.bg_color = COLOR_PARCHMENT_DARK # Color pergamino oscuro de fondo
	track_style.set_corner_radius_all(0)
	track_style.expand_margin_right = pixels_to_right
	track_style.expand_margin_left = -pixels_to_right
	v_bar.add_theme_stylebox_override("scroll", track_style)
	
	var grabber_style: StyleBoxFlat = StyleBoxFlat.new()
	grabber_style.bg_color = COLOR_BORDER
	grabber_style.set_corner_radius_all(0)
	grabber_style.expand_margin_right = pixels_to_right
	grabber_style.expand_margin_left = -pixels_to_right
	
	v_bar.add_theme_stylebox_override("grabber", grabber_style)
	
	var grabber_hover = grabber_style.duplicate()
	grabber_hover.bg_color = COLOR_BORDER.lightened(0.15) # Un toque más claro al pasar el ratón
	v_bar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	v_bar.add_theme_stylebox_override("grabber_pressed", grabber_style)
	# ──────────────────────────────────────────────────────────────────────

	# Contenedor para los items (Dentro del scroll)
	var scroll_vbox: VBoxContainer = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_vbox)

	# ── Sección venta ────────────────────────────────────────
	scroll_vbox.add_child(_make_label("-- SELL --", 7, COLOR_SELL))
	_add_sell_row(scroll_vbox, CropComponent.CropType.Wheat)
	_add_sell_row(scroll_vbox, CropComponent.CropType.Beet)
	_add_sell_row(scroll_vbox, CropComponent.CropType.Lavender)
	_add_sell_row(scroll_vbox, CropComponent.CropType.Ember_lily)
	_add_sell_row(scroll_vbox, CropComponent.CropType.Cotton)

	scroll_vbox.add_child(_make_separator())

	# ── Sección compra ───────────────────────────────────────
	scroll_vbox.add_child(_make_label("-- BUY SEEDS --", 7, COLOR_BUY))
	_add_buy_row(scroll_vbox, CropComponent.CropType.Wheat)
	_add_buy_row(scroll_vbox, CropComponent.CropType.Beet)
	_add_buy_row(scroll_vbox, CropComponent.CropType.Lavender)
	_add_buy_row(scroll_vbox, CropComponent.CropType.Ember_lily)
	_add_buy_row(scroll_vbox, CropComponent.CropType.Cotton)

	scroll_vbox.add_child(_make_separator())
	
# ── Sección equipamiento ───────────────────────────────────────
	scroll_vbox.add_child(_make_label("-- BUY EQUIPMENT --", 7, COLOR_BUY))
	_add_equipment_row(scroll_vbox, ToolsComponent.Tools.Helm, 15)
	_add_equipment_row(scroll_vbox, ToolsComponent.Tools.Chest, 25)
	_add_equipment_row(scroll_vbox, ToolsComponent.Tools.Bot, 10)
	_add_equipment_row(scroll_vbox, ToolsComponent.Tools.Sword, 0)	
	
	scroll_vbox.add_child(_make_separator())
	
	# ── Sección mejoras ───────────────────────────────────────
	scroll_vbox.add_child(_make_label("-- UPGRADE EQUIPMENT --", 7, COLOR_BUY))
	_add_armor_upgrade_row(scroll_vbox, ToolsComponent.Tools.Helm)
	_add_armor_upgrade_row(scroll_vbox, ToolsComponent.Tools.Chest)
	_add_armor_upgrade_row(scroll_vbox, ToolsComponent.Tools.Bot)
	_add_armor_upgrade_row(scroll_vbox, ToolsComponent.Tools.Sword)

	scroll_vbox.add_child(_make_separator())

	
	# ── Pie ────────────────────────────────────────────────────────
	var close_hint: Label = _make_label("[ E / ESC ] CLOSE", 5, COLOR_TEXT_LIGHT)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(close_hint)


func _add_sell_row(parent: VBoxContainer, crop_type: CropComponent.CropType) -> void:
	var crop_name: String = TradeService.CROP_NAMES.get(crop_type, "?").to_upper()
	var price: int = TradeService.SELL_PRICES.get(crop_type, 0)
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


func _add_buy_row(parent: VBoxContainer, crop_type: CropComponent.CropType) -> void:
	var crop_name: String = TradeService.CROP_NAMES.get(crop_type, "?").to_upper()
	var cost: int = TradeService.SEED_PRICES.get(crop_type, 0)
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

func _add_equipment_row(parent: VBoxContainer, tool_type: ToolsComponent.Tools, cost: int) -> void:
	var tool_name: String = TradeService.EQUIPMENT_NAMES.get(int(tool_type), "?").to_upper()
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	# A diferencia de las semillas, el equipo no muestra cantidad "x0"
	var lbl: Label = _make_label("%s" % tool_name, 6, COLOR_TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn: Button = _make_button("-%dg" % cost, COLOR_BUY)
	btn.pressed.connect(func() -> void: _on_buy_equipment_pressed(tool_type))
	hbox.add_child(btn)

	_equipment_rows[int(tool_type)] = {"label": lbl, "button": btn, "cost": cost}

func _on_buy_equipment_pressed(tool_type: ToolsComponent.Tools) -> void:
	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc:
		# Llamaremos a una nueva función en el TradeService
		trade_svc.buy_equipment(tool_type)


func _add_armor_upgrade_row(parent: VBoxContainer, tool_type: ToolsComponent.Tools) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var lbl: Label = _make_label("...", 6, COLOR_TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn: Button = _make_button("-???g", COLOR_BUY)
	btn.pressed.connect(func() -> void: _on_buy_armor_pressed(tool_type))
	hbox.add_child(btn)

	_armor_upgrade_rows[int(tool_type)] = {"label": lbl, "button": btn}

func _on_buy_armor_pressed(tool_type: ToolsComponent.Tools) -> void:
	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc:
		trade_svc.buy_armor_upgrade(tool_type)

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


func _on_inventory_updated(_slots: Array, _coins: int) -> void:
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

	for tool_type in _equipment_rows:
		var row: Dictionary = _equipment_rows[tool_type]
		var cost: int = row.get("cost", 0)
		(row["button"] as Button).disabled = trade_svc.coins < cost

	for tool_type in _armor_upgrade_rows:
		var row: Dictionary = _armor_upgrade_rows[tool_type]
		var current_lvl: int = trade_svc.armor_levels.get(tool_type, 0)
		var piece_name: String = TradeService.EQUIPMENT_NAMES.get(tool_type, "?").to_upper()

		var lbl: Label = row["label"]
		var btn: Button = row["button"]

		if current_lvl >= 3:
			lbl.text = "%s (MAX LVL)" % piece_name
			btn.text = "MAXED"
			btn.disabled = true
		else:
			var next_lvl: int = current_lvl + 1
			var price: int = TradeService.ARMOR_UPGRADE_PRICES[tool_type][current_lvl]
			lbl.text = "%s LVL %d" % [piece_name, next_lvl]
			btn.text = "-%dg" % price
			btn.disabled = trade_svc.coins < price


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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		visible = false
		EventBus.trade_closed.emit()

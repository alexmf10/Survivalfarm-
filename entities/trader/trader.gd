class_name Trader
extends Node2D

const INTERACT_RADIUS: float = 48.0

var _player_in_range: bool = false
var _trade_open: bool = false
var _hint_label: Label


func _ready() -> void:
	_build_visual()
	z_index = int(global_position.y)
	EventBus.trade_opened.connect(func() -> void: _trade_open = true)
	EventBus.trade_closed.connect(func() -> void: _trade_open = false)


func _build_visual() -> void:
	position.y += 32

	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/textures/shop/shop.png")
	sprite.centered = true
	sprite.position = Vector2(0, -32)
	add_child(sprite)

	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 12)
	col.shape = shape
	col.position = Vector2(0, -8)
	body.add_child(col)
	add_child(body)

	var name_label := Label.new()
	name_label.text = "TRADER"
	name_label.add_theme_font_size_override("font_size", 6)
	name_label.position = Vector2(-18, -34)
	add_child(name_label)

	_hint_label = Label.new()
	_hint_label.text = "[E] Trade"
	_hint_label.add_theme_font_size_override("font_size", 5)
	_hint_label.position = Vector2(-16, -44)
	_hint_label.visible = false
	add_child(_hint_label)


func _process(_delta: float) -> void:
	var player_svc := EventBus.services.player as PlayerService
	if not player_svc or not player_svc.has_player():
		return
	var dist: float = global_position.distance_to(player_svc.get_position())
	var in_range: bool = dist <= INTERACT_RADIUS
	if in_range != _player_in_range:
		_player_in_range = in_range
		_hint_label.visible = in_range and not _trade_open


func _input(event: InputEvent) -> void:
	if not _player_in_range or _trade_open or EventBus.dialogue_open:
		return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var trade_svc := EventBus.services.trade as TradeService
		if trade_svc and not trade_svc.starter_pack_granted:
			trade_svc.grant_starter_pack()
			EventBus.starter_pack_received.emit()
			EventBus.dialogue_requested.emit("Trader", "I saw you come down the road. Bad idea arriving empty-handed.\n\nTake these seeds and tools. Plant fast. When the collector appears, do not argue.")
			return
		EventBus.trade_opened.emit()

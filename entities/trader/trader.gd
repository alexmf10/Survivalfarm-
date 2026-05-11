## Entidad del comerciante. Visual temporal con ColorRect (morado).
## Detecta la proximidad del jugador via PlayerService (sin depender de capas de colisión).
## Abre la UI de comercio al pulsar E.
##
## --- Interacción ---
## • _process compara distancia al jugador cada frame (radio INTERACT_RADIUS px).
## • Cuando el jugador entra en rango: muestra el hint "[E] Trade".
## • Al pulsar E cerca del comerciante: consume el input y emite trade_opened.
## • Usa _input (antes que _unhandled_input) para tener prioridad sobre ToolComponent.
class_name Trader
extends Node2D

const INTERACT_RADIUS: float = 48.0

var _player_in_range: bool = false
var _trade_open: bool = false
var _hint_label: Label


func _ready() -> void:
	_build_visual()
	# z_index para depth-sort: la posición ya fue ajustada al base del cart en _build_visual
	z_index = int(global_position.y)
	EventBus.trade_opened.connect(func() -> void: _trade_open = true)
	EventBus.trade_closed.connect(func() -> void: _trade_open = false)


func _build_visual() -> void:
	# Y-sort: queremos que el sort key (= position.y) sea la BASE del cart.
	# El marker del trader está en el centro visual del cart. Para conseguir
	# que la posición sea la base, desplazamos +32 (mitad de shop.png 64×64)
	# y compensamos el sprite con -32 para que visualmente quede igual.
	position.y += 32

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load("res://assets/textures/shop/shop.png")
	sprite.centered = true
	sprite.position = Vector2(0, -32)
	add_child(sprite)

	# Cuerpo estático pequeño en la base del carro
	var body: StaticBody2D = StaticBody2D.new()
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(28, 12)
	col.shape = shape
	col.position = Vector2(0, -8)  # justo encima de la base del cart
	body.add_child(col)
	add_child(body)

	var name_label: Label = Label.new()
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
	if not _player_in_range or _trade_open:
		return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		EventBus.trade_opened.emit()

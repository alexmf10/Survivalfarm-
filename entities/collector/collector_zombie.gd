class_name CollectorZombie
extends Node2D

const INTERACT_RADIUS: float = 42.0
const FRAME_SIZE: Vector2i = Vector2i(16, 32)
const FRAMES_PER_DIRECTION: int = 6

var _player_in_range: bool = false
var _hint_label: Label
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_build_visual()
	_build_hint()
	z_index = int(global_position.y)


func _build_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.position = Vector2(0, -12)
	_sprite.sprite_frames = _build_frames()
	_sprite.animation = &"idle_down"
	_sprite.play()
	add_child(_sprite)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	var texture: Texture2D = load("res://assets/sprites/zombie idle.png") as Texture2D
	if texture == null:
		return frames

	var directions: Array[String] = ["right", "up", "left", "down"]
	for direction_index in range(directions.size()):
		var anim_name := "idle_%s" % directions[direction_index]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		frames.set_animation_loop(anim_name, true)
		for frame_index in range(FRAMES_PER_DIRECTION):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				(direction_index * FRAMES_PER_DIRECTION + frame_index) * FRAME_SIZE.x,
				0,
				FRAME_SIZE.x,
				FRAME_SIZE.y
			)
			frames.add_frame(anim_name, atlas)

	return frames


func _build_hint() -> void:
	_hint_label = Label.new()
	_hint_label.text = "[E] Collector"
	_hint_label.add_theme_font_size_override("font_size", 5)
	_hint_label.position = Vector2(-34, -44)
	_hint_label.visible = false
	add_child(_hint_label)


func _process(_delta: float) -> void:
	var player_svc := EventBus.services.player as PlayerService
	if not player_svc or not player_svc.has_player():
		return

	var in_range := global_position.distance_to(player_svc.get_position()) <= INTERACT_RADIUS
	if in_range != _player_in_range:
		_player_in_range = in_range
		_hint_label.visible = in_range


func _input(event: InputEvent) -> void:
	if not _player_in_range or EventBus.dialogue_open:
		return
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var tribute_svc := EventBus.services.tribute as TributeService
		if tribute_svc == null:
			return
		EventBus.dialogue_requested.emit("Collector", tribute_svc.interact_with_collector())

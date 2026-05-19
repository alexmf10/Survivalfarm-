class_name ZombieArcherShootComponent
extends Node

const ARROW_SCENE_PATH: String = "res://entities/zombie_archer/arrow.tscn"

enum State { IDLE, WINDUP, RECOVERY }

@export var base_damage: float = 12.0
@export var recovery_duration: float = 1.8
@export var hit_stun_duration: float = 0.25

var _state: int = State.IDLE
var _recovery_timer: float = 0.0
var _locked_target_pos: Vector2 = Vector2.ZERO

var _body: CharacterBody2D
var _animation: AnimationComponent
var _movement: MovementComponent


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		set_process(false)
		return
	for child in _body.get_children():
		if child is AnimationComponent:
			_animation = child
		if child is MovementComponent:
			_movement = child


func _process(delta: float) -> void:
	if _state == State.RECOVERY:
		_recovery_timer -= delta
		if _recovery_timer <= 0.0:
			_state = State.IDLE


func is_busy() -> bool:
	return _state != State.IDLE


func try_shoot(target_pos: Vector2) -> bool:
	if _state != State.IDLE:
		return false
	_state = State.WINDUP
	# Lock target at the START of the windup so the player can dodge by moving.
	_locked_target_pos = target_pos
	if _movement:
		_movement.face_direction(_body.global_position.direction_to(target_pos))
		_movement.set_direction(Vector2.ZERO)
	if _animation:
		_animation.action_finished.connect(_on_shoot_finished, CONNECT_ONE_SHOT)
		_animation.play_action("shoot")
	return true


func interrupt() -> void:
	if _state == State.IDLE:
		return
	if _animation and _animation.action_finished.is_connected(_on_shoot_finished):
		_animation.action_finished.disconnect(_on_shoot_finished)
	_state = State.RECOVERY
	_recovery_timer = hit_stun_duration


func _on_shoot_finished() -> void:
	if _state != State.WINDUP:
		return
	_spawn_arrow()
	_state = State.RECOVERY
	_recovery_timer = recovery_duration


func _spawn_arrow() -> void:
	var arrow_scene := load(ARROW_SCENE_PATH) as PackedScene
	if arrow_scene == null:
		push_error("ZombieArcherShootComponent: arrow.tscn not found.")
		return
	var arrow := arrow_scene.instantiate() as Arrow
	if arrow == null:
		return
	var dir := _body.global_position.direction_to(_locked_target_pos)
	var spawn_pos := _body.global_position + dir * 8.0
	arrow.init(spawn_pos, _locked_target_pos, base_damage)
	_body.get_parent().add_child(arrow)

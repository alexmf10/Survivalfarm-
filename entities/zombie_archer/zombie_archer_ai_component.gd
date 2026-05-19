class_name ZombieArcherAIComponent
extends Node

const PLAYER_REFERENCE_SPEED: float = 60.0
const SPEED_MIN_RATIO: float = 0.25
const SPEED_MAX_RATIO: float = 0.45

enum State { WANDER, CHASE }

@export var detection_range: float = 130.0
@export var lose_range: float = 180.0
@export var attack_range: float = 85.0
@export var min_separation_distance: float = 18.0
@export var zombie_separation_radius: float = 18.0
@export var zombie_separation_strength: float = 1.2
@export var wander_interval: float = 2.5
@export var wander_pause_chance: float = 0.35

var _body: CharacterBody2D
var _movement: MovementComponent
var _shoot: Node
var _state: int = State.WANDER
var _wander_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("ZombieArcherAIComponent: parent is not CharacterBody2D.")
		set_process(false)
		return

	for child in _body.get_children():
		if child is MovementComponent:
			_movement = child
		if child.has_method("try_shoot"):
			_shoot = child

	if _movement == null:
		push_error("ZombieArcherAIComponent: MovementComponent not found.")
		set_process(false)
		return

	_movement.speed = PLAYER_REFERENCE_SPEED * randf_range(SPEED_MIN_RATIO, SPEED_MAX_RATIO)
	_pick_wander_direction()
	_wander_timer = randf_range(0.5, wander_interval)


func _process(delta: float) -> void:
	if _shoot and _shoot.is_busy():
		return

	var player_pos: Vector2 = _get_player_position()
	if player_pos == Vector2.INF:
		_process_wander(delta)
		return

	var dist: float = _body.global_position.distance_to(player_pos)
	_update_state(dist)

	match _state:
		State.WANDER:
			_process_wander(delta)
		State.CHASE:
			_process_chase(player_pos, dist)


func _update_state(dist: float) -> void:
	match _state:
		State.WANDER:
			if dist <= detection_range:
				_state = State.CHASE
		State.CHASE:
			if dist > lose_range:
				_state = State.WANDER
				_pick_wander_direction()


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(wander_interval * 0.5, wander_interval)
		_pick_wander_direction()
	if _movement:
		_move_with_separation(_wander_direction)


func _process_chase(player_pos: Vector2, dist: float) -> void:
	if dist <= attack_range:
		if _movement:
			_movement.face_direction(_body.global_position.direction_to(player_pos))
			_movement.set_direction(Vector2.ZERO)
		if _shoot:
			_shoot.try_shoot(player_pos)
		return
	var dir := _body.global_position.direction_to(player_pos)
	if _movement:
		_move_with_separation(dir)


func _pick_wander_direction() -> void:
	if randf() < wander_pause_chance:
		_wander_direction = Vector2.ZERO
	else:
		var dirs: Array = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		_wander_direction = dirs[randi() % dirs.size()]


func _get_player_position() -> Vector2:
	var player_svc := EventBus.services.player as PlayerService
	if player_svc and player_svc.has_player():
		var p := player_svc.get_active_player()
		if p is Node2D:
			return (p as Node2D).global_position
	return Vector2.INF


func _move_with_separation(desired_direction: Vector2) -> void:
	if _movement == null:
		return
	var direction := desired_direction.limit_length(1.0)
	var separation := _get_zombie_separation()
	if separation != Vector2.ZERO:
		direction = (direction + separation * zombie_separation_strength).limit_length(1.0)
	_movement.set_direction(direction)


func _get_zombie_separation() -> Vector2:
	if _body == null or not is_inside_tree():
		return Vector2.ZERO
	var separation := Vector2.ZERO
	var radius_sq := zombie_separation_radius * zombie_separation_radius
	for other in get_tree().get_nodes_in_group("zombies"):
		if other == _body or not (other is Node2D):
			continue
		var offset := _body.global_position - (other as Node2D).global_position
		var dist_sq := offset.length_squared()
		if dist_sq > radius_sq:
			continue
		if dist_sq < 0.001:
			separation += _stable_separation_direction()
		else:
			var dist := sqrt(dist_sq)
			separation += (offset / dist) * (1.0 - dist / zombie_separation_radius)
	return separation.limit_length(1.0)


func _stable_separation_direction() -> Vector2:
	var angle := float(_body.get_instance_id() % 360) * TAU / 360.0
	return Vector2.RIGHT.rotated(angle)

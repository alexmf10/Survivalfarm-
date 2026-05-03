## ZombieAIComponent — Inteligencia artificial básica del zombie.
##
## Tres estados:
##   WANDER → pasea aleatoriamente (sin jugador detectado)
##   CHASE  → persigue al jugador; si llega a rango y consigue slot del
##            EnemyCoordinatorService, dispara try_start_attack().
##   CIRCLE → en rango pero sin slot: orbita al jugador justo fuera del
##            attack_range, presionando sin atacar.
##
## --- Cooperación con ZombieAttackComponent ---
## Cuando _attack.is_busy() es true, la IA NO toca el MovementComponent —
## el AttackComponent controla movimiento durante WINDUP/STRIKE/RECOVERY.
## Esto evita que la IA y el ataque se peleen por la dirección.
##
## --- Velocidad ---
## En _ready() asigna velocidad aleatoria 30%-60% de la del player.
## El AttackComponent puede sobrescribir temporalmente la velocidad
## (lunge durante STRIKE) y la restaura al salir.
class_name ZombieAIComponent
extends Node

# ── Constantes ────────────────────────────────────────────────────────────────
const PLAYER_REFERENCE_SPEED: float = 60.0
const SPEED_MIN_RATIO: float = 0.30
const SPEED_MAX_RATIO: float = 0.60

enum State {WANDER, CHASE, CIRCLE}

# ── Configuración ─────────────────────────────────────────────────────────────
## Radio de detección del jugador (entra en CHASE).
@export var detection_range: float = 90.0

## Radio para perder al jugador (vuelve a WANDER). > detection_range = histéresis.
@export var lose_range: float = 140.0

## Distancia para iniciar try_start_attack().
## Importante: debe ser MAYOR que la distancia mínima entre centros cuando
## las collision shapes del zombi y del player se tocan (~15 px). Si no, el
## zombi nunca puede entrar en rango — se queda empujándote sin atacar.
@export var attack_range: float = 22.0

@export var min_separation_distance: float = 18.0

@export var zombie_separation_radius: float = 18.0
@export var zombie_separation_strength: float = 1.35

## Distancia de espera si no puede atacar todavia. Debe mantenerse dentro de
## attack_range para no quedar orbitando fuera del rango real de golpe.
@export var circle_radius: float = 20.0

## Tiempo maximo en CIRCLE antes de volver a CHASE y reevaluar la persecucion.
@export var circle_repath_interval: float = 0.9

## Intensidad lateral cuando espera turno para atacar. Menor que 1 para que no
## parezca que acelera alrededor del player.
@export var circle_strafe_weight: float = 0.35

## Segundos entre cambios de dirección al pasear.
@export var wander_interval: float = 2.5

## Probabilidad (0..1) de pararse al cambiar dirección en WANDER.
@export var wander_pause_chance: float = 0.35

# ── Estado interno ────────────────────────────────────────────────────────────
var _body: CharacterBody2D
var _movement: MovementComponent
var _attack: Node # ZombieAttackComponent
var _state: int = State.WANDER
var _wander_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.ZERO
var _circle_clockwise: bool = true
var _circle_timer: float = 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("ZombieAIComponent: el padre no es CharacterBody2D.")
		set_process(false)
		return

	for child in _body.get_children():
		if child is MovementComponent:
			_movement = child
		if child.has_method("try_start_attack"):
			_attack = child

	if _movement == null:
		push_error("ZombieAIComponent: no se encontró MovementComponent.")
		set_process(false)
		return

	# Velocidad aleatoria base
	_movement.speed = PLAYER_REFERENCE_SPEED * randf_range(SPEED_MIN_RATIO, SPEED_MAX_RATIO)

	# Sentido estable por instancia: evita que toda la horda orbite hacia el mismo lado.
	_circle_clockwise = int(_body.get_instance_id()) % 2 == 0
	_circle_timer = randf_range(0.0, circle_repath_interval)

	_pick_wander_direction()
	_wander_timer = randf_range(0.5, wander_interval)


func _process(delta: float) -> void:
	# Si el AttackComponent está procesando un ataque, NO movemos al zombi.
	# Él se encarga del lunge / parón / recuperación.
	if _attack and _attack.is_busy():
		return

	var player_pos: Vector2 = _get_player_position()
	var has_player: bool = (player_pos != Vector2.INF)

	if not has_player:
		_process_wander(delta)
		return

	var dist: float = _body.global_position.distance_to(player_pos)
	_update_state(dist)

	match _state:
		State.WANDER:
			_process_wander(delta)
		State.CHASE:
			_process_chase(player_pos, dist)
		State.CIRCLE:
			_process_circle(player_pos, dist)


# ── Transiciones de estado ───────────────────────────────────────────────────

func _update_state(dist: float) -> void:
	match _state:
		State.WANDER:
			if dist <= detection_range:
				_state = State.CHASE
		State.CHASE, State.CIRCLE:
			if dist > lose_range:
				_state = State.WANDER
				_pick_wander_direction()


# ── Procesos por estado ──────────────────────────────────────────────────────

func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(wander_interval * 0.5, wander_interval)
		_pick_wander_direction()
	if _movement:
		_move_with_separation(_wander_direction)


func _process_chase(player_pos: Vector2, dist: float) -> void:
	if dist < min_separation_distance:
		if _movement:
			_move_with_separation(_direction_away_from_player(player_pos))
		return

	# Si está en rango, intenta atacar. Si no consigue slot, pasa a CIRCLE.
	if dist <= attack_range:
		if _movement:
			_movement.face_direction(_body.global_position.direction_to(player_pos))
			_movement.set_direction(Vector2.ZERO)
		if _attack and _attack.try_start_attack(player_pos):
			return # AttackComponent toma el control desde aquí
		_state = State.CIRCLE
		_circle_timer = randf_range(circle_repath_interval * 0.5, circle_repath_interval)
		_process_circle(player_pos, dist)
		return
	# Aproximarse al jugador en línea recta.
	var dir: Vector2 = _body.global_position.direction_to(player_pos)
	if _movement:
		_move_with_separation(dir)


func _process_circle(player_pos: Vector2, dist: float) -> void:
	_circle_timer -= get_process_delta_time()
	if _circle_timer <= 0.0:
		_state = State.CHASE
		_circle_clockwise = not _circle_clockwise
		_process_chase(player_pos, dist)
		return

	if dist < min_separation_distance:
		if _movement:
			_move_with_separation(_direction_away_from_player(player_pos))
		return

	# Reintenta conseguir slot — si otro zombi acaba de terminar, este puede atacar.
	if dist <= attack_range and _attack and _attack.try_start_attack(player_pos):
		return

	# Si está demasiado lejos, vuelve a CHASE para acercarse.
	if dist > attack_range:
		_state = State.CHASE
		_process_chase(player_pos, dist)
		return

	# Mantener distancia ~ circle_radius:
	# • si está más lejos → acercarse
	# • si está más cerca → retroceder
	# • si está en el anillo → strafe perpendicular
	var to_player: Vector2 = (player_pos - _body.global_position).normalized()
	var tangent: Vector2 = Vector2(-to_player.y, to_player.x)
	if not _circle_clockwise:
		tangent = - tangent

	var radial: Vector2 = Vector2.ZERO
	if dist > circle_radius:
		radial = to_player
	elif dist < min_separation_distance:
		radial = -to_player

	var direction: Vector2 = radial + tangent * circle_strafe_weight

	if _movement:
		_move_with_separation(direction)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _pick_wander_direction() -> void:
	if randf() < wander_pause_chance:
		_wander_direction = Vector2.ZERO
	else:
		var dirs: Array = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		_wander_direction = dirs[randi() % dirs.size()]


func _get_player_position() -> Vector2:
	var player_svc: PlayerService = EventBus.services.player as PlayerService
	if player_svc and player_svc.has_player():
		var p: Node = player_svc.get_active_player()
		if p is Node2D:
			return (p as Node2D).global_position
	return Vector2.INF


func _direction_away_from_player(player_pos: Vector2) -> Vector2:
	var away: Vector2 = _body.global_position - player_pos
	if away.length_squared() < 0.001:
		return Vector2.DOWN
	return away.normalized()


func _move_with_separation(desired_direction: Vector2) -> void:
	if _movement == null:
		return

	var direction: Vector2 = desired_direction.limit_length(1.0)
	var separation: Vector2 = _get_zombie_separation()
	if separation != Vector2.ZERO:
		direction = (direction + separation * zombie_separation_strength).limit_length(1.0)

	_movement.set_direction(direction)


func _get_zombie_separation() -> Vector2:
	if _body == null or not is_inside_tree():
		return Vector2.ZERO

	var separation: Vector2 = Vector2.ZERO
	var radius_sq: float = zombie_separation_radius * zombie_separation_radius
	for other in get_tree().get_nodes_in_group("zombies"):
		if other == _body or not (other is Node2D):
			continue

		var other_body: Node2D = other as Node2D
		var offset: Vector2 = _body.global_position - other_body.global_position
		var dist_sq: float = offset.length_squared()
		if dist_sq > radius_sq:
			continue

		if dist_sq < 0.001:
			separation += _stable_separation_direction()
		else:
			var dist: float = sqrt(dist_sq)
			var weight: float = 1.0 - (dist / zombie_separation_radius)
			separation += (offset / dist) * weight

	return separation.limit_length(1.0)


func _stable_separation_direction() -> Vector2:
	var angle: float = float(_body.get_instance_id() % 360) * TAU / 360.0
	return Vector2.RIGHT.rotated(angle)

## MovementComponent — Componente de movimiento reutilizable.
##
## Responsabilidad única: leer la dirección de entrada y aplicar movimiento al
## CharacterBody2D padre. No decide qué animación reproducir (eso es del
## AnimationComponent). No dibuja nada.
##
## --- Arquitectura ---
## • Se cuelga como hijo de cualquier CharacterBody2D (Player, Enemy, NPC...).
## • Las señales son LOCALES — solo las escucha el AnimationComponent hermano
##   dentro de la misma entidad. Nunca se publican al EventBus porque son un
##   detalle interno del "cómo se mueve" y no le incumben al resto del juego.
##
## --- Reutilización ---
## • Para el jugador: input_enabled = true → lee WASD automáticamente.
## • Para un enemigo: input_enabled = false → la IA llamará set_direction(dir).
##
## --- Señales emitidas ---
## • moved(direction)          → cada frame físico con input != 0
## • stopped()                 → cuando el input pasa de != 0 a 0
## • facing_changed(direction) → cuando la dirección cardinal cambia
class_name MovementComponent
extends Node

# ── Configuración ───────────────────────────────────────────────────────────
## Velocidad en píxeles por segundo.
@export var speed: float = 60.0

## Multiplicador de velocidad al pulsar Shift (sprint).
@export var sprint_multiplier: float = 1.8

## Si true, lee input del teclado. Si false, se mueve solo cuando la entidad
## que lo posee llama a set_direction() (útil para IA de enemigos).
@export var input_enabled: bool = true

# ── Señales LOCALES ─────────────────────────────────────────────────────────
## Emitida cada frame físico con vector de entrada distinto de cero.
signal moved(direction: Vector2)

## Emitida cuando el input deja de ser != 0 (el cuerpo se ha detenido).
signal stopped()

## Emitida cuando la dirección "cardinal" cambia (up/down/left/right).
## El AnimationComponent la usa para elegir la variante correcta de la animación.
signal facing_changed(direction: Vector2)

# ── Estado interno ──────────────────────────────────────────────────────────
var _body: CharacterBody2D
var _current_direction: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.DOWN  # Dirección cardinal actual (para animaciones)
var _was_moving: bool = false

# ── Knockback ───────────────────────────────────────────────────────────────
## Tiempo en segundos que dura el knockback hasta decaer a 0.
const KNOCKBACK_DECAY: float = 0.18
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_timer: float = 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("MovementComponent: parent is not a CharacterBody2D.")
		set_physics_process(false)


# ── API pública ─────────────────────────────────────────────────────────────

## Fuerza la detención del movimiento (útil en pausas, diálogos, cutscenes).
func stop() -> void:
	_current_direction = Vector2.ZERO
	if _body:
		_body.velocity = Vector2.ZERO


## Fija la dirección desde fuera (usado por una IA en el futuro).
## Solo tiene efecto si input_enabled == false.
func set_direction(direction: Vector2) -> void:
	_current_direction = direction.limit_length(1.0)
	if _current_direction != Vector2.ZERO:
		_update_facing(_current_direction)


func face_direction(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		return
	_update_facing(direction.normalized())


## Dirección cardinal actual ("up"/"down"/"left"/"right" codificada como Vector2).
func get_facing() -> Vector2:
	return _facing


## Aplica un impulso de knockback. La velocidad decae linealmente en
## KNOCKBACK_DECAY segundos. Reemplaza cualquier knockback anterior.
## Útil para que ataques empujen al objetivo (player o enemigo).
func apply_knockback(impulse: Vector2) -> void:
	_knockback_velocity = impulse
	_knockback_timer = KNOCKBACK_DECAY


# ── Proceso físico ──────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _body == null:
		return

	# Knockback tiene prioridad sobre dirección normal mientras decae.
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		var t: float = clampf(_knockback_timer / KNOCKBACK_DECAY, 0.0, 1.0)
		_body.velocity = _knockback_velocity * t
		_body.move_and_slide()
		# Durante knockback no leemos input ni emitimos señales de "moved".
		# El AnimationComponent mantendrá la animación que tuviera.
		_was_moving = false
		return

	if input_enabled:
		_current_direction = Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)

	# Aplicar velocidad al cuerpo y resolver colisiones
	# Sprint: multiplicar la velocidad si Shift está pulsado (solo para input del jugador)
	var current_speed: float = speed
	if input_enabled and Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed *= sprint_multiplier
	var previous_position: Vector2 = _body.global_position
	_body.velocity = _current_direction * current_speed
	_body.move_and_slide()

	# Emitir señales locales según el estado
	var wants_to_move: bool = _current_direction != Vector2.ZERO
	var actually_moved: bool = _body.global_position.distance_squared_to(previous_position) > 0.001
	var is_moving: bool = wants_to_move and actually_moved

	if wants_to_move:
		_update_facing(_current_direction)

	if is_moving:
		moved.emit(_current_direction)
	elif _was_moving:
		stopped.emit()

	_was_moving = is_moving


# ── Lógica interna ──────────────────────────────────────────────────────────

## Determina la dirección cardinal dominante y emite facing_changed si cambió.
func _update_facing(direction: Vector2) -> void:
	var new_facing: Vector2
	if absf(direction.x) > absf(direction.y):
		new_facing = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		new_facing = Vector2.DOWN if direction.y > 0 else Vector2.UP

	if new_facing != _facing:
		_facing = new_facing
		facing_changed.emit(_facing)

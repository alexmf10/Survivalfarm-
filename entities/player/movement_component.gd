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


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		push_error("MovementComponent: el padre no es un CharacterBody2D.")
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


## Dirección cardinal actual ("up"/"down"/"left"/"right" codificada como Vector2).
func get_facing() -> Vector2:
	return _facing


# ── Proceso físico ──────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	if _body == null:
		return

	if input_enabled:
		_current_direction = Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)

	# Aplicar velocidad al cuerpo y resolver colisiones
	_body.velocity = _current_direction * speed
	_body.move_and_slide()

	# Emitir señales locales según el estado
	var is_moving: bool = _current_direction != Vector2.ZERO

	if is_moving:
		_update_facing(_current_direction)
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

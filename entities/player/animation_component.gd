## AnimationComponent — Componente de animación reutilizable.
##
## Responsabilidad única: elegir y reproducir la animación correcta del
## AnimatedSprite2D del padre, según el estado del MovementComponent hermano.
## Puro consumidor: no emite señales de estado, solo escucha y reproduce.
##
## --- Arquitectura ---
## • Se cuelga como hijo de cualquier entidad que tenga AnimatedSprite2D
##   y un MovementComponent hermanos.
## • Se conecta a las señales LOCALES de MovementComponent: moved, stopped,
##   facing_changed. No toca el EventBus — toda la comunicación es dentro de
##   la misma entidad.
## • Soporta "acciones one-shot" (tilling, watering, chopping) que bloquean
##   el movimiento mientras se reproducen y avisan al finalizar.
##
## --- Convención de animaciones esperadas ---
## Las animaciones del SpriteFrames deben llamarse:
##   {idle_prefix}_{cardinal}  → ej. "idle_down"
##   {walk_prefix}_{cardinal}  → ej. "run_up"
##   {action}_{cardinal}       → ej. "tilling_down", "watering_left"
## donde cardinal ∈ {down, up, left, right}.
class_name AnimationComponent
extends Node

# ── Configuración ───────────────────────────────────────────────────────────
## Ruta al AnimatedSprite2D hermano de la entidad.
@export var sprite_path: NodePath = NodePath("../AnimatedSprite2D")

## Ruta al MovementComponent hermano.
@export var movement_path: NodePath = NodePath("../MovementComponent")

## Prefijo de las animaciones idle (parada). "idle_front", "idle_back"...
@export var idle_prefix: String = "idle"

## Prefijo de las animaciones de movimiento. "walk_down", "walk_up"...
@export var walk_prefix: String = "walk"

## Dirección inicial al entrar a la escena.
@export var initial_facing: String = "down"

# ── Señales LOCALES ─────────────────────────────────────────────────────────
## Emitida cuando una animación de acción one-shot finaliza.
signal action_finished()

# ── Estado interno ──────────────────────────────────────────────────────────
var _sprite: AnimatedSprite2D
var _movement: MovementComponent
var _current_facing: String = "down"
var _is_moving: bool = false
var _is_action_playing: bool = false  ## Bloquea movimiento y animaciones normales


func _ready() -> void:
	_current_facing = initial_facing
	_sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	_movement = get_node_or_null(movement_path) as MovementComponent

	if _sprite == null:
		push_error("AnimationComponent: no se encontró AnimatedSprite2D en '%s'." % sprite_path)
		return
	if _movement == null:
		push_error("AnimationComponent: no se encontró MovementComponent en '%s'." % movement_path)
		return

	# Conectar señales LOCALES del hermano MovementComponent
	_movement.moved.connect(_on_moved)
	_movement.stopped.connect(_on_stopped)
	_movement.facing_changed.connect(_on_facing_changed)

	# Conectar animation_finished para detectar fin de acciones one-shot
	_sprite.animation_finished.connect(_on_animation_finished)

	# Arrancar con el idle correspondiente a la dirección inicial
	_play_animation(idle_prefix, _current_facing)


func _exit_tree() -> void:
	if _movement:
		if _movement.moved.is_connected(_on_moved):
			_movement.moved.disconnect(_on_moved)
		if _movement.stopped.is_connected(_on_stopped):
			_movement.stopped.disconnect(_on_stopped)
		if _movement.facing_changed.is_connected(_on_facing_changed):
			_movement.facing_changed.disconnect(_on_facing_changed)
	if _sprite and _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.disconnect(_on_animation_finished)


# ── API pública ─────────────────────────────────────────────────────────────

## Reproduce una animación de acción one-shot (ej: "tilling", "watering", "chopping").
## Bloquea el movimiento del personaje hasta que la animación termine.
## La animación se construye como "{action_prefix}_{facing}".
func play_action(action_prefix: String) -> void:
	if _sprite == null:
		return

	_is_action_playing = true

	# Bloquear el movimiento durante la acción
	if _movement:
		_movement.stop()

	_play_animation(action_prefix, _current_facing)


## Devuelve true si hay una animación de acción reproduciéndose.
func is_action_playing() -> bool:
	return _is_action_playing


## Devuelve la dirección cardinal actual como string.
func get_current_facing() -> String:
	return _current_facing


# ── Handlers de las señales locales ─────────────────────────────────────────

func _on_moved(_direction: Vector2) -> void:
	if _is_action_playing:
		return  # No interrumpir acciones
	if not _is_moving:
		_is_moving = true
		_play_animation(walk_prefix, _current_facing)


func _on_stopped() -> void:
	if _is_action_playing:
		return  # No interrumpir acciones
	_is_moving = false
	_play_animation(idle_prefix, _current_facing)


func _on_facing_changed(direction: Vector2) -> void:
	_current_facing = _vector_to_cardinal(direction)
	if _is_action_playing:
		return  # No interrumpir acciones
	var prefix: String = walk_prefix if _is_moving else idle_prefix
	_play_animation(prefix, _current_facing)


func _on_animation_finished() -> void:
	if _is_action_playing:
		_is_action_playing = false
		action_finished.emit()
		# Volver a idle tras la acción
		_is_moving = false
		_play_animation(idle_prefix, _current_facing)


# ── Helpers ─────────────────────────────────────────────────────────────────

func _play_animation(prefix: String, cardinal: String) -> void:
	if _sprite == null:
		return
	var anim_name: String = "%s_%s" % [prefix, cardinal]
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim_name):
		_sprite.play(anim_name)


func _vector_to_cardinal(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0 else "left"
	return "down" if direction.y > 0 else "up"

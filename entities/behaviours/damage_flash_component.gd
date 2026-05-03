## DamageFlashComponent — Efecto visual de flash rojo al recibir daño.
##
## Se añade como hijo de CUALQUIER entidad (Player, Zombie, etc.) que tenga
## un AnimatedSprite2D y un HealthComponent como hermanos.
## Cuando la entidad recibe daño, el sprite parpadea en rojo durante un breve
## instante usando la propiedad `modulate` del AnimatedSprite2D.
## No modifica HP, no dibuja, no emite señales. Solo efecto visual.
##
## --- Arquitectura ---
## • Se conecta a la señal LOCAL health_changed del HealthComponent hermano.
## • Usa Tween para animar el parpadeo sin bloquear el proceso principal.
## • Totalmente reutilizable: idéntico en Player y Zombie.
class_name DamageFlashComponent
extends Node

# ── Configuración ────────────────────────────────────────────────────────────
## Color del flash de daño (rojo intenso semitransparente sobre el sprite).
@export var flash_color: Color = Color(1.0, 0.15, 0.15, 1.0)

## Duración total del efecto en segundos.
@export var flash_duration: float = 0.35

## Número de parpadeos durante el efecto.
@export var flash_count: int = 3

# ── Estado interno ───────────────────────────────────────────────────────────
var _sprite: AnimatedSprite2D = null
var _health: HealthComponent = null
var _tween: Tween = null
var _original_modulate: Color = Color.WHITE
var _last_hp: float = -1.0


func _ready() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	# Buscar AnimatedSprite2D y HealthComponent como hermanos (hijos del mismo padre)
	for child in parent.get_children():
		if child is AnimatedSprite2D and _sprite == null:
			_sprite = child
		if child is HealthComponent and _health == null:
			_health = child

	if _sprite == null:
		push_warning("DamageFlashComponent: no se encontró AnimatedSprite2D en '%s'" % parent.name)
		return
	if _health == null:
		push_warning("DamageFlashComponent: no se encontró HealthComponent en '%s'" % parent.name)
		return

	_original_modulate = _sprite.modulate
	_last_hp = _health.current_health
	_health.health_changed.connect(_on_health_changed)


func _exit_tree() -> void:
	if _health and _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	if _tween and _tween.is_running():
		_tween.kill()
	# Restaurar modulate original si el sprite sigue siendo válido
	if is_instance_valid(_sprite):
		_sprite.modulate = _original_modulate


# ── Handler ──────────────────────────────────────────────────────────────────

func _on_health_changed(current_hp: float, _max_hp: float) -> void:
	# Solo disparar flash si se recibió daño (HP bajó)
	if current_hp < _last_hp:
		_trigger_flash()
	_last_hp = current_hp


# ── Lógica del flash ─────────────────────────────────────────────────────────

func _trigger_flash() -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		return

	# Cancelar cualquier flash en curso
	if _tween and _tween.is_running():
		_tween.kill()

	# Restaurar antes de empezar para tener una base limpia
	_sprite.modulate = _original_modulate

	_tween = create_tween()
	var interval: float = flash_duration / (flash_count * 2)

	for i in range(flash_count):
		_tween.tween_property(_sprite, "modulate", flash_color, interval)
		_tween.tween_property(_sprite, "modulate", _original_modulate, interval)

	# Garantizar restauración final aunque haya algún error de timing
	_tween.tween_property(_sprite, "modulate", _original_modulate, 0.01)

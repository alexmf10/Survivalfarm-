## HealthComponent — Caja fuerte de vida reutilizable para CUALQUIER actor.
##
## Guarda max_health y current_health. Expone take_damage(amount) y heal(amount).
## Cuando llega a 0, emite la señal local died().
##
## --- Arquitectura ---
## • Es un componente PURO de datos/lógica: no dibuja nada ni detecta golpes.
## • Emite señales LOCALES (health_changed, died) para que sus hermanos
##   (HealthBarComponent, AnimationComponent) reaccionen directamente.
## • También publica señales GLOBALES al EventBus (hp_changed, entity_died)
##   para que la UI y otros sistemas remotos puedan reaccionar.
##
## --- Healing (curación) ---
## La curación se dispara de dos formas:
##   1. heal(amount) — método público, puede ser llamado por items, pociones, etc.
##   2. Regeneración pasiva — si passive_regen_enabled es true, el componente
##      regenera passive_regen_amount HP cada passive_regen_interval segundos,
##      siempre que la vida no esté al 100%.
##
## --- Límites ---
## NO detecta golpes físicos. Solo resta/suma HP cuando ALGUIEN se lo pide.
## NO dibuja barras de vida. Eso es trabajo del HealthBarComponent o de la UI.
class_name HealthComponent
extends Node

# ── Señales locales ──────────────────────────────────────────────────────────
## Emitida cada vez que current_health cambia.
## Los hermanos (HealthBarComponent) la escuchan directamente.
signal health_changed(current_hp: float, max_hp: float)

## Emitida cuando current_health llega a 0 (solo una vez).
signal died()

# ── Configuración exportada ──────────────────────────────────────────────────
## Vida máxima del actor.
@export var max_health: float = 100.0

## Si es true, el componente regenera vida pasivamente.
@export var passive_regen_enabled: bool = false

## Cantidad de HP que se regenera cada intervalo.
@export var passive_regen_amount: float = 1.0

## Segundos entre cada tick de regeneración pasiva.
@export var passive_regen_interval: float = 3.0

# ── Estado interno ───────────────────────────────────────────────────────────
var current_health: float = 0.0
var _is_dead: bool = false
var _regen_timer: float = 0.0


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	if _is_dead or not passive_regen_enabled:
		return
	if current_health >= max_health:
		_regen_timer = 0.0
		return

	_regen_timer += delta
	if _regen_timer >= passive_regen_interval:
		_regen_timer -= passive_regen_interval
		heal(passive_regen_amount)


# ── API pública ──────────────────────────────────────────────────────────────

## Aplica daño al actor. El amount ya debe venir validado (daño neto).
func take_damage(amount: float) -> void:
	if _is_dead:
		return
	current_health = maxf(current_health - amount, 0.0)
	_emit_change()
	if current_health <= 0.0:
		_is_dead = true
		died.emit()
		EventBus.entity_died.emit(get_parent())


## Cura al actor. Nunca sobrepasa max_health.
func heal(amount: float) -> void:
	if _is_dead:
		return
	var old_hp: float = current_health
	current_health = minf(current_health + amount, max_health)
	if current_health != old_hp:
		_emit_change()


## Devuelve la vida como fracción 0..1.
func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health


## Devuelve true si la vida está al máximo.
func is_full() -> bool:
	return current_health >= max_health


## Reinicia la vida al máximo (para respawn, etc.)
func reset() -> void:
	_is_dead = false
	current_health = max_health
	_emit_change()


# ── Internos ─────────────────────────────────────────────────────────────────

func _emit_change() -> void:
	health_changed.emit(current_health, max_health)
	# Señal global para la UI (solo si el dueño es el player)
	if get_parent() is Player:
		EventBus.player_hp_changed.emit(current_health, max_health)

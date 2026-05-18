## HealthBarComponent — Barra de vida dibujada sobre el sprite del actor.
##
## Se coloca como NODO HIJO del actor (Player, Slime, etc.).
## Dibuja un rectángulo pequeño encima del sprite con el porcentaje de vida.
##
## --- Arquitectura ---
## • Busca al hermano HealthComponent automáticamente y se conecta a su
##   señal health_changed.
## • Se OCULTA automáticamente cuando la vida está al 100%.
## • No modifica HP — es solo lectura visual.
## • Usa _draw() de Godot para pintar la barra por código, sin assets.
##
## --- Reglas de visibilidad ---
## • La barra permanece visible durante X segundos tras recibir daño o una cura fuerte.
## • Se oculta automáticamente al pasar ese tiempo (para no ensuciar la pantalla).
## • La regeneración pasiva (1 HP) actualiza la barra pero NO reinicia el temporizador.
## • Vida = 100 % o Vida = 0 %  →  barra se oculta inmediatamente.
class_name HealthBarComponent
extends Node2D

# ── Configuración ────────────────────────────────────────────────────────────
## Ancho de la barra en píxeles.
@export var bar_width: float = 14.0

## Alto de la barra en píxeles.
@export var bar_height: float = 2.0

## Desplazamiento Y respecto al origen del padre (negativo = arriba).
@export var bar_offset_y: float = -12.0

## Color de fondo (vida perdida).
@export var bg_color: Color = Color(0.15, 0.15, 0.15, 0.85)

## Color del borde fino.
@export var border_color: Color = Color(0.05, 0.05, 0.05, 0.9)

## Color de la vida alta (verde).
@export var color_high: Color = Color(0.18, 0.80, 0.25)

## Color de la vida media (amarillo).
@export var color_mid: Color = Color(0.90, 0.78, 0.15)

## Color de la vida baja (rojo).
@export var color_low: Color = Color(0.85, 0.18, 0.18)

## Umbral bajo (porcentaje 0..1).
@export var threshold_low: float = 0.3

## Umbral medio (porcentaje 0..1).
@export var threshold_mid: float = 0.6

## Tiempo en segundos tras el cual la barra se oculta si no hay cambios.
@export var hide_after_seconds: float = 5.0

## Si true, la barra permanece visible mientras la entidad siga viva.
@export var always_visible: bool = false

# ── Estado interno ───────────────────────────────────────────────────────────
var _health_ratio: float = 1.0
var _health_component: HealthComponent = null
var _show_timer: float = 0.0
var _last_hp: float = -1.0


func _ready() -> void:
	# Buscar el HealthComponent hermano en el padre
	var parent_node: Node = get_parent()
	if parent_node:
		for child in parent_node.get_children():
			if child is HealthComponent:
				_health_component = child
				break

	if _health_component:
		_health_component.health_changed.connect(_on_health_changed)
		_last_hp = _health_component.current_health
		_health_ratio = _health_component.get_health_ratio()
	else:
		push_warning("HealthBarComponent: HealthComponent not found in parent '%s'" % get_parent().name)

	# Posicionar la barra arriba del sprite
	position = Vector2(0, bar_offset_y)

	# Empezar oculta salvo en enemigos especiales como bosses.
	visible = always_visible
	call_deferred("_refresh_initial_ratio")


func _process(delta: float) -> void:
	if visible and not always_visible:
		_show_timer -= delta
		if _show_timer <= 0.0:
			visible = false


func _on_health_changed(current_hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		_health_ratio = 0.0
	else:
		_health_ratio = current_hp / max_hp

	# Mostrar barra y reiniciar timer si recibió daño o una cura mayor a 1 HP (ignorar regen pasiva)
	var hp_diff: float = current_hp - _last_hp
	if hp_diff < 0.0 or hp_diff > 1.0:
		_show_timer = hide_after_seconds
		visible = true

	# Ocultar inmediatamente si está al 100% o muerto
	if _health_ratio <= 0.0:
		visible = false
	elif always_visible:
		visible = true
	elif _health_ratio >= 1.0:
		visible = false

	_last_hp = current_hp
	queue_redraw()


func _refresh_initial_ratio() -> void:
	if _health_component == null:
		return
	_last_hp = _health_component.current_health
	_health_ratio = _health_component.get_health_ratio()
	visible = always_visible and _health_ratio > 0.0
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	# Calcular posiciones centradas
	var half_w: float = bar_width * 0.5
	var rect_bg: Rect2 = Rect2(-half_w - 1, -1, bar_width + 2, bar_height + 2)
	var rect_fill: Rect2 = Rect2(-half_w, 0, bar_width * _health_ratio, bar_height)

	# Borde
	draw_rect(rect_bg, border_color)

	# Fondo
	var bg_rect: Rect2 = Rect2(-half_w, 0, bar_width, bar_height)
	draw_rect(bg_rect, bg_color)

	# Relleno con color según porcentaje
	var fill_color: Color = _get_fill_color()
	draw_rect(rect_fill, fill_color)


func _get_fill_color() -> Color:
	if _health_ratio <= threshold_low:
		return color_low
	elif _health_ratio <= threshold_mid:
		return color_mid
	else:
		return color_high

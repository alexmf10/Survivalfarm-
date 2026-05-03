## HealthHUD — Barra de vida detallada del jugador en la interfaz gráfica.
##
## CanvasLayer que muestra una barra de salud estilo RPG en la esquina
## superior izquierda de la pantalla. Incluye:
## - Icono de corazón pixel-art dibujado por código.
## - Barra de vida con relleno gradual y colores por umbral.
## - Texto numérico "HP / MaxHP".
## - Animación suave de transición cuando cambia la vida.
##
## --- Arquitectura ---
## - Escucha: EventBus.player_hp_changed → actualiza la barra y el texto.
## - No emite señales (solo lectura).
## - Se construye por código, sin assets ni sprites externos.
class_name HealthHUD
extends CanvasLayer

# ── Paleta de colores estilo medieval/pixel ──────────────────────────────────
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT: Color = Color(0.35, 0.25, 0.15)

const COLOR_HP_HIGH: Color = Color(0.18, 0.80, 0.25)
const COLOR_HP_MID: Color = Color(0.90, 0.78, 0.15)
const COLOR_HP_LOW: Color = Color(0.85, 0.18, 0.18)
const COLOR_HP_BG: Color = Color(0.48, 0.42, 0.32)

const COLOR_HEART: Color = Color(0.85, 0.18, 0.25)
const COLOR_HEART_BG: Color = Color(0.60, 0.20, 0.22, 0.4)

const THRESHOLD_LOW: float = 0.3
const THRESHOLD_MID: float = 0.6

# ── Nodos internos ───────────────────────────────────────────────────────────
var _font: Font
var _hp_label: Label
var _hp_bar: ProgressBar
var _heart_icon: Control
var _bar_fill_style: StyleBoxFlat
var _tween: Tween

var _current_hp: float = 100.0
var _max_hp: float = 100.0


func _ready() -> void:
	layer = 10
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()
	_connect_signals()
	# Empezar oculta — se mostrará cuando el HealthComponent emita
	_update_display(_current_hp, _max_hp, false)


func _exit_tree() -> void:
	_disconnect_signals()


# ── Construcción de la UI ────────────────────────────────────────────────────

func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Panel contenedor
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 8
	panel.offset_top = 8
	panel.offset_right = 8
	panel.offset_bottom = 8

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_color = COLOR_BORDER
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.set_corner_radius_all(0)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	# Layout horizontal: corazón + barra vertical
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	# Icono de corazón (dibujado por código)
	_heart_icon = HeartIcon.new()
	_heart_icon.custom_minimum_size = Vector2(10, 10)
	_heart_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_heart_icon)

	# Columna vertical: texto HP + barra
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	# Label "HP: 100/100"
	_hp_label = Label.new()
	_hp_label.text = "HP: 100/100"
	if _font:
		_hp_label.add_theme_font_override("font", _font)
	_hp_label.add_theme_font_size_override("font_size", 6)
	_hp_label.add_theme_color_override("font_color", COLOR_TEXT)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_hp_label)

	# Barra de vida
	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 1.0
	_hp_bar.value = 1.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(80, 6)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = COLOR_HP_BG
	bar_bg.set_corner_radius_all(0)
	_hp_bar.add_theme_stylebox_override("background", bar_bg)

	_bar_fill_style = StyleBoxFlat.new()
	_bar_fill_style.bg_color = COLOR_HP_HIGH
	_bar_fill_style.set_corner_radius_all(0)
	_hp_bar.add_theme_stylebox_override("fill", _bar_fill_style)

	vbox.add_child(_hp_bar)


# ── Conexión de señales ──────────────────────────────────────────────────────

func _connect_signals() -> void:
	EventBus.player_hp_changed.connect(_on_player_hp_changed)


func _disconnect_signals() -> void:
	if EventBus.player_hp_changed.is_connected(_on_player_hp_changed):
		EventBus.player_hp_changed.disconnect(_on_player_hp_changed)


# ── Handlers ─────────────────────────────────────────────────────────────────

func _on_player_hp_changed(current_hp: float, max_hp: float) -> void:
	_update_display(current_hp, max_hp, true)


func _update_display(current_hp: float, max_hp: float, animate: bool) -> void:
	_current_hp = current_hp
	_max_hp = max_hp

	# Actualizar texto
	_hp_label.text = "HP: %d/%d" % [int(current_hp), int(max_hp)]

	# Calcular ratio
	var ratio: float = 0.0
	if max_hp > 0.0:
		ratio = current_hp / max_hp

	# Color según porcentaje
	var fill_color: Color
	if ratio <= THRESHOLD_LOW:
		fill_color = COLOR_HP_LOW
	elif ratio <= THRESHOLD_MID:
		fill_color = COLOR_HP_MID
	else:
		fill_color = COLOR_HP_HIGH

	_bar_fill_style.bg_color = fill_color

	# Animar o setear directo
	if animate:
		if _tween and _tween.is_running():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_hp_bar, "value", ratio, 0.4) \
			.set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
	else:
		_hp_bar.value = ratio


# ── Subclase interna: Icono corazón dibujado por código ──────────────────────

class HeartIcon extends Control:
	## Icono pixel-art de un corazón usando draw_rect (cuadraditos de 2x2).
	## Patrón de corazón 5x5 píxeles escalado x2.
	const HEART_COLOR: Color = Color(0.85, 0.18, 0.25)
	const PX: float = 2.0 # Tamaño de cada "pixel" del corazón

	# Mapa del corazón 5x5 (1 = relleno, 0 = vacío)
	const HEART_MAP: Array = [
		[0, 1, 0, 1, 0],
		[1, 1, 1, 1, 1],
		[1, 1, 1, 1, 1],
		[0, 1, 1, 1, 0],
		[0, 0, 1, 0, 0],
	]

	func _draw() -> void:
		for y in range(HEART_MAP.size()):
			for x in range(HEART_MAP[y].size()):
				if HEART_MAP[y][x] == 1:
					draw_rect(Rect2(x * PX, y * PX, PX, PX), HEART_COLOR)

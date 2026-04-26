## HUD del ciclo día/noche. Capa visual que muestra el estado del tiempo al jugador.
## Se instancia como CanvasLayer para flotar sobre el mundo del juego.
##
## Arquitectura
## - Escucha señales del EventBus:
##     - EventBus.time_tick         -> actualiza labels de tiempo y barra de progreso
##     - EventBus.day_phase_changed -> anima el tinte de pantalla (día↔noche)
##     - EventBus.day_started       -> actualiza el label del contador de días
## - No emite señales (solo lectura).
## - Se conecta al EventBus en _ready() y se desconecta en _exit_tree().
##
## Elementos visuales
## - Label "Day X"          -> esquina superior derecha
## - Label "☀ DAY / ☽ NIGHT" -> debajo del contador
## - Label "MM:SS"          -> tiempo restante de la fase
## - ProgressBar            -> barra de progreso de la fase
## - ColorRect (tinte)      -> cubre toda la pantalla, se oscurece de noche
class_name DayCycleHUD
extends CanvasLayer

const COLOR_PARCHMENT:  Color = Color(0.82, 0.76, 0.63)
const COLOR_BORDER:     Color = Color(0.38, 0.28, 0.20)
const COLOR_TEXT:       Color = Color(0.35, 0.25, 0.15)
const COLOR_TEXT_DAY:   Color = Color(0.55, 0.38, 0.08)
const COLOR_TEXT_NIGHT: Color = Color(0.35, 0.40, 0.68)
const COLOR_BAR_DAY:    Color = Color(0.85, 0.65, 0.10)
const COLOR_BAR_NIGHT:  Color = Color(0.30, 0.35, 0.70)

const TINT_DAY:   Color = Color(0, 0, 0, 0)
const TINT_NIGHT: Color = Color(0.05, 0.05, 0.2, 0.45)
const TINT_TRANSITION_DURATION: float = 2.0

var _font: Font
var _day_label: Label
var _phase_label: Label
var _time_label: Label
var _progress_bar: ProgressBar
var _tint_rect: ColorRect
var _tint_tween: Tween


func _ready() -> void:
	layer = 10
	_font = load("res://ui/theme/PressStart2P-Regular.ttf") as Font
	_build_ui()
	_connect_signals()


func _exit_tree() -> void:
	_disconnect_signals()


#  Construcción de la UI

func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_tint_rect = ColorRect.new()
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.color = TINT_DAY
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tint_rect)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left   = -120
	panel.offset_right  =  -8
	panel.offset_top    =   8
	panel.offset_bottom =   8

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color       = COLOR_PARCHMENT
	style.border_color   = COLOR_BORDER
	style.border_width_top    = 2
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_bottom = 4
	style.set_corner_radius_all(0)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	_day_label = _make_label("DAY 1", 7, COLOR_TEXT)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_day_label)

	_phase_label = _make_label("DAY", 6, COLOR_TEXT_DAY)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_label)

	_time_label = _make_label("00:10", 6, COLOR_TEXT)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_time_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 5)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.48, 0.42, 0.32)
	bar_bg.set_corner_radius_all(0)
	_progress_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_BAR_DAY
	bar_fill.set_corner_radius_all(0)
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)

	vbox.add_child(_progress_bar)


func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


#  Conexión / desconexión de señales del EventBus 

func _connect_signals() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.day_started.connect(_on_day_started)


func _disconnect_signals() -> void:
	if EventBus.time_tick.is_connected(_on_time_tick):
		EventBus.time_tick.disconnect(_on_time_tick)
	if EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.disconnect(_on_day_phase_changed)
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


#  Handlers de señales

## Llamado cada ~1 segundo por DayCycleService vía EventBus.time_tick.
## Actualiza la barra de progreso y el reloj MM:SS del tiempo restante.
func _on_time_tick(day_number: int, elapsed_secs: float, phase: String) -> void:
	# Obtener PHASE_DURATION del servicio. Fallback a 300 si no está disponible.
	var phase_duration: float = 300.0
	var svc = EventBus.services.day_cycle
	if svc:
		phase_duration = svc.PHASE_DURATION

	# Actualizar barra de progreso
	var progress: float = clampf(elapsed_secs / phase_duration, 0.0, 1.0)
	_progress_bar.value = progress

	# Calcular y mostrar tiempo restante
	var remaining: float = maxf(phase_duration - elapsed_secs, 0.0)
	var minutes: int = int(remaining) / 60
	var seconds: int = int(remaining) % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]

	# Actualizar el color de la barra según la fase
	var fill_style: StyleBoxFlat = _progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = COLOR_BAR_NIGHT if phase == "NIGHT" else COLOR_BAR_DAY


## Llamado cuando la fase cambia (día <-> noche) vía EventBus.day_phase_changed.
## Anima el ColorRect de tinte con un Tween suave.
func _on_day_phase_changed(night: bool) -> void:
	if night:
		_phase_label.text = "** NIGHT **"
		_phase_label.add_theme_color_override("font_color", COLOR_TEXT_NIGHT)
	else:
		_phase_label.text = "* DAY *"
		_phase_label.add_theme_color_override("font_color", COLOR_TEXT_DAY)

	# Animar tinte de pantalla
	if _tint_tween and _tint_tween.is_running():
		_tint_tween.kill()

	var target_color: Color = TINT_NIGHT if night else TINT_DAY
	_tint_tween = create_tween()
	_tint_tween.tween_property(_tint_rect, "color", target_color, TINT_TRANSITION_DURATION)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)


## Llamado al inicio de cada nuevo día vía EventBus.day_started.
## Actualiza el label del contador de días.
func _on_day_started(day_number: int) -> void:
	_day_label.text = "DAY %d" % day_number

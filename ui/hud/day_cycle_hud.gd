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

# Nodos de la UI (creados por código en _build_ui)
var _day_label: Label
var _phase_label: Label
var _time_label: Label
var _progress_bar: ProgressBar
var _tint_rect: ColorRect

#  Colores del tinte 
## Color del tinte durante el día (totalmente transparente).
const TINT_DAY: Color = Color(0, 0, 0, 0)

## Color del tinte durante la noche (azul oscuro semitransparente).
const TINT_NIGHT: Color = Color(0.05, 0.05, 0.2, 0.45)

## Duración de la transición de tinte en segundos.
const TINT_TRANSITION_DURATION: float = 2.0

#  Referencia al tween activo 
var _tint_tween: Tween


func _ready() -> void:
	# Capa 10 para que esté por encima de la mayoría (se supone) de elementos del juego
	layer = 10
	_build_ui()
	_connect_signals()


func _exit_tree() -> void:
	_disconnect_signals()


#  Construcción de la UI

func _build_ui() -> void:
	# Contenedor raíz (Control que cubre toda la pantalla)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Tinte de pantalla (ColorRect que cubre todo el viewport)
	_tint_rect = ColorRect.new()
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.color = TINT_DAY
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tint_rect)

	# Panel informativo (esquina superior izquierda)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(8, 8)
	panel.size = Vector2(116, 0)

	# Estilo del panel: fondo semitransparente oscuro
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.75)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# Label del día
	_day_label = Label.new()
	_day_label.text = "Day 1"
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.add_theme_font_size_override("font_size", 9)
	_day_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	vbox.add_child(_day_label)

	# Label de la fase (☀ DAY / ☽ NIGHT)
	_phase_label = Label.new()
	_phase_label.text = "☀ DAY"
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 7)
	_phase_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(_phase_label)

	# Label del tiempo restante (MM:SS)
	_time_label = Label.new()
	_time_label.text = "05:00"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 7)
	_time_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(_time_label)

	# Barra de progreso de la fase
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 6)

	# Estilos de la barra
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.12, 0.1)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.9, 0.75, 0.3)
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)

	vbox.add_child(_progress_bar)


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
		if phase == "NIGHT":
			fill_style.bg_color = Color(0.3, 0.35, 0.7)   # azul noche
		else:
			fill_style.bg_color = Color(0.9, 0.75, 0.3)    # dorado día


## Llamado cuando la fase cambia (día <-> noche) vía EventBus.day_phase_changed.
## Anima el ColorRect de tinte con un Tween suave.
func _on_day_phase_changed(night: bool) -> void:
	# Actualizar label de fase
	if night:
		_phase_label.text = "☽ NIGHT"
		_phase_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.9))
	else:
		_phase_label.text = "☀ DAY"
		_phase_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))

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
	_day_label.text = "Day %d" % day_number

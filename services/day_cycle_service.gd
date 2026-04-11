## Servicio del ciclo día/noche. Controla el reloj de fases (día y noche de 5 min cada una)
## y el contador de días. Es un Node (no RefCounted) porque necesita _process().
class_name DayCycleService
extends Node

## Constantes
## Duración de cada fase en segundos (5 minutos = 300 s).
## Para pruebas rápidas se puede reducir a 10.0 o 30.0.
const PHASE_DURATION: float = 10.0

## Estado del ciclo
## Día actual de la partida (empieza en 1).
var current_day: int = 1

## true = noche, false = día.
var is_night: bool = false

## Segundos transcurridos dentro de la fase actual (0 -> PHASE_DURATION).
var elapsed: float = 0.0

## Si el reloj está corriendo
var running: bool = false

## Acumulador para emitir time_tick cada segundo (no cada frame).
var _tick_acc: float = 0.0



## Arranca el ciclo desde el día indicado. Llamado tras cargar una partida.
func start_cycle(day: int = 1) -> void:
	current_day = day
	is_night = false
	elapsed = 0.0
	_tick_acc = 0.0
	running = true
	## Emitir estado inicial para que la HUD se sincronice
	EventBus.day_started.emit(current_day)
	EventBus.day_phase_changed.emit(is_night)
	EventBus.time_tick.emit(current_day, elapsed, get_phase_name())


## Pausa el reloj
func pause() -> void:
	running = false


## Reanuda el reloj.
func resume() -> void:
	running = true


## Progreso de la fase actual como valor 0.0 -> 1.0.
func get_progress() -> float:
	if PHASE_DURATION <= 0.0:
		return 1.0
	return clampf(elapsed / PHASE_DURATION, 0.0, 1.0)


## Devuelve "DAY" o "NIGHT" según la fase actual.
func get_phase_name() -> String:
	return "NIGHT" if is_night else "DAY"


## Proceso cada frame

func _process(delta: float) -> void:
	if not running:
		return

	elapsed += delta
	_tick_acc += delta

	## Emitir tick cada segundo (1s)
	if _tick_acc >= 1.0:
		_tick_acc -= 1.0
		EventBus.time_tick.emit(current_day, elapsed, get_phase_name())

	## Se acabó la fase actual?
	if elapsed >= PHASE_DURATION:
		_advance_phase()


## Lógica interna

## Avanza a la siguiente fase. Si termina la noche, incrementa el día.
func _advance_phase() -> void:
	elapsed -= PHASE_DURATION  ## conservar excedente para precisión
	_tick_acc = 0.0

	if is_night:
		## La noche acaba -> nuevo día
		current_day += 1
		is_night = false
		EventBus.day_started.emit(current_day)
	else:
		## El día acaba -> empieza la noche
		is_night = true

	EventBus.day_phase_changed.emit(is_night)
	EventBus.time_tick.emit(current_day, elapsed, get_phase_name())

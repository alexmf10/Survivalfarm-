## Bus de eventos global (Autoload). Canal central de comunicación.
## Los actores y servicios emiten señales aquí; la UI las escucha sin conocer al emisor.
## También aloja el ServiceLocator para acceso global a servicios.
##
## Conexiones:
## - ProfileService emite: achievement_unlocked
## - UI screens emiten/escuchan: screen_change_requested, profile_updated
## - DayCycleService emite: day_phase_changed, day_started, time_tick
## - DayCycleHUD escucha: day_phase_changed, day_started, time_tick
extends Node

# Señales globales
signal achievement_unlocked(achievement_id: String)
signal profile_updated()
signal screen_change_requested(screen_name: String)

# Señales del ciclo día/noche
## Emitida por DayCycleService cuando la fase cambia.
## Escuchada por DayCycleHUD.
signal day_phase_changed(is_night: bool)

## Emitida por DayCycleService al inicio de cada nuevo día (cuando termina la noche).
## Escuchada por DayCycleHUD para actualizar el contador.
signal day_started(day_number: int)

## Emitida por DayCycleService cada segundo mientras el reloj corre.
## Escuchada por DayCycleHUD para actualizar la barra de progreso y etiquetas.
signal time_tick(day_number: int, elapsed: float, phase: String)

#señales del inventario
##Emitida y escuchada por 
# Registro de servicios compartidos.
var services: ServiceLocator = ServiceLocator.new()

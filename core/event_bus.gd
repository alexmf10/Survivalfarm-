## Bus de eventos global (Autoload). Canal central de comunicación.
## Los actores y servicios emiten señales aquí; la UI las escucha sin conocer al emisor.
## También aloja el ServiceLocator para acceso global a servicios.
##
## Conexiones:
## - ProfileService emite: achievement_unlocked
## - UI screens emiten/escuchan: screen_change_requested, profile_updated
## - DayCycleService emite: day_phase_changed, day_started, time_tick
## - DayCycleHUD escucha: day_phase_changed, day_started, time_tick
## - Player emite: player_spawned, player_despawned, player_position_changed
## - ToolComponent emite: player_tilled, player_watered, player_planted, player_harvest_attempted
## - CropService emite: tile_tilled, crop_planted, crop_watered, crop_grown, crop_harvested
## - FarmService escucha: tile_tilled, crop_planted, crop_grown, crop_harvested, crop_watered
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

# Señales del jugador (feature 05_player_character)
## Emitida por Player._ready() al aparecer en el mundo.
## Escuchada por: cámara, enemigos futuros, UI que necesite la referencia.
signal player_spawned(player: Node)

## Emitida por Player._exit_tree() al salir del mundo.
signal player_despawned()

## Emitida periódicamente por Player cuando se ha movido lo bastante.
## Escuchada (en el futuro) por: SaveService para autoguardado, minimapa.
signal player_position_changed(position: Vector2)

## Emitida cuando el jugador cambia su herramienta activa.
## Escuchada por ToolHUD y TestToolbarHUD para actualizar la interfaz.
signal player_tool_changed(tool: ToolsComponent.Tools)

# Señales de acciones del jugador sobre el mundo (emitidas por ToolComponent)
# NOTA: Todas reciben tile_pos (Vector2i) — el ToolComponent calcula la coordenada
# del tile bajo el ratón y valida el radio de acción ANTES de emitir.

## Emitida cuando el jugador ara un tile.
signal player_tilled(tile_pos: Vector2i)

## Emitida cuando el jugador riega un tile.
signal player_watered(tile_pos: Vector2i)

## Emitida cuando el jugador planta un cultivo.
signal player_planted(tile_pos: Vector2i, crop_type: CropComponent.CropType)

## Emitida cuando el jugador intenta cosechar (tecla E).
signal player_harvest_attempted(tile_pos: Vector2i)

# Señales de estado de cultivos (emitidas por CropService)
## Emitida cuando un tile ha sido arado correctamente.
signal tile_tilled(tile_pos: Vector2i)

## Emitida cuando un cultivo ha sido plantado.
signal crop_planted(tile_pos: Vector2i, crop_type: CropComponent.CropType)

## Emitida cuando un cultivo ha sido regado.
signal crop_watered(tile_pos: Vector2i)

## Emitida cuando un cultivo crece a un nuevo stage.
signal crop_grown(tile_pos: Vector2i, new_stage: int, max_stages: int)

## Emitida cuando un cultivo es cosechado.
signal crop_harvested(tile_pos: Vector2i, crop_type: CropComponent.CropType)

## Emitida por ToolComponent cuando se usa una herramienta (para squash/stretch feedback).
signal tool_action_performed(tool: ToolsComponent.Tools, tile_pos: Vector2i)

# [TEST] Señal de debug — avanzar crecimiento de un cultivo manualmente.
signal debug_advance_crop(tile_pos: Vector2i)

# Registro de servicios compartidos.
var services: ServiceLocator = ServiceLocator.new()

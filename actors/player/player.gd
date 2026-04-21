## Player — Fachada de la entidad del jugador.
##
## Este script es INTENCIONADAMENTE FINO. No contiene lógica de movimiento,
## de animación ni de input. Esas responsabilidades viven en los componentes
## hijos (MovementComponent, AnimationComponent).
##
## --- Responsabilidades ---
## 1. Registrarse en el PlayerService al aparecer / desregistrarse al salir.
## 2. Emitir al EventBus los eventos que al RESTO del juego le interesan
##    (player_spawned, player_despawned, player_position_changed).
##
## --- Diferencia entre señales locales y globales ---
## • Las señales internas (moved, stopped, facing_changed) NO salen de la
##   entidad: MovementComponent ↔ AnimationComponent se hablan directamente.
## • Las señales globales suben al EventBus para que otros sistemas
##   (cámara, enemigos, save...) puedan reaccionar sin conocer al Player.
##
## --- Árbol de la escena ---
## Player (CharacterBody2D)                ← este script
## ├── AnimatedSprite2D                    ← representación visual
## ├── CollisionShape2D                    ← colisión física
## ├── MovementComponent                   ← lee WASD, mueve al padre
## ├── AnimationComponent                  ← escucha y elige animaciones
## ├── ToolComponent                       ← gestiona herramientas y emite señales de cultivo
## └── Camera2D                            ← sigue al jugador
class_name Player
extends CharacterBody2D

## Cada cuántos segundos como mínimo publicamos la posición al EventBus.
## Así no saturamos el bus con un evento por frame.
const POSITION_BROADCAST_INTERVAL: float = 0.5

## Distancia mínima que hay que moverse desde el último broadcast para
## volver a emitir. Evita ruido cuando el jugador está quieto.
const POSITION_BROADCAST_MIN_DELTA: float = 4.0

var _broadcast_timer: float = 0.0
var _last_broadcast_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Registrarse como jugador activo en el servicio
	var player_svc := EventBus.services.player as PlayerService
	if player_svc:
		player_svc.set_active_player(self)

	_last_broadcast_position = global_position
	EventBus.player_spawned.emit(self)


func _exit_tree() -> void:
	var player_svc := EventBus.services.player as PlayerService
	if player_svc:
		player_svc.clear_active_player()
	EventBus.player_despawned.emit()


func _process(delta: float) -> void:
	# Broadcast throttled de la posición. No se publica cada frame — se
	# publica como mucho cada POSITION_BROADCAST_INTERVAL segundos, y solo
	# si el jugador se ha movido lo bastante.
	_broadcast_timer += delta
	if _broadcast_timer < POSITION_BROADCAST_INTERVAL:
		return
	_broadcast_timer = 0.0

	if global_position.distance_to(_last_broadcast_position) >= POSITION_BROADCAST_MIN_DELTA:
		_last_broadcast_position = global_position
		EventBus.player_position_changed.emit(global_position)

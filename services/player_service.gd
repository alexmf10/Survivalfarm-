## PlayerService — "Directorio telefónico" del jugador activo.
##
## Servicio intencionalmente FINO. Solo guarda una referencia al nodo Player
## que esté actualmente en escena. Otros sistemas (cámara, enemigos, save,
## combate) lo consultan para encontrar al jugador sin tener que buscarlo
## por ruta en el árbol ni usar grupos de Godot.
##
## --- Arquitectura ---
## • Registrado por main.gd con clave "player" en el ServiceLocator.
## • Player._ready() llama set_active_player(self) al aparecer.
## • Player._exit_tree() llama clear_active_player() al desaparecer.
## • No emite señales propias. Las señales relacionadas con el jugador se
##   publican en EventBus (player_spawned, player_despawned, ...).
##
## --- Por qué RefCounted ---
## No necesita _process() ni estar en el árbol; es un contenedor de
## referencia. Mismo patrón que SaveService y ProfileService.
class_name PlayerService
extends RefCounted

var _active_player: Node = null


# ── API pública ─────────────────────────────────────────────────────────────

## Lo llama el Player en _ready() tras aparecer en escena.
func set_active_player(player: Node) -> void:
	_active_player = player


## Lo llama el Player en _exit_tree() al desaparecer.
func clear_active_player() -> void:
	_active_player = null


## Devuelve el jugador activo o null si no hay ninguno.
func get_active_player() -> Node:
	return _active_player


## Comprobación rápida para sistemas que solo quieren saber si existe.
func has_player() -> bool:
	return _active_player != null and is_instance_valid(_active_player)


## Atajo para consultar la posición actual del jugador.
## Devuelve Vector2.ZERO si no hay jugador activo.
func get_position() -> Vector2:
	if has_player() and _active_player is Node2D:
		return (_active_player as Node2D).global_position
	return Vector2.ZERO

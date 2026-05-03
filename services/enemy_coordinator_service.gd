## EnemyCoordinatorService — Árbitro de ataques enemigos.
##
## Limita cuántos enemigos pueden estar comprometidos en un ataque
## simultáneamente. El resto presionan/orbitan al jugador, sin pegar.
## Esto evita el caos de N enemigos golpeando a la vez y permite que el
## combate tenga ritmo legible: amenaza clara → ventana de castigo → reset.
##
## --- Arquitectura ---
## • RefCounted, registrado en main.gd con clave "enemy_coord".
## • Stateful: guarda los nodos que actualmente tienen "permiso" para atacar.
## • API simple: request_attack_slot(node) / release_attack_slot(node).
## • Auto-limpia entradas inválidas (zombies muertos) al pedir slot.
##
## --- Quiénes lo usan ---
## • ZombieAttackComponent.try_start_attack() llama request_attack_slot
##   antes de entrar en WINDUP.
## • ZombieAttackComponent libera el slot al terminar RECOVERY o al ser
##   interrumpido.
class_name EnemyCoordinatorService
extends RefCounted

## Máximo de enemigos atacando simultáneamente.
const MAX_CONCURRENT_ATTACKERS: int = 1

var _attacking: Array = []  # Array[Node]


## Pide permiso para atacar. Devuelve true si se concedió.
## Si el nodo ya tiene slot, devuelve true sin duplicar.
func request_attack_slot(node: Node) -> bool:
	_cleanup()
	if node in _attacking:
		return true
	if _attacking.size() >= MAX_CONCURRENT_ATTACKERS:
		return false
	_attacking.append(node)
	return true


## Libera el slot del nodo. Idempotente.
func release_attack_slot(node: Node) -> void:
	_attacking.erase(node)


## Cuántos atacantes activos hay (debug/UI).
func active_attackers() -> int:
	_cleanup()
	return _attacking.size()


# ── Internos ────────────────────────────────────────────────────────────────

func _cleanup() -> void:
	var valid: Array = []
	for n in _attacking:
		if is_instance_valid(n):
			valid.append(n)
	_attacking = valid

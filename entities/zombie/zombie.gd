## Zombie — Fachada fina de la entidad enemigo zombie.
##
## Script intencionadamente FINO, igual que Player.gd.
## No contiene lógica de IA, animación, ni combate — todo vive en componentes.
##
## --- Responsabilidades ---
## 1. Conectar HealthComponent.died → iniciar secuencia de muerte.
## 2. Emitir EventBus.zombie_died al morir.
## 3. Liberarse del árbol tras un breve delay tras morir.
##
## --- Árbol de la escena ---
## Zombie (CharacterBody2D)                ← este script
## ├── AnimatedSprite2D                    ← representación visual
## ├── CollisionShape2D                    ← colisión física
## ├── MovementComponent                   ← input_enabled=false, controlado por IA
## ├── AnimationComponent                  ← escucha señales de MovementComponent
## ├── ZombieAIComponent                   ← lógica de WANDER/CHASE
## ├── ZombieAttackComponent               ← ataque melee (puñetazo)
## ├── HealthComponent                     ← vida del zombie
## ├── HealthBarComponent                  ← barra de vida sobre sprite
## └── DamageFlashComponent                ← flash rojo al recibir daño
class_name Zombie
extends CharacterBody2D

## Tiempo en segundos entre la muerte y queue_free() (para ver animación si la hubiera).
const DEATH_CLEANUP_DELAY: float = 0.5

var _last_hp: float = 0.0


func _ready() -> void:
	add_to_group("zombies")

	var health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_died)
		health.health_changed.connect(_on_damaged)
		_last_hp = health.current_health


func _exit_tree() -> void:
	pass  # Los componentes se desconectan solos en sus propios _exit_tree()


# ── Handlers ─────────────────────────────────────────────────────────────────

func _on_died() -> void:
	remove_from_group("zombies")

	# Desactivar IA y colisión para no seguir interactuando
	var ai: Node = get_node_or_null("ZombieAIComponent")
	if ai:
		ai.set_process(false)

	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", true)

	# Detener movimiento
	var movement: MovementComponent = get_node_or_null("MovementComponent") as MovementComponent
	if movement:
		movement.stop()

	# Emitir señal global
	EventBus.zombie_died.emit(self)

	# Liberar el nodo tras el delay
	await get_tree().create_timer(DEATH_CLEANUP_DELAY).timeout
	queue_free()


func _on_damaged(current_hp: float, _max_hp: float) -> void:
	if current_hp >= _last_hp:
		_last_hp = current_hp
		return  # curación, no daño
	_last_hp = current_hp

	# Interrumpir el ataque en curso si hay alguno (cancela WINDUP/STRIKE/RECOVERY).
	# Esto permite "cortar" un golpe del zombi pegándole en el momento adecuado.
	var attack: Node = get_node_or_null("ZombieAttackComponent")
	if attack and attack.has_method("interrupt"):
		attack.interrupt()

	var anim: AnimationComponent = get_node_or_null("AnimationComponent") as AnimationComponent
	if anim and not anim.is_action_playing():
		anim.play_action("hurt")

class_name ZombieArcher
extends CharacterBody2D

const DEATH_CLEANUP_DELAY: float = 0.5

var _last_hp: float = 0.0


func _ready() -> void:
	add_to_group("zombies")

	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_died)
		health.health_changed.connect(_on_damaged)
		_last_hp = health.current_health


func _exit_tree() -> void:
	pass


func _on_died() -> void:
	remove_from_group("zombies")

	var ai := get_node_or_null("ZombieArcherAIComponent")
	if ai:
		ai.set_process(false)

	var shoot := get_node_or_null("ZombieArcherShootComponent")
	if shoot:
		shoot.set_process(false)

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", true)

	var movement := get_node_or_null("MovementComponent") as MovementComponent
	if movement:
		movement.stop()

	EventBus.zombie_died.emit(self)

	await get_tree().create_timer(DEATH_CLEANUP_DELAY, false).timeout
	queue_free()


func _on_damaged(current_hp: float, _max_hp: float) -> void:
	if current_hp >= _last_hp:
		_last_hp = current_hp
		return
	_last_hp = current_hp

	var shoot := get_node_or_null("ZombieArcherShootComponent")
	if shoot and shoot.has_method("interrupt"):
		shoot.interrupt()

	var anim := get_node_or_null("AnimationComponent") as AnimationComponent
	if anim:
		anim.play_action("hurt")

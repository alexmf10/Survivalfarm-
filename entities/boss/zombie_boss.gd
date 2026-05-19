class_name ZombieBoss
extends CharacterBody2D

const DEATH_CLEANUP_DELAY: float = 1.0
const WIN_MESSAGE: String = "You defeated the patriarch of the horde.\nYour land is safe again."

var _last_hp: float = 0.0


func _ready() -> void:
	add_to_group("zombies")
	add_to_group("bosses")

	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_died)
		health.health_changed.connect(_on_damaged)
		_last_hp = health.current_health


func _on_died() -> void:
	remove_from_group("zombies")
	remove_from_group("bosses")

	var ai := get_node_or_null("ZombieAIComponent")
	if ai:
		ai.set_process(false)

	var attack := get_node_or_null("ZombieAttackComponent")
	if attack and attack.has_method("interrupt"):
		attack.interrupt()

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", true)

	var movement := get_node_or_null("MovementComponent") as MovementComponent
	if movement:
		movement.stop()

	EventBus.zombie_died.emit(self)
	await _play_death_sequence()
	EventBus.game_won.emit(WIN_MESSAGE)
	await get_tree().create_timer(DEATH_CLEANUP_DELAY, false).timeout
	queue_free()


func _on_damaged(current_hp: float, _max_hp: float) -> void:
	if current_hp >= _last_hp:
		_last_hp = current_hp
		return
	_last_hp = current_hp

	var attack := get_node_or_null("ZombieAttackComponent")
	if attack and attack.has_method("interrupt"):
		attack.interrupt()

	var anim := get_node_or_null("AnimationComponent") as AnimationComponent
	if anim and not anim.is_action_playing():
		anim.play_action("hurt")


func _play_death_sequence() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		await get_tree().create_timer(0.6, false).timeout
		return

	sprite.stop()
	sprite.z_index += 20

	var original_scale: Vector2 = sprite.scale
	var original_y: float = sprite.position.y
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.25, 0.18, 1.0), 0.12)
	tween.parallel().tween_property(sprite, "scale", original_scale * 1.18, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite, "rotation_degrees", -8.0, 0.08)
	tween.tween_property(sprite, "rotation_degrees", 8.0, 0.08)
	tween.tween_property(sprite, "rotation_degrees", -5.0, 0.08)
	tween.tween_property(sprite, "rotation_degrees", 0.0, 0.08)
	tween.tween_property(sprite, "modulate", Color(0.25, 0.25, 0.25, 0.0), 0.65)
	tween.parallel().tween_property(sprite, "position:y", original_y + 18.0, 0.65)
	tween.parallel().tween_property(sprite, "scale", original_scale * 0.65, 0.65)
	await tween.finished

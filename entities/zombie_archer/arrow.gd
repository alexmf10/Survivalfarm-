class_name Arrow
extends Area2D

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 130.0
var _damage: float = 12.0
var _max_range: float = 220.0
var _traveled: float = 0.0
var _has_hit: bool = false


func init(start_pos: Vector2, target_pos: Vector2, damage: float) -> void:
	global_position = start_pos
	_damage = damage
	_direction = (target_pos - start_pos).normalized()
	rotation = _direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _has_hit:
		return
	var step := _direction * _speed * delta
	global_position += step
	_traveled += step.length()
	if _traveled >= _max_range:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _has_hit or not (body is Player):
		return
	_has_hit = true
	for child in body.get_children():
		if child is HealthComponent:
			var combat_svc := EventBus.services.combat as CombatService
			var net_damage := _damage
			if combat_svc:
				net_damage = combat_svc.calculate_damage(_damage, 0.0)
			child.take_damage(net_damage)
			break
	queue_free()

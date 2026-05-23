class_name Arrow
extends Area2D

const COLLISION_MASK: int = 3  # layer 1 (walls/trees) + layer 2 (player)

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


func _process(delta: float) -> void:
	if _has_hit:
		return

	var step := _direction * _speed * delta
	var next_pos := global_position + step

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, next_pos, COLLISION_MASK)
	var hit := space.intersect_ray(query)

	if hit:
		var body = hit.get("collider")
		if body is Player:
			_apply_damage(body)
		queue_free()
		return

	global_position = next_pos
	_traveled += step.length()
	if _traveled >= _max_range:
		queue_free()


func _apply_damage(player: Node2D) -> void:
	_has_hit = true
	for child in player.get_children():
		if child is HealthComponent:
			var combat_svc := EventBus.services.combat as CombatService
			var trade_svc := EventBus.services.trade as TradeService
			var net_damage := _damage
			if combat_svc:
				var armor_reduction: float = 0.0
				if trade_svc:
					armor_reduction = trade_svc.get_total_armor_reduction()
				net_damage = combat_svc.calculate_damage(_damage, 0.0, armor_reduction)
			child.take_damage(net_damage)
			break

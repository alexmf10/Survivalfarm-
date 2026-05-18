extends StaticBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var interactable_component: InteractableBehaviour = $InteractableComponent

func _ready() -> void:
	interactable_component.interactable_activated.connect(on_interactable_activated)
	interactable_component.interactable_deactivated.connect(on_interactable_deactivated)
	if not EventBus.tribute_failed.is_connected(_on_tribute_failed):
		EventBus.tribute_failed.connect(_on_tribute_failed)
	collision_layer = 1

func on_interactable_activated() -> void:
	if _is_horde_lock_active():
		_close_door()
		return
	# print("activated")
	animated_sprite_2d.play("open_door")
	collision_layer = 2
	
func on_interactable_deactivated() -> void:
	_close_door()

func _on_tribute_failed(_message: String) -> void:
	_close_door()

func _close_door() -> void:
	# print("deactivated")
	animated_sprite_2d.play("close_door")
	collision_layer = 1

func _is_horde_lock_active() -> bool:
	var tribute_svc := EventBus.services.tribute as TributeService
	return tribute_svc != null and tribute_svc.horde_started

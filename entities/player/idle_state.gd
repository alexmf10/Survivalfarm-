extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	if player.player_direction == Vector2.LEFT:
		animated_sprite_2d.play("idle_left")
	elif player.player_direction == Vector2.RIGHT:
		animated_sprite_2d.play("idle_right")
	elif player.player_direction == Vector2.UP:
		animated_sprite_2d.play("idle_back")	
	elif player.player_direction == Vector2.DOWN:
		animated_sprite_2d.play("idle_front")
	else:
		animated_sprite_2d.play("idle_front")

func _on_next_transitions() -> void:
	EventBus.services.input.movement_input()
	
	if EventBus.services.input.is_movement_input():
		transition.emit("Walk");
		
	if player.current_tools == ToolsComponent.Tools.AxeWood && EventBus.services.input.use_tool():
		transition.emit("Chopping")
		
	if player.current_tools == ToolsComponent.Tools.TillGround && EventBus.services.input.use_tool():
		transition.emit("Tilling")
		
	if player.current_tools == ToolsComponent.Tools.WaterCrops && EventBus.services.input.use_tool():
		transition.emit("Watering")

	if player.current_tools == ToolsComponent.Tools.PlantWheat && EventBus.services.input.use_tool():
		transition.emit("Planting")

	if player.current_tools == ToolsComponent.Tools.PlantBeet && EventBus.services.input.use_tool():
		transition.emit("Planting")

	if player.current_tools == ToolsComponent.Tools.None && EventBus.services.input.use_tool():
		EventBus.player_harvest_attempted.emit(player.global_position, player.player_direction)


func _on_enter() -> void:
	pass


func _on_exit() -> void:
	animated_sprite_2d.stop()

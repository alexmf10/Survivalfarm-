extends Node2D

const DayCycleHUD_SCENE: PackedScene = preload("res://ui/hud/day_cycle_hud.tscn")

## Press P to advance the day. All planted crops are watered automatically each day.


func _ready() -> void:
	add_child(DayCycleHUD_SCENE.instantiate())
	EventBus.services.day_cycle.start_cycle(1)
	EventBus.day_started.connect(_on_day_started)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_P and event.pressed:
		_advance_day()


func _advance_day() -> void:
	var day_cycle: DayCycleService = EventBus.services.day_cycle
	EventBus.day_started.emit(day_cycle.current_day + 1)


func _on_day_started(_day: int) -> void:
	EventBus.services.crop.water_all()

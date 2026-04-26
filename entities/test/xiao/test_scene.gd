extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_P:
			var day_cycle := EventBus.services.day_cycle as DayCycleService
			if day_cycle:
				day_cycle.start_cycle(day_cycle.current_day + 1)
		KEY_O:
			var crop_svc := EventBus.services.crop as CropService
			if crop_svc:
				crop_svc.water_all()

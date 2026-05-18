extends Node

const RESULT_PATH: String = "C:/Users/alex/Desktop/0_ProyectoAcademico/survivalfarm_smoke_result.txt"
const WORLD_SCENE_PATH: String = "res://core/game_world.tscn"

var _failures: Array[String] = []
var _tribute_paid_count: int = 0
var _final_started_count: int = 0
var _game_won_count: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	_register_services()
	_connect_observers()
	_prepare_clean_smoke_slot()
	_assert_legacy_save_migration()

	var world := _load_world()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(world != null, "GameWorld instancia correctamente.")
	_assert(EventBus.services.tribute is TributeService, "TributeService registrado.")
	_assert(EventBus.services.trade is TradeService, "TradeService registrado.")

	var trade_svc := EventBus.services.trade as TradeService
	var tribute_svc := EventBus.services.tribute as TributeService
	var day_svc := EventBus.services.day_cycle as DayCycleService

	_assert(not trade_svc.starter_pack_granted, "La partida empieza sin pack inicial.")
	_assert(tribute_svc.get_objective_text().contains("trader"), "El objetivo inicial apunta al mercader.")

	_simulate_starter_pack(trade_svc)
	await get_tree().process_frame
	_assert(trade_svc.starter_pack_granted, "El pack inicial queda marcado como entregado.")
	_assert(tribute_svc.starter_pack_claimed, "El sistema de tributos detecta el pack inicial.")
	_assert(trade_svc.coins == 50, "El pack inicial entrega 50 monedas.")
	_assert(trade_svc.get_seed_count(CropComponent.CropType.Wheat) == 40, "El pack inicial entrega 40 semillas de trigo.")
	_assert(trade_svc.get_seed_count(CropComponent.CropType.Beet) == 20, "El pack inicial entrega 20 semillas de remolacha.")
	_assert_inventory_and_crop_persistence()

	_pay_tribute(tribute_svc, 15, 8, 1)
	_pay_tribute(tribute_svc, 35, 18, 2)
	_pay_tribute(tribute_svc, 60, 30, 3)

	_assert(_tribute_paid_count == 3, "Se emiten tres pagos de tributo antes del final.")
	_assert(tribute_svc.current_tribute_index == 3, "El cuarto tributo queda preparado tras pagar el tercero.")

	day_svc.pause()
	day_svc.current_day = 12
	var reveal_text: String = tribute_svc.interact_with_collector()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(reveal_text.contains("You have paid enough"), "El cuarto tributo revela la marcha.")
	_assert(tribute_svc.final_started, "El final queda marcado como iniciado.")
	_assert(_final_started_count == 1, "Se emite el evento de boss final una vez.")

	var bosses := get_tree().get_nodes_in_group("bosses")
	_assert(bosses.size() == 1, "El boss final aparece en el mundo.")
	if bosses.size() == 1:
		var boss := bosses[0] as Node
		var health := boss.get_node_or_null("HealthComponent") as HealthComponent
		_assert(health != null, "El boss tiene HealthComponent.")
		if health:
			health.take_damage(9999.0)
			await get_tree().create_timer(2.2).timeout
			_assert(_game_won_count == 1, "Matar al boss emite la victoria.")

	_finish()


func _register_services() -> void:
	EventBus.services = ServiceLocator.new()

	var profile_svc: ProfileService = ProfileService.new()
	EventBus.services.register(&"profile", profile_svc)

	var save_svc: SaveService = SaveService.new()
	save_svc.active_slot = 1
	EventBus.services.register(&"save", save_svc)

	var day_cycle_svc: DayCycleService = DayCycleService.new()
	day_cycle_svc.name = "DayCycleServiceSmoke"
	EventBus.add_child(day_cycle_svc)
	EventBus.services.register(&"day_cycle", day_cycle_svc)

	var player_svc: PlayerService = PlayerService.new()
	EventBus.services.register(&"player", player_svc)

	var crop_svc: CropService = CropService.new()
	crop_svc.connect_signals()
	crop_svc.register_crop(preload("res://data/definition/wheat.tres"))
	crop_svc.register_crop(preload("res://data/definition/beet.tres"))
	EventBus.services.register(&"crop", crop_svc)

	var farm_svc: FarmService = FarmService.new()
	farm_svc.name = "FarmServiceSmoke"
	EventBus.add_child(farm_svc)
	EventBus.services.register(&"farm", farm_svc)

	var trade_svc: TradeService = TradeService.new()
	trade_svc.connect_signals()
	EventBus.services.register(&"trade", trade_svc)

	var tribute_svc: TributeService = TributeService.new()
	tribute_svc.connect_signals()
	EventBus.services.register(&"tribute", tribute_svc)

	var combat_svc: CombatService = CombatService.new()
	EventBus.services.register(&"combat", combat_svc)

	var enemy_coord_svc: EnemyCoordinatorService = EnemyCoordinatorService.new()
	EventBus.services.register(&"enemy_coord", enemy_coord_svc)


func _prepare_clean_smoke_slot() -> void:
	var save_svc := EventBus.services.save as SaveService
	if save_svc == null:
		return
	if save_svc.slot_exists(1):
		save_svc.delete_slot(1)
	save_svc.create_new_game(1, "Smoke")
	save_svc.active_slot = 1


func _assert_legacy_save_migration() -> void:
	var legacy_data := {
		"nickname": "Legacy",
		"day": 748,
		"timestamp": Time.get_unix_time_from_system(),
		"date_string": Time.get_datetime_string_from_system(),
		"player_hp": 100,
		"player_position": {"x": 0, "y": 0},
		"coins": 0,
		"inventory": [],
	}
	var file := FileAccess.open("user://saves/slot_2.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(legacy_data, "\t"))
		file.close()

	var save_svc := EventBus.services.save as SaveService
	var slot2_data: Dictionary = save_svc.read_slot_json(2)
	var story_state: Dictionary = slot2_data.get("story_state", {})
	_assert(bool(story_state.get("starter_pack_granted", false)), "Los saves legacy de dia > 1 no disparan el tutorial inicial.")
	_assert(int(story_state.get("current_tribute_index", 0)) >= 4, "Los saves legacy de dia > 1 no quedan atrapados en tributos vencidos.")
	_assert(bool(slot2_data.get("starter_pack_granted", false)), "Los saves legacy desbloquean herramientas al cargar.")

	var trade_svc := EventBus.services.trade as TradeService
	var tribute_svc := EventBus.services.tribute as TributeService
	trade_svc.load_from_save(slot2_data)
	tribute_svc.apply_save_state(story_state)
	var slot1_data: Dictionary = save_svc.read_slot_json(1)
	trade_svc.load_from_save(slot1_data)
	tribute_svc.apply_save_state(slot1_data.get("story_state", {}))
	_assert(not trade_svc.starter_pack_granted, "Cambiar de un save legacy a partida nueva reinicia TradeService.")
	_assert(not tribute_svc.starter_pack_claimed, "Cambiar de un save legacy a partida nueva reinicia TributeService.")

	var broken_data := {
		"nickname": "Broken",
		"day": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"date_string": Time.get_datetime_string_from_system(),
		"story_state": {
			"starter_pack_granted": true,
			"current_tribute_index": 0,
			"horde_started": false,
			"final_started": false,
		},
		"trade_state": {
			"coins": 0,
			"slots": [],
			"active_hotbar_index": 0,
			"starter_pack_granted": true,
		},
		"crop_state": {"crops": []},
	}
	var broken_file := FileAccess.open("user://saves/slot_3.json", FileAccess.WRITE)
	if broken_file:
		broken_file.store_string(JSON.stringify(broken_data, "\t"))
		broken_file.close()
	var slot3_data: Dictionary = save_svc.read_slot_json(3)
	_assert(not bool(slot3_data.get("story_state", {}).get("starter_pack_granted", true)), "Un save corrupto dia 1 sin inventario/cultivos permite recuperar el pack.")
	_assert(not bool(slot3_data.get("starter_pack_granted", true)), "Un save corrupto dia 1 desbloquea de nuevo el mercader.")


func _assert_inventory_and_crop_persistence() -> void:
	var save_svc := EventBus.services.save as SaveService
	var trade_svc := EventBus.services.trade as TradeService
	var crop_svc := EventBus.services.crop as CropService
	if save_svc == null or trade_svc == null or crop_svc == null:
		_failures.append("Servicios no disponibles para probar persistencia.")
		return

	var crop_tile := Vector2i(22, 13)
	_assert(crop_svc.can_plant(crop_tile), "El tile de prueba permite plantar.")
	EventBus.player_planted.emit(crop_tile, CropComponent.CropType.Wheat)
	trade_svc.consume_active_item()

	var slot1_save: Dictionary = save_svc.read_slot_json(1)
	var reloaded_trade := TradeService.new()
	reloaded_trade.load_from_save(slot1_save)
	_assert(reloaded_trade.coins == trade_svc.coins, "Las monedas se recargan desde el save.")
	_assert(reloaded_trade.get_seed_count(CropComponent.CropType.Wheat) == trade_svc.get_seed_count(CropComponent.CropType.Wheat), "Las semillas se recargan desde el save.")

	var saved_crops: Array = slot1_save.get("crops", [])
	_assert(saved_crops.size() == 1, "El cultivo plantado se escribe en crops.")
	var reloaded_crop := CropService.new()
	reloaded_crop.register_crop(preload("res://data/definition/wheat.tres"))
	reloaded_crop.register_crop(preload("res://data/definition/beet.tres"))
	reloaded_crop.set_tilled_layer(null)
	reloaded_crop.set_tillable_area([crop_tile] as Array[Vector2i])
	reloaded_crop.apply_save_state({"crops": saved_crops})
	_assert(reloaded_crop.has_crop(crop_tile), "El cultivo plantado se recarga desde el save.")


func _connect_observers() -> void:
	EventBus.tribute_paid.connect(func(_tribute_index: int) -> void:
		_tribute_paid_count += 1
	)
	EventBus.final_boss_started.connect(func(_message: String) -> void:
		_final_started_count += 1
	)
	EventBus.game_won.connect(func(_message: String) -> void:
		_game_won_count += 1
	)


func _load_world() -> Node:
	var world_scene := load(WORLD_SCENE_PATH) as PackedScene
	if world_scene == null:
		_failures.append("No se pudo cargar %s." % WORLD_SCENE_PATH)
		return null
	var world := world_scene.instantiate()
	get_tree().root.add_child(world)
	return world


func _simulate_starter_pack(trade_svc: TradeService) -> void:
	var granted := trade_svc.grant_starter_pack()
	_assert(granted, "El mercader puede entregar el pack inicial una sola vez.")
	EventBus.starter_pack_received.emit()


func _pay_tribute(tribute_svc: TributeService, wheat: int, beet: int, expected_index: int) -> void:
	_add_crops(CropComponent.CropType.Wheat, wheat)
	_add_crops(CropComponent.CropType.Beet, beet)
	var response: String = tribute_svc.interact_with_collector()
	_assert(response.contains("Delivery accepted"), "El tributo %d acepta la entrega." % expected_index)
	_assert(tribute_svc.current_tribute_index == expected_index, "El tributo %d avanza el indice." % expected_index)


func _add_crops(crop_type: CropComponent.CropType, amount: int) -> void:
	for i in range(amount):
		EventBus.crop_harvested.emit(Vector2i.ZERO, crop_type)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _finish() -> void:
	var output := "PASS\n"
	var exit_code := 0
	if not _failures.is_empty():
		output = "FAIL\n"
		for failure in _failures:
			output += "- %s\n" % failure
		exit_code = 1

	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(output)
		file.close()

	get_tree().quit(exit_code)

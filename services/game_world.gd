## Escena de juego. Carga el mapa del mundo (test_scene.tscn) con todos los
## assets reales (tilemap, casas, zonas de cultivo) y el jugador ya instanciado.
##
## --- Arquitectura ---
## - Instancia el mapa completo (test_scene.tscn) desactivando su script propio
##   para evitar duplicar la lógica de HUD y ciclo día/noche.
## - Carga el HUD del ciclo día/noche (CanvasLayer) y lo añade como hijo.
## - Arranca el DayCycleService leyendo el día guardado del slot activo.
## - Autoguarda el día cuando avanza (EventBus.day_started).
## - Riega automáticamente todos los cultivos al inicio de cada día.
##
## --- Conexiones ---
## - Recibe: EventBus.day_started → auto-guarda el día + riega cultivos
## - Usa: EventBus.services.day_cycle → DayCycleService.start_cycle()
## - Usa: EventBus.services.save → SaveService.get_day() / save_day()
## - Usa: EventBus.services.crop → CropService.water_all()
## - NO conoce directamente al Player — el mapa ya lo incluye. El Player se
##   auto-registra en PlayerService y emite EventBus.player_spawned al aparecer.
class_name GameWorld
extends Control

const MAP_SCENE_PATH: String = "res://entities/test/alex/alex_scene.tscn"

## Slot activo (se establece antes de cambiar a esta escena).
var active_slot: int = 1
var _trade_open: bool = false


func _ready() -> void:
	# Leer el slot activo desde SaveService (puesto por slots_screen)
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		active_slot = save_svc.active_slot

	EventBus.player_spawned.connect(_on_player_spawned, CONNECT_ONE_SHOT)

	_build_world()
	_build_hud()
	_start_day_cycle()
	call_deferred("_restore_crops")
	call_deferred("_restore_inventory")

	EventBus.day_started.connect(_on_day_started)
	EventBus.trade_opened.connect(func() -> void: _trade_open = true)
	EventBus.trade_closed.connect(func() -> void: _trade_open = false)


func _exit_tree() -> void:
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		day_cycle_svc.pause()
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


# ── Construcción de la escena ───────────────────────────────────────────────

func _build_world() -> void:
	# Cargar el mapa completo con todos los assets (tilemap, casas, player)
	var map_scene: PackedScene = load(MAP_SCENE_PATH) as PackedScene
	if map_scene == null:
		push_error("GameWorld: no se pudo cargar el mapa en %s" % MAP_SCENE_PATH)
		return

	var world: Node2D = map_scene.instantiate() as Node2D
	add_child(world)

	var trader: Trader = Trader.new()
	# Posicionar al trader en el Marker2D "TraderSpawnPoint" si existe;
	# si no, fallback a la posición histórica.
	var trader_marker: Marker2D = world.get_node_or_null("SpawnPoints/TraderSpawnPoint") as Marker2D
	if trader_marker:
		trader.position = trader_marker.position
	else:
		trader.position = Vector2(350, 180)
	# call_deferred para evitar "Parent node is busy setting up children" cuando
	# los _ready() en cascada del mapa se están ejecutando.
	world.add_child.call_deferred(trader)


func _build_hud() -> void:
	var hud_scene: PackedScene = load("res://ui/hud/day_cycle_hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	add_child(hud)
	
	var tool_hud_scene: PackedScene = load("res://ui/hud/tool_hud.tscn")
	var tool_hud: CanvasLayer = tool_hud_scene.instantiate()
	add_child(tool_hud)

	var health_hud_scene: PackedScene = load("res://ui/hud/health_hud.tscn")
	var health_hud: CanvasLayer = health_hud_scene.instantiate()
	add_child(health_hud)

	#var sword_hud_scene: PackedScene = load("res://ui/hud/sword_hud.tscn")
	#var sword_hud: CanvasLayer = sword_hud_scene.instantiate()
	#add_child(sword_hud)

	var trade_hud: TradeHUD = TradeHUD.new()
	add_child(trade_hud)


func _start_day_cycle() -> void:
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	var save_svc: SaveService = EventBus.services.save as SaveService
	if day_cycle_svc and save_svc:
		var data: Dictionary = save_svc.read_slot_json(active_slot)
		var saved_day: int = data.get("day", 1)
		var saved_elapsed: float = data.get("elapsed", 0.0)
		var saved_is_night: bool = data.get("is_night", false)
		day_cycle_svc.start_cycle(saved_day, saved_elapsed, saved_is_night)


# ── Handlers ────────────────────────────────────────────────────────────────

func _on_player_spawned(player: Node) -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	if not save_svc: return
	var data: Dictionary = save_svc.read_slot_json(active_slot)
	var pos_data: Dictionary = data.get("player_position", {})
	var x: float = pos_data.get("x", 0.0)
	var y: float = pos_data.get("y", 0.0)
	if x != 0.0 or y != 0.0:
		player.global_position = Vector2(x, y)


func _restore_inventory() -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	var trade_svc: TradeService = EventBus.services.trade as TradeService
	if not save_svc or not trade_svc: return
	var data: Dictionary = save_svc.read_slot_json(active_slot)
	trade_svc.load_from_save(data)


func _restore_crops() -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	var crop_svc: CropService = EventBus.services.crop as CropService
	if not save_svc or not crop_svc: return
	var data: Dictionary = save_svc.read_slot_json(active_slot)
	var crops_data: Array = data.get("crops", [])
	if not crops_data.is_empty():
		crop_svc.load_crops_save_data(crops_data)


func _on_day_started(day_number: int) -> void:
	# Auto-guardar el día
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc:
		save_svc.save_day(active_slot, day_number)


func _input(event: InputEvent) -> void:
	if _trade_open:
		return
	if event.is_action_pressed("pause"):
		var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
		var save_svc: SaveService = EventBus.services.save as SaveService
		if day_cycle_svc and save_svc:
			save_svc.save_day(active_slot, day_cycle_svc.current_day)
			day_cycle_svc.pause()
		get_tree().change_scene_to_file("res://ui/menus/slots_screen.tscn")

	# PRUEBAS GLOBALES 
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P:
				var day_cycle := EventBus.services.day_cycle as DayCycleService
				if day_cycle:
					day_cycle.start_cycle(day_cycle.current_day + 1)
			KEY_N:
				# Debug: forzar transición a noche (útil para probar la cama)
				var day_cycle := EventBus.services.day_cycle as DayCycleService
				if day_cycle and not day_cycle.is_night:
					day_cycle.is_night = true
					day_cycle.elapsed = 0.0
					EventBus.day_phase_changed.emit(true)
					EventBus.time_tick.emit(day_cycle.current_day, 0.0, "NIGHT")
			KEY_O:
				var crop_svc := EventBus.services.crop as CropService
				if crop_svc:
					crop_svc.water_all()
			KEY_K:
				# Debug: infligir 15 de daño al jugador
				var player_svc := EventBus.services.player as PlayerService
				if player_svc and player_svc.has_player():
					var player: Node = player_svc.get_active_player()
					var health := player.get_node_or_null("HealthComponent") as HealthComponent
					if health:
						health.take_damage(15.0)
			KEY_L:
				# Debug: curar 20 HP al jugador
				var player_svc := EventBus.services.player as PlayerService
				if player_svc and player_svc.has_player():
					var player: Node = player_svc.get_active_player()
					var health := player.get_node_or_null("HealthComponent") as HealthComponent
					if health:
						health.heal(20.0)
			KEY_Z:
				get_viewport().set_input_as_handled()
				var zombie_scene: PackedScene = load("res://entities/zombie/zombie.tscn") as PackedScene
				if zombie_scene == null:
					push_error("GameWorld: no se pudo cargar zombie.tscn — ¿sprites importados?")
					return
				var zombie: Node2D = zombie_scene.instantiate() as Node2D
				if zombie == null:
					push_error("GameWorld: instantiate() de zombie.tscn devolvió null")
					return
				# Añadir al mundo PRIMERO, luego fijar posición (global_position requiere estar en el árbol)
				var world_node: Node = get_child(0)
				if world_node == null:
					push_error("GameWorld: get_child(0) es null, no hay nodo de mundo")
					return
				world_node.add_child(zombie)
				var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
				zombie.global_position = canvas_xform.affine_inverse() * get_viewport().get_mouse_position()

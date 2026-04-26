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

const MAP_SCENE_PATH: String = "res://entities/test/xiao/test_scene.tscn"

## Slot activo (se establece antes de cambiar a esta escena).
var active_slot: int = 1
var _trade_open: bool = false


func _ready() -> void:
	# Leer el slot activo desde SaveService (puesto por slots_screen)
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		active_slot = save_svc.active_slot

	_build_world()
	_build_hud()
	_start_day_cycle()

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
	trader.position = Vector2(350, 180)
	world.add_child(trader)


func _build_hud() -> void:
	var hud_scene: PackedScene = load("res://ui/hud/day_cycle_hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	add_child(hud)
	
	var tool_hud_scene: PackedScene = load("res://ui/hud/tool_hud.tscn")
	var tool_hud: CanvasLayer = tool_hud_scene.instantiate()
	add_child(tool_hud)

	var trade_hud: TradeHUD = TradeHUD.new()
	add_child(trade_hud)


func _start_day_cycle() -> void:
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	var save_svc: SaveService = EventBus.services.save as SaveService
	if day_cycle_svc and save_svc:
		var saved_day: int = save_svc.get_day(active_slot)
		day_cycle_svc.start_cycle(saved_day)


# ── Handlers ────────────────────────────────────────────────────────────────

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

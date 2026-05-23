## Escena raíz Bootstrap (punto de entrada de la aplicación al iniciar).
## Aquí se registrarán los servicios en el ServiceLocator.
##
## Servicios registrados:
## "profile"   → ProfileService (byRef) — logros por slot
## "save"      → SaveService (byRef) — gestión de slots de guardado
## "day_cycle"  → DayCycleService (Node) — ciclo día/noche
## "player"    → PlayerService (byRef) — directorio del jugador activo
## "crop"      → CropService (byRef) — estado de cultivos
## "farm"      → FarmService (Node) — visuales de cultivos
## "combat"    → CombatService (byRef) — cálculo centralizado de daño
## "enemy_coord" → EnemyCoordinatorService (byRef) — árbitro de ataques enemigos
## "sound"      → SoundService (Node) — reproduce SFX/música según señales del bus
extends Node


func _ready() -> void:
	# Servicio del perfil
	var profile_svc: ProfileService = ProfileService.new()
	EventBus.services.register(&"profile", profile_svc)

	# Servicio del guardado
	var save_svc: SaveService = SaveService.new()
	EventBus.services.register(&"save", save_svc)

	# DayCycleService es Node → necesita ser hijo del árbol para _process()
	var day_cycle_svc: DayCycleService = DayCycleService.new()
	day_cycle_svc.name = "DayCycleService"
	day_cycle_svc.process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.add_child(day_cycle_svc)
	EventBus.services.register(&"day_cycle", day_cycle_svc)

	# PlayerService: directorio fino del jugador activo (RefCounted).
	var player_svc: PlayerService = PlayerService.new()
	EventBus.services.register(&"player", player_svc)

	# CropService: gestiona el estado de los cultivos (arar, plantar, regar, cosechar).
	var crop_svc: CropService = CropService.new()
	crop_svc.connect_signals()
	crop_svc.register_crop(preload("res://data/definition/wheat.tres"))
	crop_svc.register_crop(preload("res://data/definition/beet.tres"))
	crop_svc.register_crop(preload("res://data/definition/lavender.tres"))
	crop_svc.register_crop(preload("res://data/definition/ember_lily.tres"))
	crop_svc.register_crop(preload("res://data/definition/cotton.tres"))
	EventBus.services.register(&"crop", crop_svc)

	# FarmService: gestiona los visuales del sistema de cultivos (Node, necesita árbol).
	var farm_svc: FarmService = FarmService.new()
	farm_svc.name = "FarmService"
	farm_svc.process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.add_child(farm_svc)
	EventBus.services.register(&"farm", farm_svc)

	# TradeService: gestiona inventario del jugador y lógica de compraventa.
	var trade_svc: TradeService = TradeService.new()
	trade_svc.connect_signals()
	EventBus.services.register(&"trade", trade_svc)

	var tribute_svc: TributeService = TributeService.new()
	tribute_svc.connect_signals()
	EventBus.services.register(&"tribute", tribute_svc)

	# CombatService: cálculo centralizado de daño (RefCounted, no necesita árbol).
	var combat_svc: CombatService = CombatService.new()
	EventBus.services.register(&"combat", combat_svc)

	# EnemyCoordinatorService: limita cuántos enemigos atacan a la vez (RefCounted).
	var enemy_coord_svc: EnemyCoordinatorService = EnemyCoordinatorService.new()
	EventBus.services.register(&"enemy_coord", enemy_coord_svc)

	# AuthService: gestiona login/registro con Supabase (Node, necesita árbol).
	var auth_svc: AuthService = AuthService.new()
	auth_svc.name = "AuthService"
	EventBus.add_child(auth_svc)
	EventBus.services.register(&"auth", auth_svc)

	# SupabaseService: sync de guardados a la nube (Node, necesita árbol).
	var supabase_svc: SupabaseService = SupabaseService.new()
	supabase_svc.name = "SupabaseService"
	EventBus.add_child(supabase_svc)
	EventBus.services.register(&"supabase", supabase_svc)

	# SoundService: escucha señales del EventBus y reproduce audio (Node, necesita árbol).
	var sound_svc: SoundService = SoundService.new()
	sound_svc.name = "SoundService"
	EventBus.add_child(sound_svc)
	EventBus.services.register(&"sound", sound_svc)

	# Ir a la pantalla de login
	get_tree().call_deferred("change_scene_to_file", "res://ui/menus/auth_screen.tscn")

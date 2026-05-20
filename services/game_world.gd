class_name GameWorld
extends Control

const MAP_SCENE_PATH: String = "res://entities/test/alex/alex_scene.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://ui/menus/main_menu.tscn"
const ZOMBIE_SCENE_PATH: String = "res://entities/zombie/zombie.tscn"
const ZOMBIE_ARCHER_SCENE_PATH: String = "res://entities/zombie_archer/zombie_archer.tscn"
const BOSS_SCENE_PATH: String = "res://entities/boss/zombie_boss.tscn"
const COLLECTOR_SCENE_PATH: String = "res://entities/collector/collector_zombie.tscn"

const NIGHT_PATROL_MARKERS: Array[String] = [
	"NightZombieSpawnPoint1",
	"NightZombieSpawnPoint2",
	"NightZombieSpawnPoint3",
	"NightZombieSpawnPoint4",
]
const HORDE_MARKERS: Array[String] = [
	"HordeSpawnPoint1",
	"HordeSpawnPoint2",
	"HordeSpawnPoint3",
]

const APOCALYPSE_HORDE_POSITIONS: Array[Vector2] = [
	Vector2(80, 96),
	Vector2(176, 144),
	Vector2(320, 96),
	Vector2(512, 96),
	Vector2(720, 96),
	Vector2(880, 128),
	Vector2(64, 240),
	Vector2(208, 256),
	Vector2(352, 224),
	Vector2(608, 224),
	Vector2(800, 256),
	Vector2(920, 304),
	Vector2(96, 416),
	Vector2(256, 448),
	Vector2(432, 400),
	Vector2(624, 432),
	Vector2(808, 416),
	Vector2(896, 512),
	Vector2(160, 560),
	Vector2(384, 560),
	Vector2(640, 560),
	Vector2(832, 560),
]
const APOCALYPSE_HORDE_MULTIPLIER: int = 5
const APOCALYPSE_HORDE_EXTRA_COUNT: int = 20
const HOUSE_SPAWN_BLOCK_RECT: Rect2 = Rect2(Vector2(384, 16), Vector2(192, 192))

const UI_COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const UI_COLOR_BORDER: Color = Color(0.38, 0.28, 0.20)
const UI_COLOR_TEXT: Color = Color(0.35, 0.25, 0.15)
const UI_FONT_PATH: String = "res://ui/theme/PressStart2P-Regular.ttf"

var active_slot: int = 1
var _trade_open: bool = false
var _saved_player_pos: Vector2 = Vector2.ZERO
var _night_zombies: Array[Node2D] = []
var _sunburn_targets: Array[Node2D] = []
var _sunburn_timer: Timer = null
var _ui_font: Font
var _objective_label: Label
var _objective_text: String = ""
var _mission_popup: PanelContainer
var _mission_popup_label: Label
var _mission_timer: Timer
var _dialogue_layer: CanvasLayer
var _dialogue_panel: PanelContainer
var _dialogue_name_label: Label
var _dialogue_text_label: Label
var _dialogue_ignore_until_msec: int = 0
var _apocalypse_overlay: CanvasLayer
var _end_overlay: CanvasLayer
var _pause_layer: CanvasLayer
var _pause_resume_button: Button
var _day_cycle_was_running_before_pause: bool = false
var _horde_spawned: bool = false
var _final_spawned: bool = false
var _defeat_active: bool = false
var _game_ended: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		active_slot = save_svc.active_slot

	_build_hud()
	_load_slot_state()
	_connect_events()
	_build_world()
	_start_day_cycle()

	var tribute_svc := EventBus.services.tribute as TributeService
	if tribute_svc:
		_on_objective_changed(tribute_svc.get_objective_text())
		call_deferred("_restore_persistent_story_encounters")

	call_deferred("_unlock_new_world")


func _exit_tree() -> void:
	if not _game_ended:
		_save_slot_state()
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		day_cycle_svc.pause()

	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)
	if EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.disconnect(_on_day_phase_changed)
	if EventBus.objective_changed.is_connected(_on_objective_changed):
		EventBus.objective_changed.disconnect(_on_objective_changed)
	if EventBus.dialogue_requested.is_connected(_show_dialogue_message):
		EventBus.dialogue_requested.disconnect(_show_dialogue_message)
	if EventBus.tribute_failed.is_connected(_on_tribute_failed):
		EventBus.tribute_failed.disconnect(_on_tribute_failed)
	if EventBus.final_boss_started.is_connected(_on_final_boss_started):
		EventBus.final_boss_started.disconnect(_on_final_boss_started)
	if EventBus.entity_died.is_connected(_on_entity_died):
		EventBus.entity_died.disconnect(_on_entity_died)
	if EventBus.game_won.is_connected(_on_game_won):
		EventBus.game_won.disconnect(_on_game_won)
	if EventBus.player_spawned.is_connected(_on_player_spawned):
		EventBus.player_spawned.disconnect(_on_player_spawned)


func _connect_events() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.objective_changed.connect(_on_objective_changed)
	EventBus.dialogue_requested.connect(_show_dialogue_message)
	EventBus.tribute_failed.connect(_on_tribute_failed)
	EventBus.final_boss_started.connect(_on_final_boss_started)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.game_won.connect(_on_game_won)
	EventBus.trade_opened.connect(func() -> void: _trade_open = true)
	EventBus.trade_closed.connect(func() -> void: _trade_open = false)
	EventBus.player_spawned.connect(_on_player_spawned)


func _unlock_new_world() -> void:
	var profile_svc: ProfileService = EventBus.services.profile as ProfileService
	if profile_svc:
		profile_svc.unlock_achievement("new_world")


func _load_slot_state() -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc == null:
		return

	var profile_svc: ProfileService = EventBus.services.profile as ProfileService
	if profile_svc:
		profile_svc.load_profile(active_slot)

	var data: Dictionary = save_svc.read_slot_json(active_slot)

	var pos_data = data.get("player_position", null)
	if pos_data is Dictionary:
		var px: float = float(pos_data.get("x", 0.0))
		var py: float = float(pos_data.get("y", 0.0))
		if px != 0.0 or py != 0.0:
			_saved_player_pos = Vector2(px, py)

	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc:
		trade_svc.load_from_save(data)

	var tribute_svc := EventBus.services.tribute as TributeService
	if tribute_svc:
		tribute_svc.apply_save_state(data.get("story_state", {}))

	var crop_svc := EventBus.services.crop as CropService
	if crop_svc:
		crop_svc.apply_save_state({
			"crops": data.get("crops", []),
			"tilled_tiles": data.get("tilled_tiles", []),
		})


func _on_player_spawned(player: Node) -> void:
	if _saved_player_pos != Vector2.ZERO:
		player.global_position = _saved_player_pos
		_saved_player_pos = Vector2.ZERO


func _build_world() -> void:
	var map_scene: PackedScene = load(MAP_SCENE_PATH) as PackedScene
	if map_scene == null:
		push_error("GameWorld: could not load map at %s" % MAP_SCENE_PATH)
		return

	var world: Node2D = map_scene.instantiate() as Node2D
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	var trader: Trader = Trader.new()
	var trader_marker := _get_marker("TraderSpawnPoint")
	if trader_marker:
		trader.position = trader_marker.position
	else:
		trader.position = Vector2(350, 180)
	world.call_deferred("add_child", trader)

	var collector_marker := _get_marker("CollectorSpawnPoint")
	if collector_marker:
		call_deferred("_spawn_scene", COLLECTOR_SCENE_PATH, collector_marker.global_position)


func _build_hud() -> void:
	_ui_font = load(UI_FONT_PATH) as Font

	var hud_scene: PackedScene = load("res://ui/hud/day_cycle_hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)

	var tool_hud_scene: PackedScene = load("res://ui/hud/tool_hud.tscn")
	var tool_hud: CanvasLayer = tool_hud_scene.instantiate()
	tool_hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(tool_hud)

	var health_hud_scene: PackedScene = load("res://ui/hud/health_hud.tscn")
	var health_hud: CanvasLayer = health_hud_scene.instantiate()
	health_hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(health_hud)

	var trade_hud: TradeHUD = TradeHUD.new()
	trade_hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(trade_hud)

	_build_objective_hud()
	_build_dialogue_box()
	_build_pause_menu()

	var achievement_popup := AchievementPopup.new()
	achievement_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(achievement_popup)


func _build_objective_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -120
	panel.offset_top = 92
	panel.offset_right = -8
	panel.offset_bottom = 126
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_mission_panel_gui_input)
	panel.add_theme_stylebox_override("panel", _make_wood_panel_style(8))
	layer.add_child(panel)

	_objective_label = Label.new()
	_objective_label.text = "MISSION  M"
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font:
		_objective_label.add_theme_font_override("font", _ui_font)
	_objective_label.add_theme_font_size_override("font_size", 7)
	_objective_label.add_theme_color_override("font_color", UI_COLOR_TEXT)
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_objective_label)

	_build_mission_popup(layer)


func _build_mission_popup(layer: CanvasLayer) -> void:
	_mission_popup = PanelContainer.new()
	_mission_popup.set_anchors_preset(Control.PRESET_CENTER)
	_mission_popup.custom_minimum_size = Vector2(430, 122)
	_mission_popup.offset_left = -215
	_mission_popup.offset_top = -61
	_mission_popup.offset_right = 215
	_mission_popup.offset_bottom = 61
	_mission_popup.visible = false
	_mission_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_mission_popup.add_theme_stylebox_override("panel", _make_wood_panel_style(14))
	layer.add_child(_mission_popup)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	_mission_popup.add_child(box)

	var title := Label.new()
	title.text = "CURRENT MISSION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_font:
		title.add_theme_font_override("font", _ui_font)
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", UI_COLOR_TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	_mission_popup_label = Label.new()
	_mission_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_popup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mission_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font:
		_mission_popup_label.add_theme_font_override("font", _ui_font)
	_mission_popup_label.add_theme_font_size_override("font_size", 8)
	_mission_popup_label.add_theme_color_override("font_color", UI_COLOR_TEXT)
	_mission_popup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_mission_popup_label)

	_mission_timer = Timer.new()
	_mission_timer.one_shot = true
	_mission_timer.wait_time = 5.0
	_mission_timer.timeout.connect(_hide_mission_popup)
	layer.add_child(_mission_timer)


func _make_wood_panel_style(content_margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UI_COLOR_PARCHMENT
	style.border_color = UI_COLOR_BORDER
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.set_corner_radius_all(0)
	style.set_content_margin_all(content_margin)
	return style


func _build_dialogue_box() -> void:
	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.layer = 120
	_dialogue_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_dialogue_layer)

	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialogue_panel.offset_left = 32
	_dialogue_panel.offset_top = -126
	_dialogue_panel.offset_right = -32
	_dialogue_panel.offset_bottom = -18
	_dialogue_panel.visible = false
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_panel.gui_input.connect(_on_dialogue_gui_input)
	_dialogue_panel.add_theme_stylebox_override("panel", _make_wood_panel_style(14))
	_dialogue_layer.add_child(_dialogue_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_dialogue_panel.add_child(box)

	_dialogue_name_label = Label.new()
	_dialogue_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _ui_font:
		_dialogue_name_label.add_theme_font_override("font", _ui_font)
	_dialogue_name_label.add_theme_font_size_override("font_size", 10)
	_dialogue_name_label.add_theme_color_override("font_color", Color(0.23, 0.15, 0.08))
	_dialogue_name_label.add_theme_constant_override("outline_size", 2)
	_dialogue_name_label.add_theme_color_override("font_outline_color", Color(0.70, 0.62, 0.45))
	_dialogue_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_dialogue_name_label)

	_dialogue_text_label = Label.new()
	_dialogue_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dialogue_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font:
		_dialogue_text_label.add_theme_font_override("font", _ui_font)
	_dialogue_text_label.add_theme_font_size_override("font_size", 8)
	_dialogue_text_label.add_theme_color_override("font_color", UI_COLOR_TEXT)
	_dialogue_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_dialogue_text_label)

	var continue_label := Label.new()
	continue_label.text = "E / ENTER / CLICK"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _ui_font:
		continue_label.add_theme_font_override("font", _ui_font)
	continue_label.add_theme_font_size_override("font_size", 6)
	continue_label.add_theme_color_override("font_color", Color(0.47, 0.34, 0.20))
	continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(continue_label)


func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 135
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.visible = false
	add_child(_pause_layer)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.04, 0.03, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(260, 156)
	panel.offset_left = -130
	panel.offset_top = -78
	panel.offset_right = 130
	panel.offset_bottom = 78
	panel.add_theme_stylebox_override("panel", _make_wood_panel_style(14))
	shade.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_font:
		title.add_theme_font_override("font", _ui_font)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", UI_COLOR_TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	_pause_resume_button = _make_pause_button("RESUME")
	_pause_resume_button.pressed.connect(_close_pause_menu)
	box.add_child(_pause_resume_button)

	var main_menu_button := _make_pause_button("MAIN MENU")
	main_menu_button.pressed.connect(_return_to_main_menu)
	box.add_child(main_menu_button)


func _make_pause_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 34)
	if _ui_font:
		btn.add_theme_font_override("font", _ui_font)
	btn.add_theme_font_size_override("font_size", 8)
	btn.add_theme_color_override("font_color", UI_COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", UI_COLOR_TEXT)
	btn.add_theme_color_override("font_pressed_color", UI_COLOR_TEXT)
	btn.add_theme_color_override("font_focus_color", UI_COLOR_TEXT)

	var style := StyleBoxFlat.new()
	style.bg_color = UI_COLOR_PARCHMENT
	style.border_color = UI_COLOR_BORDER
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 5
	style.set_corner_radius_all(0)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = UI_COLOR_PARCHMENT.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := style.duplicate()
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 4
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _start_day_cycle() -> void:
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	var save_svc: SaveService = EventBus.services.save as SaveService
	if day_cycle_svc and save_svc:
		var data: Dictionary = save_svc.read_slot_json(active_slot)
		day_cycle_svc.apply_save_state({
			"current_day": data.get("day", 1),
			"is_night": data.get("is_night", false),
			"elapsed": data.get("elapsed", 0.0),
			"running": true,
		})


func _on_day_started(day_number: int) -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc:
		save_svc.save_day(active_slot, day_number)
	_night_zombies.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_slot_state()


func _save_slot_state() -> void:
	var save_svc: SaveService = EventBus.services.save as SaveService
	if save_svc == null or active_slot <= 0:
		return
	var day_cycle_svc := EventBus.services.day_cycle as DayCycleService
	var current_day: int = day_cycle_svc.current_day if day_cycle_svc else 1
	save_svc.save_day(active_slot, current_day)


func _on_day_phase_changed(is_night: bool) -> void:
	if not is_night:
		var survivors := get_tree().get_nodes_in_group("zombies")
		for z in survivors:
			_sunburn_targets.append(z as Node2D)
		if not _sunburn_targets.is_empty():
			_start_sunburn_tick()
		return

	var tribute_svc := EventBus.services.tribute as TributeService
	if tribute_svc and (not tribute_svc.starter_pack_claimed or tribute_svc.horde_started or tribute_svc.final_started):
		return

	_spawn_night_patrol()


func _on_objective_changed(text: String) -> void:
	_objective_text = text


func _on_mission_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_mission_popup()


func _toggle_mission_popup() -> void:
	if _mission_popup == null:
		return
	if _mission_popup.visible:
		_hide_mission_popup()
	else:
		_show_mission_popup()


func _show_mission_popup() -> void:
	if _mission_popup == null or _mission_popup_label == null:
		return

	if _objective_text.is_empty():
		_mission_popup_label.text = "No active mission."
	else:
		_mission_popup_label.text = _objective_text

	_mission_popup.visible = true
	if _mission_timer:
		_mission_timer.start()


func _hide_mission_popup() -> void:
	if _mission_timer:
		_mission_timer.stop()
	if _mission_popup:
		_mission_popup.visible = false


func _on_tribute_failed(message: String) -> void:
	if _horde_spawned:
		return
	_horde_spawned = true
	_force_night()
	_pause_day_cycle()
	_clear_night_zombies(true)
	_play_apocalypse_intro(message)
	_spawn_apocalypse_horde()


func _on_final_boss_started(message: String) -> void:
	if _final_spawned:
		return
	_final_spawned = true
	_force_night()
	_pause_day_cycle()
	_clear_night_zombies(true)
	_show_story_message(message)

	var boss_marker := _get_marker("BossSpawnPoint")
	if boss_marker:
		_spawn_enemy(BOSS_SCENE_PATH, boss_marker.global_position)
	_spawn_zombie_pack(NIGHT_PATROL_MARKERS, 8, 18.0)


func _restore_persistent_story_encounters() -> void:
	var tribute_svc := EventBus.services.tribute as TributeService
	if tribute_svc == null:
		return

	if tribute_svc.horde_started:
		_horde_spawned = true
		_force_night()
		_pause_day_cycle()
		_clear_night_zombies(true)
		_spawn_apocalypse_horde()
		_show_dialogue_message("Collector", "The debt is already written. The march does not stop because you close your eyes.", true)
	elif tribute_svc.final_started:
		_final_spawned = true
		_force_night()
		_pause_day_cycle()
		_clear_night_zombies(true)
		var boss_marker := _get_marker("BossSpawnPoint")
		if boss_marker and get_tree().get_nodes_in_group("bosses").is_empty():
			_spawn_enemy(BOSS_SCENE_PATH, boss_marker.global_position)
		_spawn_zombie_pack(NIGHT_PATROL_MARKERS, 8, 18.0)


func _on_game_won(message: String) -> void:
	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		day_cycle_svc.pause()

	for zombie in get_tree().get_nodes_in_group("zombies"):
		if is_instance_valid(zombie) and not (zombie is ZombieBoss):
			zombie.queue_free()

	_finish_active_run()
	_show_victory_overlay(message)
	call_deferred("_freeze_terminal_game_state")


func _on_entity_died(entity: Node) -> void:
	if not (entity is Player):
		return

	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		day_cycle_svc.pause()

	var movement := entity.get_node_or_null("MovementComponent") as MovementComponent
	if movement:
		movement.stop()
		movement.input_enabled = false

	_finish_active_run()
	_show_defeat_overlay("The march has devoured the farm.")
	call_deferred("_freeze_terminal_game_state")


func _spawn_night_patrol() -> void:
	if not _night_zombies.is_empty():
		return
	_night_zombies = _spawn_zombie_pack(NIGHT_PATROL_MARKERS, 10, 14.0)
	for i in range(4):
		var marker_name: String = NIGHT_PATROL_MARKERS[i % NIGHT_PATROL_MARKERS.size()]
		var marker := _get_marker(marker_name)
		if marker == null:
			continue
		var offset := Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		var archer := _spawn_enemy(ZOMBIE_ARCHER_SCENE_PATH, marker.global_position + offset)
		if archer:
			_night_zombies.append(archer)


func _spawn_zombie_pack(marker_names: Array[String], count: int, jitter: float) -> Array[Node2D]:
	var spawned: Array[Node2D] = []
	if marker_names.is_empty():
		return spawned

	for i in range(count):
		var marker_name: String = marker_names[i % marker_names.size()]
		var marker := _get_marker(marker_name)
		if marker == null:
			continue
		var offset := Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
		var zombie := _spawn_enemy(ZOMBIE_SCENE_PATH, marker.global_position + offset)
		if zombie:
			spawned.append(zombie)

	return spawned


func _spawn_apocalypse_horde() -> void:
	var existing_horde: Array[Node] = get_tree().get_nodes_in_group("apocalypse_horde")
	var target_count: int = APOCALYPSE_HORDE_POSITIONS.size() * APOCALYPSE_HORDE_MULTIPLIER + APOCALYPSE_HORDE_EXTRA_COUNT
	if existing_horde.size() >= target_count:
		return

	for i in range(existing_horde.size(), target_count):
		var base_pos: Vector2 = APOCALYPSE_HORDE_POSITIONS[i % APOCALYPSE_HORDE_POSITIONS.size()]
		var wave: int = i / APOCALYPSE_HORDE_POSITIONS.size()
		var spread: float = 22.0 + float(wave) * 10.0
		var offset := Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		var spawn_pos := _sanitize_apocalypse_spawn_position(base_pos + offset)
		var zombie := _spawn_enemy(ZOMBIE_SCENE_PATH, spawn_pos)
		if zombie:
			zombie.add_to_group("apocalypse_horde")
			_empower_apocalypse_zombie(zombie)
			_night_zombies.append(zombie)


func _empower_apocalypse_zombie(zombie: Node2D) -> void:
	var ai := zombie.get_node_or_null("ZombieAIComponent")
	if ai and ai.has_method("force_apocalypse_hunt"):
		ai.force_apocalypse_hunt()
	var attack := zombie.get_node_or_null("ZombieAttackComponent")
	if attack and attack.has_method("force_apocalypse_lethality"):
		attack.force_apocalypse_lethality()


func _sanitize_apocalypse_spawn_position(pos: Vector2) -> Vector2:
	if not HOUSE_SPAWN_BLOCK_RECT.has_point(pos):
		return pos
	return Vector2(
		clamp(pos.x, HOUSE_SPAWN_BLOCK_RECT.position.x - 28.0, HOUSE_SPAWN_BLOCK_RECT.end.x + 28.0),
		HOUSE_SPAWN_BLOCK_RECT.end.y + randf_range(24.0, 64.0)
	)


func _clear_night_zombies(instant: bool = false) -> void:
	if instant:
		if is_instance_valid(_sunburn_timer):
			_sunburn_timer.stop()
		for z in _sunburn_targets:
			if is_instance_valid(z):
				z.queue_free()
		_sunburn_targets.clear()
		for zombie in _night_zombies:
			if is_instance_valid(zombie):
				zombie.queue_free()
		_night_zombies.clear()
		return

	# Natural dawn: apply sunburn instead of instant removal.
	if _night_zombies.is_empty():
		return
	for zombie in _night_zombies:
		if is_instance_valid(zombie):
			_sunburn_targets.append(zombie)
	_night_zombies.clear()
	_start_sunburn_tick()


func _start_sunburn_tick() -> void:
	if _sunburn_targets.is_empty():
		return
	if not is_instance_valid(_sunburn_timer):
		_sunburn_timer = Timer.new()
		_sunburn_timer.wait_time = 1.0
		_sunburn_timer.timeout.connect(_on_sunburn_tick)
		add_child(_sunburn_timer)
	_sunburn_timer.start()


func _on_sunburn_tick() -> void:
	var still_alive: Array[Node2D] = []
	for zombie in _sunburn_targets:
		if not is_instance_valid(zombie):
			continue
		var health := zombie.get_node_or_null("HealthComponent") as HealthComponent
		if health == null or health.current_health <= 0.0:
			continue
		health.take_damage(20.0)
		if health.current_health > 0.0:
			still_alive.append(zombie)
	_sunburn_targets = still_alive
	if _sunburn_targets.is_empty():
		_sunburn_timer.stop()


func _force_night() -> void:
	var day_cycle_svc := EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc == null or day_cycle_svc.is_night:
		return
	day_cycle_svc.is_night = true
	day_cycle_svc.elapsed = 0.0
	EventBus.day_phase_changed.emit(true)
	EventBus.time_tick.emit(day_cycle_svc.current_day, 0.0, "NIGHT")


func _pause_day_cycle() -> void:
	var day_cycle_svc := EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		day_cycle_svc.pause()


func _debug_advance_day_or_due_night() -> void:
	var day_cycle_svc := EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc == null:
		return

	var tribute_svc := EventBus.services.tribute as TributeService
	if tribute_svc and (tribute_svc.horde_started or tribute_svc.final_started):
		return
	if not day_cycle_svc.is_night and tribute_svc and tribute_svc.is_tribute_due_on_day(day_cycle_svc.current_day):
		_force_night()
	else:
		day_cycle_svc.start_cycle(day_cycle_svc.current_day + 1)
	_save_slot_state()


func _debug_jump_to_next_tribute_night() -> void:
	var day_cycle_svc := EventBus.services.day_cycle as DayCycleService
	var tribute_svc := EventBus.services.tribute as TributeService
	if day_cycle_svc == null or tribute_svc == null:
		return

	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc and not trade_svc.starter_pack_granted:
		trade_svc.grant_starter_pack()
		EventBus.starter_pack_received.emit()

	var tribute := tribute_svc.get_current_tribute()
	if tribute.is_empty():
		return

	var due_day: int = int(tribute["due_day"])
	day_cycle_svc.current_day = max(day_cycle_svc.current_day, due_day)
	day_cycle_svc.is_night = false
	day_cycle_svc.elapsed = 0.0
	day_cycle_svc.running = true
	_force_night()
	if not tribute_svc.horde_started and not tribute_svc.final_started:
		tribute_svc.debug_trigger_current_due_event()
	_pause_day_cycle()
	_save_slot_state()


func _show_story_message(message: String) -> void:
	_show_dialogue_message("The March", message)


func _show_dialogue_message(speaker: String, message: String, centered: bool = false) -> void:
	if _dialogue_panel == null or _dialogue_name_label == null or _dialogue_text_label == null:
		return
	if centered:
		_position_dialogue_center()
	else:
		_position_dialogue_bottom()
	_dialogue_name_label.text = speaker.to_upper()
	_dialogue_text_label.text = message
	_dialogue_panel.visible = true
	EventBus.dialogue_open = true
	_dialogue_ignore_until_msec = Time.get_ticks_msec() + 180


func _position_dialogue_bottom() -> void:
	_dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialogue_panel.offset_left = 32
	_dialogue_panel.offset_top = -126
	_dialogue_panel.offset_right = -32
	_dialogue_panel.offset_bottom = -18


func _position_dialogue_center() -> void:
	_dialogue_panel.set_anchors_preset(Control.PRESET_CENTER)
	_dialogue_panel.offset_left = -280
	_dialogue_panel.offset_top = -76
	_dialogue_panel.offset_right = 280
	_dialogue_panel.offset_bottom = 76


func _hide_dialogue_message() -> void:
	if _dialogue_panel:
		_dialogue_panel.visible = false
	EventBus.dialogue_open = false


func _open_pause_menu() -> void:
	if _pause_layer == null or _pause_layer.visible:
		return
	var day_cycle_svc := EventBus.services.day_cycle as DayCycleService
	_day_cycle_was_running_before_pause = day_cycle_svc != null and day_cycle_svc.running
	if day_cycle_svc:
		day_cycle_svc.pause()
	var sound_svc := EventBus.services.sound as SoundService
	if sound_svc:
		sound_svc.pause_audio()
	_save_slot_state()
	_pause_layer.visible = true
	get_tree().paused = true
	if _pause_resume_button:
		_pause_resume_button.grab_focus()


func _close_pause_menu() -> void:
	if _pause_layer == null:
		return
	_pause_layer.visible = false
	get_tree().paused = false
	var day_cycle_svc := EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc and _day_cycle_was_running_before_pause:
		day_cycle_svc.resume()
	_day_cycle_was_running_before_pause = false
	var sound_svc := EventBus.services.sound as SoundService
	if sound_svc:
		sound_svc.resume_audio()


func _return_to_main_menu() -> void:
	if not _game_ended:
		_save_slot_state()
	var sound_svc := EventBus.services.sound as SoundService
	if sound_svc:
		sound_svc.resume_audio()
		if _game_ended:
			sound_svc.stop_music()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _finish_active_run() -> void:
	if _game_ended:
		return
	_game_ended = true
	_trade_open = false
	EventBus.dialogue_open = false
	_hide_mission_popup()

	var save_svc := EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		save_svc.delete_slot(save_svc.active_slot)
		save_svc.active_slot = -1

	var sound_svc := EventBus.services.sound as SoundService
	if sound_svc:
		sound_svc.pause_audio()


func _has_blocking_screen_open() -> bool:
	if _trade_open:
		return true
	if _dialogue_panel and _dialogue_panel.visible:
		return true
	if _mission_popup and _mission_popup.visible:
		return true
	if _apocalypse_overlay and is_instance_valid(_apocalypse_overlay):
		return true
	if _end_overlay and is_instance_valid(_end_overlay):
		return true
	for child in get_tree().root.get_children():
		if child.name == "SleepOverlay" and child is CanvasLayer and child.visible:
			return true
	return false


func _on_dialogue_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hide_dialogue_message()


func _play_apocalypse_intro(message: String) -> void:
	_show_apocalypse_flash()
	_shake_world()
	_show_dialogue_message("Collector", message, true)


func _show_apocalypse_flash() -> void:
	if _apocalypse_overlay and is_instance_valid(_apocalypse_overlay):
		_apocalypse_overlay.queue_free()

	_apocalypse_overlay = CanvasLayer.new()
	_apocalypse_overlay.layer = 110
	_apocalypse_overlay.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_apocalypse_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.0, 0.0, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apocalypse_overlay.add_child(shade)

	var tween := create_tween()
	tween.tween_property(shade, "color", Color(0.12, 0.0, 0.0, 0.82), 0.45)
	tween.tween_interval(0.25)
	tween.tween_property(shade, "color", Color(0.05, 0.0, 0.0, 0.22), 1.15)
	tween.tween_callback(func() -> void:
		if _apocalypse_overlay and is_instance_valid(_apocalypse_overlay):
			_apocalypse_overlay.queue_free()
	)


func _shake_world(duration: float = 1.6, strength: float = 8.0) -> void:
	var world_node := _get_world_node() as Node2D
	if world_node == null:
		return

	var original_position := world_node.position
	var tween := create_tween()
	var steps := 14
	for i in range(steps):
		var factor := 1.0 - (float(i) / float(steps))
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) * factor
		tween.tween_property(world_node, "position", original_position + offset, duration / float(steps))
	tween.tween_property(world_node, "position", original_position, 0.08)


func _show_victory_overlay(message: String) -> void:
	_show_end_overlay("VICTORY", message, Color(0.28, 0.48, 0.12), true)


func _show_defeat_overlay(message: String) -> void:
	_defeat_active = true
	_show_end_overlay("DEFEAT", message, Color(0.52, 0.12, 0.08), true)


func _show_end_overlay(title_text: String, message: String, title_color: Color, instant: bool = false) -> void:
	var overlay := CanvasLayer.new()
	_end_overlay = overlay
	overlay.layer = 150
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.04, 0.03, 0.72)
	shade.modulate.a = 1.0 if instant else 0.0
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 178)
	panel.offset_left = -210
	panel.offset_top = -89
	panel.offset_right = 210
	panel.offset_bottom = 89
	panel.modulate.a = 1.0 if instant else 0.0
	panel.add_theme_stylebox_override("panel", _make_wood_panel_style(18))
	shade.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _ui_font:
		title.add_theme_font_override("font", _ui_font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.70, 0.62, 0.45))
	box.add_child(title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = UI_COLOR_BORDER
	sep_style.content_margin_top = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	box.add_child(sep)

	var body := Label.new()
	body.text = message
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _ui_font:
		body.add_theme_font_override("font", _ui_font)
	body.add_theme_font_size_override("font_size", 7)
	body.add_theme_color_override("font_color", UI_COLOR_TEXT)
	box.add_child(body)

	var button := _make_end_button("BACK TO MENU")
	button.pressed.connect(_return_to_main_menu)
	box.add_child(button)
	button.grab_focus()

	if instant:
		return

	var tween := create_tween()
	tween.tween_property(shade, "modulate:a", 1.0, 0.7)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.7)
	tween.parallel().tween_property(panel, "scale", Vector2(1.04, 1.04), 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18)


func _make_end_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 34)
	if _ui_font:
		btn.add_theme_font_override("font", _ui_font)
	btn.add_theme_font_size_override("font_size", 7)
	btn.add_theme_color_override("font_color", UI_COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", UI_COLOR_TEXT)
	btn.add_theme_color_override("font_pressed_color", UI_COLOR_TEXT)
	btn.add_theme_color_override("font_focus_color", UI_COLOR_TEXT)

	var style := StyleBoxFlat.new()
	style.bg_color = UI_COLOR_PARCHMENT
	style.border_color = UI_COLOR_BORDER
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 5
	style.set_corner_radius_all(0)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = UI_COLOR_PARCHMENT.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := style.duplicate()
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 4
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _freeze_terminal_game_state() -> void:
	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if _defeat_active:
		return

	if _end_overlay and is_instance_valid(_end_overlay):
		return

	if _pause_layer and _pause_layer.visible:
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_close_pause_menu()
		return

	if _dialogue_panel and _dialogue_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if Time.get_ticks_msec() >= _dialogue_ignore_until_msec and event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
				get_viewport().set_input_as_handled()
				_hide_dialogue_message()
				return
			if event.is_action_pressed("pause"):
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			_hide_dialogue_message()
			return

	if _trade_open:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _has_blocking_screen_open():
			return
		_open_pause_menu()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:
				get_viewport().set_input_as_handled()
				_toggle_mission_popup()
			KEY_P:
				_debug_advance_day_or_due_night()
			KEY_H:
				_debug_jump_to_next_tribute_night()
			KEY_N:
				_force_night()
			KEY_O:
				var crop_svc := EventBus.services.crop as CropService
				if crop_svc:
					crop_svc.water_all()
			KEY_K:
				var player_svc := EventBus.services.player as PlayerService
				if player_svc and player_svc.has_player():
					var player: Node = player_svc.get_active_player()
					var health := player.get_node_or_null("HealthComponent") as HealthComponent
					if health:
						health.take_damage(15.0)
			KEY_L:
				var player_svc := EventBus.services.player as PlayerService
				if player_svc and player_svc.has_player():
					var player: Node = player_svc.get_active_player()
					var health := player.get_node_or_null("HealthComponent") as HealthComponent
					if health:
						health.heal(20.0)
			KEY_Z:
				get_viewport().set_input_as_handled()
				var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
				_spawn_enemy(ZOMBIE_SCENE_PATH, canvas_xform.affine_inverse() * get_viewport().get_mouse_position())
			KEY_B:
				get_viewport().set_input_as_handled()
				var boss_canvas_xform: Transform2D = get_viewport().get_canvas_transform()
				_spawn_enemy(BOSS_SCENE_PATH, boss_canvas_xform.affine_inverse() * get_viewport().get_mouse_position())
			KEY_F:
				get_viewport().set_input_as_handled()
				_debug_skip_to_final_boss()
			KEY_R:
				get_viewport().set_input_as_handled()
				var archer_xform: Transform2D = get_viewport().get_canvas_transform()
				_spawn_enemy(ZOMBIE_ARCHER_SCENE_PATH, archer_xform.affine_inverse() * get_viewport().get_mouse_position())
			KEY_QUOTELEFT: # ` — unlock all achievements for testing
				get_viewport().set_input_as_handled()
				_debug_unlock_all_achievements()


func _debug_unlock_all_achievements() -> void:
	var profile_svc := EventBus.services.profile as ProfileService
	if not profile_svc:
		return
	var ids: Array[String] = [
		"new_world", "first_water", "first_plant", "first_harvest", "green_thumb",
		"survive_night", "survive_7", "survive_30", "trader_deal", "rich_farmer",
		"first_tribute", "all_tributes", "first_kill", "zombie_slayer",
		"boss_defeated", "full_armor",
	]
	for id in ids:
		profile_svc.unlock_achievement(id)


func _debug_skip_to_final_boss() -> void:
	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc and not trade_svc.starter_pack_granted:
		trade_svc.grant_starter_pack()

	if _final_spawned:
		return
	_final_spawned = true
	_force_night()
	_pause_day_cycle()
	_clear_night_zombies(true)
	_show_story_message("The final moment has come.\nEnd the patriarch of the horde!")

	var boss_marker := _get_marker("BossSpawnPoint")
	if boss_marker:
		_spawn_enemy(BOSS_SCENE_PATH, boss_marker.global_position)
	_spawn_zombie_pack(NIGHT_PATROL_MARKERS, 8, 18.0)


func _get_marker(marker_name: String) -> Marker2D:
	var world_node := _get_world_node()
	if world_node == null:
		return null
	return world_node.get_node_or_null("SpawnPoints/%s" % marker_name) as Marker2D


func _get_world_node() -> Node:
	if get_child_count() == 0:
		return null
	return get_child(0)


func _spawn_enemy(scene_path: String, spawn_position: Vector2) -> Node2D:
	return _spawn_scene(scene_path, spawn_position)


func _spawn_scene(scene_path: String, spawn_position: Vector2) -> Node2D:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("GameWorld: could not load %s" % scene_path)
		return null

	var node: Node2D = packed.instantiate() as Node2D
	if node == null:
		push_error("GameWorld: instantiate() for %s returned null" % scene_path)
		return null

	var world_node := _get_world_node()
	if world_node == null:
		push_error("GameWorld: no world node found")
		return null

	world_node.add_child(node)
	node.global_position = spawn_position
	return node

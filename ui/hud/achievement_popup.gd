## Notificación en la esquina inferior-izquierda al desbloquear un logro.
## Se instancia en game_world._build_hud(); escucha EventBus.achievement_unlocked.
## Encola múltiples logros y los muestra uno a uno con animación de deslizamiento.
## También conecta todas las señales de juego para disparar los logros (Node → conexiones fiables).
class_name AchievementPopup
extends CanvasLayer

const UI_FONT_PATH: String = "res://ui/theme/PressStart2P-Regular.ttf"
const COLOR_PARCHMENT: Color = Color(0.82, 0.76, 0.63)
const COLOR_BORDER_GOLD: Color = Color(0.85, 0.68, 0.20)
const COLOR_TEXT: Color = Color(0.35, 0.25, 0.15)
const COLOR_GOLD: Color = Color(0.85, 0.65, 0.10)
const COLOR_DESC: Color = Color(0.50, 0.38, 0.25)

const PANEL_WIDTH: float = 260.0
const PANEL_HEIGHT: float = 84.0
const MARGIN: float = 8.0
const DISPLAY_DURATION: float = 3.5
const ANIM_DURATION: float = 0.3

var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _font: Font
var _tween: Tween
var _queue: Array[Dictionary] = []
var _showing: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(UI_FONT_PATH) as Font
	_build_ui()
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)

	# Achievement triggers — connected here (Node) for reliable persistence across scenes
	EventBus.crop_watered.connect(_on_crop_watered)
	EventBus.crop_planted.connect(_on_crop_planted)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.day_started.connect(_on_day_started)
	EventBus.zombie_died.connect(_on_zombie_died)
	EventBus.game_won.connect(_on_game_won)
	EventBus.tribute_paid.connect(_on_tribute_paid)
	EventBus.seeds_purchased.connect(_on_seeds_purchased)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.position = Vector2(MARGIN, 2000.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PARCHMENT
	style.border_color = COLOR_BORDER_GOLD
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.set_corner_radius_all(0)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header_row)

	var star := Label.new()
	star.text = "★"
	if _font:
		star.add_theme_font_override("font", _font)
	star.add_theme_font_size_override("font_size", 10)
	star.add_theme_color_override("font_color", COLOR_GOLD)
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(star)

	var header := Label.new()
	header.text = "ACHIEVEMENT!"
	if _font:
		header.add_theme_font_override("font", _font)
	header.add_theme_font_size_override("font_size", 7)
	header.add_theme_color_override("font_color", COLOR_GOLD)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(header)

	_title_label = Label.new()
	_title_label.text = ""
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font:
		_title_label.add_theme_font_override("font", _font)
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font:
		_desc_label.add_theme_font_override("font", _font)
	_desc_label.add_theme_font_size_override("font_size", 6)
	_desc_label.add_theme_color_override("font_color", COLOR_DESC)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_desc_label)


# ── Achievement triggers ──────────────────────────────────────────────────────

func _profile() -> ProfileService:
	return EventBus.services.profile as ProfileService


func _on_crop_watered(_tile_pos: Vector2i) -> void:
	var p := _profile()
	if p:
		p.unlock_achievement("first_water")


func _on_crop_planted(_tile_pos: Vector2i, _crop_type: int) -> void:
	var p := _profile()
	if p:
		p.unlock_achievement("first_plant")


func _on_crop_harvested(_tile_pos: Vector2i, _crop_type: int) -> void:
	var p := _profile()
	if not p:
		return
	p.unlock_achievement("first_harvest")
	if p.increment_stat("harvest_count") >= 10:
		p.unlock_achievement("green_thumb")


func _on_inventory_updated(slots: Array, coins: int) -> void:
	var p := _profile()
	if not p:
		return
	if coins >= 100:
		p.unlock_achievement("rich_farmer")
	if slots.size() > 18 and slots[16] != null and slots[17] != null and slots[18] != null:
		p.unlock_achievement("full_armor")


func _on_day_started(day_number: int) -> void:
	var p := _profile()
	if not p:
		return
	if day_number == 2:
		p.unlock_achievement("survive_night")
	if day_number == 7:
		p.unlock_achievement("survive_7")
	if day_number == 30:
		p.unlock_achievement("survive_30")


func _on_zombie_died(_zombie) -> void:
	var p := _profile()
	if not p:
		return
	p.unlock_achievement("first_kill")
	if p.increment_stat("zombie_kill_count") >= 10:
		p.unlock_achievement("zombie_slayer")


func _on_game_won(_msg) -> void:
	var p := _profile()
	if p:
		p.unlock_achievement("boss_defeated")


func _on_tribute_paid(index: int) -> void:
	var p := _profile()
	if not p:
		return
	if index == 0:
		p.unlock_achievement("first_tribute")
	if index == 2:
		p.unlock_achievement("all_tributes")


func _on_seeds_purchased(_crop_type) -> void:
	var p := _profile()
	if p:
		p.unlock_achievement("trader_deal")


# ── Display ───────────────────────────────────────────────────────────────────

func _on_achievement_unlocked(achievement_id: String) -> void:
	var profile_svc: ProfileService = EventBus.services.profile as ProfileService
	if not profile_svc:
		return
	var achievements := profile_svc.get_achievements()
	if not achievements.has(achievement_id):
		return
	var data: Dictionary = achievements[achievement_id]
	_queue.append({
		"title": data.get("title", achievement_id),
		"description": data.get("description", ""),
	})
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var entry: Dictionary = _queue.pop_front()
	_title_label.text = entry["title"].to_upper()
	_desc_label.text = entry["description"]

	if _tween and _tween.is_running():
		_tween.kill()

	var viewport_h: float = get_viewport().get_visible_rect().size.y
	var visible_y: float = viewport_h - PANEL_HEIGHT - MARGIN
	var hidden_y: float = viewport_h + MARGIN

	_panel.position = Vector2(MARGIN, hidden_y)

	_tween = create_tween()
	_tween.tween_property(_panel, "position:y", visible_y, ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(DISPLAY_DURATION)
	_tween.tween_property(_panel, "position:y", hidden_y, ANIM_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_show_next)

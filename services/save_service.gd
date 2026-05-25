## Servicio de Guardado de slot de partida. Gestiona los metadatos de los 5 slots de guardado.
class_name SaveService
extends RefCounted

const MAX_SLOTS: int = 5
const LOCAL_SAVE_DIR: String = "user://saves/local/"
const CLOUD_SAVE_DIR: String = "user://saves/cloud/"

## Slot activo actual. Establecido por slots_screen.gd al pulsar PLAY.
var active_slot: int = -1

## true = usa partidas de la cuenta online; false = partidas locales.
var online_mode: bool = false


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(LOCAL_SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(CLOUD_SAVE_DIR)
	_migrate_legacy_saves()


func _get_slot_path(slot: int) -> String:
	var dir: String = CLOUD_SAVE_DIR if online_mode else LOCAL_SAVE_DIR
	return dir + "slot_%d.json" % slot


func _migrate_legacy_saves() -> void:
	for i: int in range(1, MAX_SLOTS + 1):
		var old_path: String = "user://saves/slot_%d.json" % i
		var new_path: String = LOCAL_SAVE_DIR + "slot_%d.json" % i
		if FileAccess.file_exists(old_path) and not FileAccess.file_exists(new_path):
			var file_r: FileAccess = FileAccess.open(old_path, FileAccess.READ)
			if file_r:
				var content: String = file_r.get_as_text()
				file_r.close()
				var file_w: FileAccess = FileAccess.open(new_path, FileAccess.WRITE)
				if file_w:
					file_w.store_string(content)
					file_w.close()
			DirAccess.remove_absolute(old_path)


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot))


func get_slot_info(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {"exists": false, "slot": slot}
	var file: FileAccess = FileAccess.open(_get_slot_path(slot), FileAccess.READ)
	if not file:
		return {"exists": false, "slot": slot}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {"exists": false, "slot": slot}
	file.close()
	var data: Dictionary = json.data
	return {
		"exists": true,
		"slot": slot,
		"nickname": data.get("nickname", "???"),
		"day": data.get("day", 1),
		"timestamp": data.get("timestamp", 0),
		"date_string": data.get("date_string", ""),
	}


func get_all_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i: int in range(1, MAX_SLOTS + 1):
		slots.append(get_slot_info(i))
	return slots


static func generate_uuid_v4() -> String:
	var h: String = "0123456789abcdef"
	var r: String = ""
	for i: int in range(32):
		var n: int
		if i == 12:
			n = 4
		elif i == 16:
			n = (randi() & 0x3) | 0x8
		else:
			n = randi() & 0xF
		r += h[n]
	return "%s-%s-%s-%s-%s" % [r.substr(0, 8), r.substr(8, 4), r.substr(12, 4), r.substr(16, 4), r.substr(20, 12)]


func ensure_player_uuid(slot: int) -> String:
	if not slot_exists(slot):
		return ""
	var path: String = _get_slot_path(slot)
	var file_r: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file_r:
		return ""
	var json: JSON = JSON.new()
	if json.parse(file_r.get_as_text()) != OK:
		file_r.close()
		return ""
	var data: Dictionary = json.data
	file_r.close()
	var existing: String = data.get("player_uuid", "")
	if existing != "":
		return existing
	var new_uuid: String = generate_uuid_v4()
	data["player_uuid"] = new_uuid
	var file_w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file_w:
		file_w.store_string(JSON.stringify(data, "\t"))
		file_w.close()
	return new_uuid


func create_new_game(slot: int, nickname: String) -> void:
	var data: Dictionary = {
		"nickname": nickname,
		"player_uuid": generate_uuid_v4(),
		"day": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"date_string": Time.get_datetime_string_from_system(),
		"player_hp": 100,
		"player_position": {"x": 0, "y": 0},
		"elapsed": 0.0,
		"is_night": false,
		"coins": 0,
		"active_hotbar_index": 0,
		"starter_pack_granted": false,
		"inventory": [],
		"crops": [],
		"story_state": {
			"starter_pack_granted": false,
			"current_tribute_index": 0,
			"horde_started": false,
			"final_started": false,
		},
	}
	var file: FileAccess = FileAccess.open(_get_slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	sync_to_cloud(slot)


func update_nickname(slot: int, new_nickname: String) -> void:
	if not slot_exists(slot): return
	var path: String = _get_slot_path(slot)
	var file_r: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file_r: return
	var json: JSON = JSON.new()
	if json.parse(file_r.get_as_text()) == OK:
		var data: Dictionary = json.data
		file_r.close()
		data["nickname"] = new_nickname
		var file_w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file_w:
			file_w.store_string(JSON.stringify(data, "\t"))
			file_w.close()
	else:
		file_r.close()


func delete_slot(slot: int) -> void:
	var path: String = _get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var supabase: SupabaseService = EventBus.services.supabase as SupabaseService
	var auth: AuthService = EventBus.services.auth as AuthService
	if supabase and auth and auth.is_authenticated():
		supabase.delete_save(slot)


func get_first_free_slot() -> int:
	for i: int in range(1, MAX_SLOTS + 1):
		if not slot_exists(i):
			return i
	return -1


## Guardado principal: escribe todo el estado del juego en un único JSON plano.
func save_day(slot: int, day: int) -> void:
	if not slot_exists(slot): return
	var path: String = _get_slot_path(slot)
	var file_r: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file_r: return
	var json: JSON = JSON.new()
	if json.parse(file_r.get_as_text()) != OK:
		file_r.close()
		return
	var data: Dictionary = json.data
	file_r.close()

	data["day"] = day
	data["timestamp"] = Time.get_unix_time_from_system()
	data["date_string"] = Time.get_datetime_string_from_system()

	var day_cycle_svc: DayCycleService = EventBus.services.day_cycle as DayCycleService
	if day_cycle_svc:
		data["elapsed"] = day_cycle_svc.elapsed
		data["is_night"] = day_cycle_svc.is_night

	var player_svc: PlayerService = EventBus.services.player as PlayerService
	if player_svc and player_svc.has_player():
		var pos: Vector2 = player_svc.get_position()
		data["player_position"] = {"x": pos.x, "y": pos.y}

	var crop_svc: CropService = EventBus.services.crop as CropService
	if crop_svc:
		var crop_state: Dictionary = crop_svc.get_save_state()
		data["crops"] = crop_state.get("crops", [])
		data["tilled_tiles"] = crop_state.get("tilled_tiles", [])

	var trade_svc: TradeService = EventBus.services.trade as TradeService
	if trade_svc:
		var trade_data: Dictionary = trade_svc.get_save_data()
		data["coins"] = trade_data.get("coins", 0)
		data["inventory"] = trade_data.get("inventory", [])
		data["active_hotbar_index"] = trade_data.get("active_hotbar_index", 0)
		data["starter_pack_granted"] = trade_data.get("starter_pack_granted", false)

	var tribute_svc: TributeService = EventBus.services.tribute as TributeService
	if tribute_svc:
		data["story_state"] = tribute_svc.get_save_state()

	var file_w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file_w:
		file_w.store_string(JSON.stringify(data, "\t"))
		file_w.close()
	sync_to_cloud(slot)


func get_day(slot: int) -> int:
	var info: Dictionary = get_slot_info(slot)
	if not info.get("exists", false):
		return 1
	return info.get("day", 1)


## Guarda solo la posición del jugador (patch ligero, sin reescribir todo el estado).
func save_player_position(slot: int, pos: Vector2) -> void:
	if not slot_exists(slot): return
	var path: String = _get_slot_path(slot)
	var file_r: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file_r: return
	var json: JSON = JSON.new()
	if json.parse(file_r.get_as_text()) != OK:
		file_r.close()
		return
	var data: Dictionary = json.data
	file_r.close()
	data["player_position"] = {"x": pos.x, "y": pos.y}
	var file_w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file_w:
		file_w.store_string(JSON.stringify(data, "\t"))
		file_w.close()


# ── Métodos de guardado parcial (llamados desde los servicios al mutar estado) ──
# Todos escriben claves planas en el mismo JSON, sin estructuras anidadas de estado.

func save_crop_state(slot: int, crop_state: Dictionary) -> void:
	if not slot_exists(slot): return
	var path: String = _get_slot_path(slot)
	var file_r: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file_r: return
	var json: JSON = JSON.new()
	if json.parse(file_r.get_as_text()) != OK:
		file_r.close()
		return
	var data: Dictionary = json.data
	file_r.close()
	data["crops"] = crop_state.get("crops", [])
	data["tilled_tiles"] = crop_state.get("tilled_tiles", [])
	var file_w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file_w:
		file_w.store_string(JSON.stringify(data, "\t"))
		file_w.close()


func save_trade_state(slot: int, _ignored: Dictionary) -> void:
	if not slot_exists(slot): return
	var path: String = _get_slot_path(slot)
	var file_r: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file_r: return
	var json: JSON = JSON.new()
	if json.parse(file_r.get_as_text()) != OK:
		file_r.close()
		return
	var data: Dictionary = json.data
	file_r.close()
	var trade_svc: TradeService = EventBus.services.trade as TradeService
	if trade_svc:
		var save_data: Dictionary = trade_svc.get_save_data()
		data["coins"] = save_data.get("coins", 0)
		data["inventory"] = save_data.get("inventory", [])
		data["active_hotbar_index"] = save_data.get("active_hotbar_index", 0)
		data["starter_pack_granted"] = save_data.get("starter_pack_granted", false)
		data["armor_levels"] = save_data.get("armor_levels", {})
	var file_w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file_w:
		file_w.store_string(JSON.stringify(data, "\t"))
		file_w.close()


func save_story_state(slot: int, story_state: Dictionary) -> void:
	if not slot_exists(slot): return
	var path: String = _get_slot_path(slot)
	var file_r: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file_r: return
	var json: JSON = JSON.new()
	if json.parse(file_r.get_as_text()) != OK:
		file_r.close()
		return
	var data: Dictionary = json.data
	file_r.close()
	data["story_state"] = story_state.duplicate(true)
	var file_w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file_w:
		file_w.store_string(JSON.stringify(data, "\t"))
		file_w.close()


# ── Cloud Sync ────────────────────────────────────────────────────────────────

func read_slot_json(slot: int) -> Dictionary:
	return _read_json(_get_slot_path(slot))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	return json.data


func sync_to_cloud(slot: int) -> void:
	var supabase: SupabaseService = EventBus.services.supabase as SupabaseService
	var auth: AuthService = EventBus.services.auth as AuthService
	if supabase and auth and auth.is_authenticated():
		var data: Dictionary = read_slot_json(slot)
		if not data.is_empty():
			supabase.push_save(slot, data)


func sync_cloud_slots(callback: Callable) -> void:
	var supabase: SupabaseService = EventBus.services.supabase as SupabaseService
	var auth: AuthService = EventBus.services.auth as AuthService
	if not supabase or not auth or not auth.is_authenticated():
		callback.call()
		return
	supabase.fetch_saves(func(saves: Array) -> void:
		for s: Dictionary in saves:
			_merge_cloud_slot(s.get("slot_number", -1), s.get("save_data", {}), s.get("updated_at", ""))
		callback.call()
	)


func _merge_cloud_slot(slot: int, cloud_data: Dictionary, cloud_updated_at: String) -> void:
	if slot < 1 or slot > MAX_SLOTS or cloud_data.is_empty():
		return
	var cloud_path: String = CLOUD_SAVE_DIR + "slot_%d.json" % slot
	var local_ts: int = 0
	if FileAccess.file_exists(cloud_path):
		var existing: Dictionary = _read_json(cloud_path)
		local_ts = existing.get("timestamp", 0)
	var cloud_ts: int = int(Time.get_unix_time_from_datetime_string(cloud_updated_at.rstrip("Z")))
	if cloud_ts > local_ts:
		var file: FileAccess = FileAccess.open(cloud_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(cloud_data, "\t"))
			file.close()


func clear_cloud_saves() -> void:
	for i: int in range(1, MAX_SLOTS + 1):
		var path: String = CLOUD_SAVE_DIR + "slot_%d.json" % i
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func write_cloud_slot(slot: int, data: Dictionary) -> void:
	if slot < 1 or slot > MAX_SLOTS:
		return
	var path: String = CLOUD_SAVE_DIR + "slot_%d.json" % slot
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

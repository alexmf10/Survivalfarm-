## Servicio de Guardado de slot de partida. Gestiona los metadatos de los 5 slots de guardado.
class_name SaveService
extends RefCounted

const MAX_SLOTS: int = 5
const SAVE_DIR: String = "user://saves/"
const LEGACY_COMPLETED_TRIBUTE_INDEX: int = 4

## Slot activo actual. Establecido por slots_screen.gd al pulsar PLAY.
var active_slot: int = -1


func _init() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _get_slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot


func _read_slot_data(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}

	var file: FileAccess = FileAccess.open(_get_slot_path(slot), FileAccess.READ)
	if not file:
		return {}

	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()

	return json.data if json.data is Dictionary else {}


func _write_slot_data(slot: int, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(_get_slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot))


func get_slot_info(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {"exists": false, "slot": slot}
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty():
		return {"exists": false, "slot": slot}
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


func create_new_game(slot: int, nickname: String) -> void:
	var data: Dictionary = {
		"nickname": nickname,
		"day": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"date_string": Time.get_datetime_string_from_system(),
		"player_hp": 100,
		"player_position": {"x": 0, "y": 0},
		"coins": 0,
		"inventory": [],
		"story_state": _get_default_story_state(false),
		"trade_state": _get_default_trade_state(false),
		"crop_state": _get_default_crop_state(),
		"day_cycle_state": _get_default_day_cycle_state(1),
	}
	_write_slot_data(slot, data)


func update_nickname(slot: int, new_nickname: String) -> void:
	if not slot_exists(slot): return
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty(): return
	data["nickname"] = new_nickname
	_write_slot_data(slot, data)


func delete_slot(slot: int) -> void:
	var path: String = _get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func get_first_free_slot() -> int:
	## Devuelve el primer slot libre (1-5) o -1 si no hay ninguno.
	for i: int in range(1, MAX_SLOTS + 1):
		if not slot_exists(i):
			return i
	return -1


## Guarda el día actual en un slot existente.
## Llamado por el sistema de guardado cuando el jugador guarda la partida.
## @param slot  Número de slot (1-5).
## @param day   Día actual (proporcionado por DayCycleService.current_day).
func save_day(slot: int, day: int) -> void:
	if not slot_exists(slot): return
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty(): return
	data["day"] = day
	data["timestamp"] = Time.get_unix_time_from_system()
	data["date_string"] = Time.get_datetime_string_from_system()
	_write_slot_data(slot, data)


## Lee el día guardado de un slot. Devuelve 1 si el slot no existe.
## @param slot  Número de slot (1-5).
func get_day(slot: int) -> int:
	var info: Dictionary = get_slot_info(slot)
	if not info.get("exists", false):
		return 1
	return info.get("day", 1)


func get_day_cycle_state(slot: int) -> Dictionary:
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty():
		return _get_default_day_cycle_state(1)
	if data.has("day_cycle_state") and data["day_cycle_state"] is Dictionary:
		return data["day_cycle_state"].duplicate(true)
	return _get_default_day_cycle_state(int(data.get("day", 1)))


func save_day_cycle_state(slot: int, day_cycle_state: Dictionary) -> void:
	if not slot_exists(slot): return
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty(): return
	data["day_cycle_state"] = day_cycle_state.duplicate(true)
	data["day"] = int(day_cycle_state.get("current_day", data.get("day", 1)))
	data["timestamp"] = Time.get_unix_time_from_system()
	data["date_string"] = Time.get_datetime_string_from_system()
	_write_slot_data(slot, data)


func get_story_state(slot: int) -> Dictionary:
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty():
		return _get_default_story_state(false)
	if data.has("story_state") and data["story_state"] is Dictionary:
		var state: Dictionary = data["story_state"].duplicate(true)
		if _is_broken_starter_save(data, state):
			return _get_default_story_state(false)
		return state
	return _get_legacy_story_state(int(data.get("day", 1)))


func save_story_state(slot: int, story_state: Dictionary) -> void:
	if not slot_exists(slot): return
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty(): return
	data["story_state"] = story_state.duplicate(true)
	data["timestamp"] = Time.get_unix_time_from_system()
	data["date_string"] = Time.get_datetime_string_from_system()
	_write_slot_data(slot, data)


func get_trade_state(slot: int) -> Dictionary:
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty():
		return _get_default_trade_state(false)
	if data.has("trade_state") and data["trade_state"] is Dictionary:
		var state: Dictionary = data["trade_state"].duplicate(true)
		var story_state: Dictionary = data.get("story_state", {})
		if _is_broken_starter_save(data, story_state):
			state["starter_pack_granted"] = false
		return state
	var legacy_story: Dictionary = _get_legacy_story_state(int(data.get("day", 1)))
	return _get_default_trade_state(bool(legacy_story.get("starter_pack_granted", false)))


func save_trade_state(slot: int, trade_state: Dictionary) -> void:
	if not slot_exists(slot): return
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty(): return
	data["trade_state"] = trade_state.duplicate(true)
	data["timestamp"] = Time.get_unix_time_from_system()
	data["date_string"] = Time.get_datetime_string_from_system()
	_write_slot_data(slot, data)


func get_crop_state(slot: int) -> Dictionary:
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty():
		return _get_default_crop_state()
	if data.has("crop_state") and data["crop_state"] is Dictionary:
		return data["crop_state"].duplicate(true)
	return _get_default_crop_state()


func save_crop_state(slot: int, crop_state: Dictionary) -> void:
	if not slot_exists(slot): return
	var data: Dictionary = _read_slot_data(slot)
	if data.is_empty(): return
	data["crop_state"] = crop_state.duplicate(true)
	data["timestamp"] = Time.get_unix_time_from_system()
	data["date_string"] = Time.get_datetime_string_from_system()
	_write_slot_data(slot, data)


func _get_legacy_story_state(day: int) -> Dictionary:
	if day > 1:
		return _get_default_story_state(true)
	return _get_default_story_state(false)


func _get_default_story_state(legacy_completed: bool) -> Dictionary:
	return {
		"starter_pack_granted": legacy_completed,
		"current_tribute_index": LEGACY_COMPLETED_TRIBUTE_INDEX if legacy_completed else 0,
		"horde_started": false,
		"final_started": false,
		"legacy_migrated": legacy_completed,
	}


func _get_default_trade_state(starter_pack: bool) -> Dictionary:
	return {
		"coins": 0,
		"slots": [],
		"active_hotbar_index": 0,
		"starter_pack_granted": starter_pack,
	}


func _get_default_crop_state() -> Dictionary:
	return {
		"crops": [],
	}


func _get_default_day_cycle_state(day: int) -> Dictionary:
	return {
		"current_day": day,
		"is_night": false,
		"elapsed": 0.0,
		"running": true,
	}


func _is_broken_starter_save(data: Dictionary, story_state: Dictionary) -> bool:
	var day_state = data.get("day_cycle_state", {})
	var day: int = int(day_state.get("current_day", data.get("day", 1))) if day_state is Dictionary else int(data.get("day", 1))
	if day > 1:
		return false
	if not bool(story_state.get("starter_pack_granted", false)):
		return false
	if int(story_state.get("current_tribute_index", 0)) != 0:
		return false

	var crop_state = data.get("crop_state", {})
	var crops: Array = crop_state.get("crops", []) if crop_state is Dictionary else []
	if not crops.is_empty():
		return false

	var trade_state = data.get("trade_state", {})
	if not (trade_state is Dictionary):
		return false
	if int(trade_state.get("coins", 0)) > 0:
		return false
	for slot in trade_state.get("slots", []):
		if slot is Dictionary and int(slot.get("amount", 0)) > 0:
			return false
	return true

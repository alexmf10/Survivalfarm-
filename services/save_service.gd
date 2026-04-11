## Servicio de Guardado de slot de partida. Gestiona los metadatos de los 5 slots de guardado.
class_name SaveService
extends RefCounted

const MAX_SLOTS: int = 5
const SAVE_DIR: String = "user://saves/"

## Slot activo actual. Establecido por slots_screen.gd al pulsar PLAY.
var active_slot: int = -1


func _init() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _get_slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot


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
	}
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(_get_slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()


func update_nickname(slot: int, new_nickname: String) -> void:
	if not slot_exists(slot): return
	var path: String = _get_slot_path(slot)
	var file_read: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file_read: return
	var json: JSON = JSON.new()
	if json.parse(file_read.get_as_text()) == OK:
		var data: Dictionary = json.data
		file_read.close()
		data["nickname"] = new_nickname
		var file_write: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file_write:
			file_write.store_string(JSON.stringify(data, "\t"))
			file_write.close()
	else:
		file_read.close()


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

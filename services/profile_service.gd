## Servicio de Perfil y Logros por slot.
## Persiste datos en user://achievements_slot_X.json.
class_name ProfileService
extends RefCounted

const DEFAULT_ACHIEVEMENTS: Dictionary = {
	"first_harvest": {"title": "First Harvest", "description": "Recoge tu primera cosecha", "unlocked": false, "unlock_date": ""},
	"rich_farmer": {"title": "Rich Farmer", "description": "Acumula 100 monedas", "unlocked": false, "unlock_date": ""},
	"survive_7": {"title": "Week Survivor", "description": "Sobrevive 7 dias", "unlocked": false, "unlock_date": ""},
	"survive_30": {"title": "Month Survivor", "description": "Sobrevive 30 dias", "unlocked": false, "unlock_date": ""},
	"first_kill": {"title": "Monster Slayer", "description": "Derrota tu primer enemigo", "unlocked": false, "unlock_date": ""},
	"boss_defeated": {"title": "Farm Savior", "description": "Derrota al monstruo final", "unlocked": false, "unlock_date": ""},
	"full_armor": {"title": "Fully Equipped", "description": "Equipa armadura completa", "unlocked": false, "unlock_date": ""},
	"trader_deal": {"title": "Businessman", "description": "Realiza tu primera transaccion", "unlocked": false, "unlock_date": ""},
}

var current_slot: int = -1
var _achievements: Dictionary = {}


func _init() -> void:
	_achievements = DEFAULT_ACHIEVEMENTS.duplicate(true)


func load_profile(slot: int) -> void:
	current_slot = slot
	_load_profile()


func _get_save_path() -> String:
	return "user://achievements_slot_%d.json" % current_slot


# Logros

func get_achievements() -> Dictionary:
	return _achievements.duplicate(true)


func is_achievement_unlocked(achievement_id: String) -> bool:
	if _achievements.has(achievement_id):
		return _achievements[achievement_id].get("unlocked", false)
	return false


func unlock_achievement(achievement_id: String) -> void:
	if current_slot <= 0: return
	if not _achievements.has(achievement_id):
		push_warning("ProfileService: achievement '%s' no existe." % achievement_id)
		return
	if _achievements[achievement_id]["unlocked"]:
		return # Ya desbloqueado
	_achievements[achievement_id]["unlocked"] = true
	_achievements[achievement_id]["unlock_date"] = Time.get_datetime_string_from_system()
	_save_profile()
	if EventBus:
		EventBus.achievement_unlocked.emit(achievement_id)


func get_unlocked_count() -> int:
	var count: int = 0
	for id: String in _achievements:
		if _achievements[id].get("unlocked", false):
			count += 1
	return count


func get_total_count() -> int:
	return _achievements.size()


# Cargado y guardado

func _save_profile() -> void:
	if current_slot <= 0: return
	var data: Dictionary = {"achievements": _achievements}
	var file: FileAccess = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _load_profile() -> void:
	_achievements = DEFAULT_ACHIEVEMENTS.duplicate(true)
	if current_slot <= 0: return
	
	var path: String = _get_save_path()
	if not FileAccess.file_exists(path): return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file: return

	var json: JSON = JSON.new()
	var error: int = json.parse(file.get_as_text())
	file.close()

	if error == OK:
		var data: Dictionary = json.data
		var saved_achievements: Dictionary = data.get("achievements", {})
		for id: String in _achievements:
			if saved_achievements.has(id):
				_achievements[id] = saved_achievements[id]

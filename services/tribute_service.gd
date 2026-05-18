class_name TributeService
extends RefCounted

const FAILURE_MESSAGE: String = "No harvest. Then there will be meat."
const FINAL_REVEAL_MESSAGE: String = "Fourth tribute: 999 wheat, 999 beets.\n\nDo not look at me like that. It was never about collecting from you. It was about waking them.\n\nYou have paid enough to feed the march. Tonight, the owner comes."

const TRIBUTES: Array[Dictionary] = [
	{
		"due_day": 4,
		"wheat": 15,
		"beet": 8,
		"reward_wheat_seeds": 45,
		"reward_beet_seeds": 24,
		"dialog": "First tribute. Wheat and beets. The soil signs with roots; you sign with harvest.",
		"reward_dialog": "Plant these. The ones below prefer food raised in your own dirt.",
	},
	{
		"due_day": 7,
		"wheat": 35,
		"beet": 18,
		"reward_wheat_seeds": 55,
		"reward_beet_seeds": 28,
		"dialog": "Good delivery. The ones below chew better when it arrives fresh.",
		"reward_dialog": "More seeds. More roots. More mouths waiting under the soil.",
	},
	{
		"due_day": 10,
		"wheat": 60,
		"beet": 30,
		"reward_wheat_seeds": 35,
		"reward_beet_seeds": 18,
		"dialog": "The march can already smell your field. Do not fail now; when they are hungry, they do not know door from owner.",
		"reward_dialog": "One last sowing, farmer. Let it grow tall. Let it grow deep.",
	},
	{
		"due_day": 12,
		"wheat": 999,
		"beet": 999,
		"reward_wheat_seeds": 0,
		"reward_beet_seeds": 0,
		"dialog": FINAL_REVEAL_MESSAGE,
		"final": true,
	},
]

var starter_pack_claimed: bool = false
var current_tribute_index: int = 0
var horde_started: bool = false
var final_started: bool = false
var _loading_state: bool = false


func connect_signals() -> void:
	EventBus.starter_pack_received.connect(_on_starter_pack_received)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)


func apply_save_state(state: Dictionary) -> void:
	_loading_state = true
	starter_pack_claimed = bool(state.get("starter_pack_granted", false))
	current_tribute_index = clampi(int(state.get("current_tribute_index", 0)), 0, TRIBUTES.size())
	horde_started = bool(state.get("horde_started", false))
	final_started = bool(state.get("final_started", false))
	_loading_state = false


func get_save_state() -> Dictionary:
	return {
		"starter_pack_granted": starter_pack_claimed,
		"current_tribute_index": current_tribute_index,
		"horde_started": horde_started,
		"final_started": final_started,
	}


func get_current_tribute() -> Dictionary:
	if current_tribute_index < 0 or current_tribute_index >= TRIBUTES.size():
		return {}
	return TRIBUTES[current_tribute_index]


func get_objective_text() -> String:
	if not starter_pack_claimed:
		return "Find the trader. No one survives here without seeds."
	if horde_started:
		return "You cannot sleep. The horde is coming from the graveyard."
	if final_started:
		return "Defeat the owner of the march."

	var tribute := get_current_tribute()
	if tribute.is_empty():
		return "The soil is silent."
	if tribute.get("final", false):
		return "The last visit will be on day %d." % int(tribute["due_day"])
	return "Tribute %d: %d wheat + %d beets before day %d." % [
		current_tribute_index + 1,
		tribute["wheat"],
		tribute["beet"],
		tribute["due_day"],
	]


func can_sleep() -> bool:
	if not starter_pack_claimed:
		return false
	if horde_started or final_started:
		return false

	var tribute := get_current_tribute()
	if tribute.is_empty():
		return true

	var day_svc := EventBus.services.day_cycle as DayCycleService
	if day_svc == null:
		return true

	return day_svc.current_day < int(tribute["due_day"])


func is_tribute_due_on_day(day_number: int) -> bool:
	if not starter_pack_claimed or horde_started or final_started:
		return false

	var tribute := get_current_tribute()
	if tribute.is_empty():
		return false

	return day_number >= int(tribute["due_day"])


func debug_trigger_current_due_event() -> void:
	if horde_started or final_started:
		return

	starter_pack_claimed = true
	var tribute := get_current_tribute()
	if tribute.is_empty():
		return

	if tribute.get("final", false):
		_start_final()
	else:
		horde_started = true
		_save_state()
		EventBus.objective_changed.emit(get_objective_text())
		EventBus.tribute_failed.emit(FAILURE_MESSAGE)


func get_sleep_block_message() -> String:
	if not starter_pack_claimed:
		return "Talk to the trader first."
	if horde_started:
		return "You cannot sleep. Something is moving in the graveyard."
	if final_started:
		return "You cannot sleep. The owner is already coming."
	return "The collector is waiting for his tribute."


func interact_with_collector() -> String:
	if not starter_pack_claimed:
		return "Talk to the trader first. He knows why this land is still breathing."
	if horde_started:
		return FAILURE_MESSAGE
	if final_started:
		return "The march is already on its way."

	var tribute := get_current_tribute()
	if tribute.is_empty():
		return "There is nothing left to collect."
	if tribute.get("final", false):
		var day_svc := EventBus.services.day_cycle as DayCycleService
		if day_svc and day_svc.current_day < int(tribute["due_day"]):
			return "The fourth tribute is still sprouting. Come back on day %d." % int(tribute["due_day"])
		_start_final()
		return FINAL_REVEAL_MESSAGE

	var trade_svc := EventBus.services.trade as TradeService
	if trade_svc == null:
		return "I cannot find your sacks. Come back when the soil remembers them."

	var wheat_required: int = int(tribute["wheat"])
	var beet_required: int = int(tribute["beet"])
	var header: String = str(tribute["dialog"])

	if not trade_svc.has_crops(wheat_required, beet_required):
		return "%s\n\nBring %d wheat and %d beets before night falls on day %d.\n\nYou currently have %d wheat and %d beets." % [
			header,
			wheat_required,
			beet_required,
			int(tribute["due_day"]),
			trade_svc.get_crop_count(CropComponent.CropType.Wheat),
			trade_svc.get_crop_count(CropComponent.CropType.Beet),
		]

	trade_svc.remove_crops(wheat_required, beet_required)
	trade_svc.add_seeds(CropComponent.CropType.Wheat, int(tribute["reward_wheat_seeds"]))
	trade_svc.add_seeds(CropComponent.CropType.Beet, int(tribute["reward_beet_seeds"]))

	var paid_index: int = current_tribute_index
	current_tribute_index += 1
	_save_state()
	EventBus.tribute_paid.emit(paid_index)
	EventBus.objective_changed.emit(get_objective_text())

	return "%s\n\nDelivery accepted.\n%s" % [header, str(tribute["reward_dialog"])]


func _on_starter_pack_received() -> void:
	starter_pack_claimed = true
	_save_state()
	EventBus.objective_changed.emit(get_objective_text())
	EventBus.tribute_available.emit(current_tribute_index)


func _on_day_started(_day_number: int) -> void:
	EventBus.objective_changed.emit(get_objective_text())


func _on_day_phase_changed(is_night: bool) -> void:
	if not is_night or not starter_pack_claimed or horde_started or final_started:
		return

	var tribute := get_current_tribute()
	if tribute.is_empty():
		return

	var day_svc := EventBus.services.day_cycle as DayCycleService
	if day_svc == null or day_svc.current_day < int(tribute["due_day"]):
		return

	if tribute.get("final", false):
		_start_final()
	else:
		horde_started = true
		_save_state()
		EventBus.objective_changed.emit(get_objective_text())
		EventBus.tribute_failed.emit(FAILURE_MESSAGE)


func _start_final() -> void:
	if final_started:
		return
	final_started = true
	_save_state()
	EventBus.objective_changed.emit(get_objective_text())
	EventBus.final_boss_started.emit(FINAL_REVEAL_MESSAGE)


func _save_state() -> void:
	if _loading_state:
		return
	var save_svc := EventBus.services.save as SaveService
	if save_svc and save_svc.active_slot > 0:
		save_svc.save_story_state(save_svc.active_slot, get_save_state())

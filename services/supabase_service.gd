## Sincronización de logros y partidas con Supabase (Node — necesita árbol para HTTPRequest).
## Escucha EventBus; nunca acopla directamente con ProfileService ni SaveService.
## Falla silenciosamente si no hay red o no existe backend_config.gd.
class_name SupabaseService
extends Node

const MAX_RETRIES: int = 1
const RETRY_DELAY_SEC: float = 3.0

var _user_id: String = ""
var _active_slot: int = -1

# Cola de logros
var _busy: bool = false
var _pending_queue: Array[Dictionary] = []
var _http: HTTPRequest

# HTTP separado para saves (no bloquea la cola de logros)
var _http_save: HTTPRequest
var _save_callback: Callable


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_achievement_request_completed)

	_http_save = HTTPRequest.new()
	_http_save.timeout = 10.0
	add_child(_http_save)
	_http_save.request_completed.connect(_on_save_request_completed)

	EventBus.slot_activated.connect(_on_slot_activated)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.auth_state_changed.connect(_on_auth_state_changed)


func _on_auth_state_changed(is_authenticated: bool, user_id: String) -> void:
	_user_id = user_id if is_authenticated else ""
	_pending_queue.clear()
	_busy = false


func _on_slot_activated(slot: int, _uuid: String) -> void:
	_active_slot = slot


# ── Achievements ──────────────────────────────────────────────────────────────

func _on_achievement_unlocked(achievement_id: String) -> void:
	if _user_id == "":
		return
	_pending_queue.append({
		"achievement_id": achievement_id,
		"unlocked_at": Time.get_datetime_string_from_system() + "Z",
		"retry_count": 0,
	})
	_flush_queue()


func _flush_queue() -> void:
	if _busy or _pending_queue.is_empty():
		return
	_busy = true
	_send_achievement(_pending_queue[0])


func _send_achievement(item: Dictionary) -> void:
	var config: GDScript = _load_config()
	if not config:
		push_warning("SupabaseService: backend_config.gd no encontrado, logro '%s' no sincronizado." % item["achievement_id"])
		_busy = false
		_pending_queue.pop_front()
		_flush_queue()
		return

	var url: String = config.SUPABASE_URL + "/rest/v1/player_achievements"
	var body: String = JSON.stringify({
		"user_id": _user_id,
		"achievement_id": item["achievement_id"],
		"unlocked_at": item["unlocked_at"],
		"slot_number": _active_slot,
	})
	var headers: PackedStringArray = _auth_headers(config)
	headers.append("Prefer: return=minimal")

	var err: int = _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("SupabaseService: HTTPRequest falló (código %d)" % err)
		_busy = false
		_on_achievement_failed(_pending_queue[0])


func _on_achievement_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_busy = false
	if _pending_queue.is_empty():
		return
	var network_ok: bool = (result == HTTPRequest.RESULT_SUCCESS)
	var http_ok: bool = (response_code == 201 or response_code == 409)
	if network_ok and http_ok:
		_pending_queue.pop_front()
		_flush_queue()
	else:
		push_warning("SupabaseService: logro — respuesta inesperada result=%d code=%d" % [result, response_code])
		_on_achievement_failed(_pending_queue[0])


func _on_achievement_failed(item: Dictionary) -> void:
	item["retry_count"] += 1
	_pending_queue[0] = item
	if item["retry_count"] > MAX_RETRIES:
		push_warning("SupabaseService: logro '%s' descartado tras %d intentos." % [item["achievement_id"], MAX_RETRIES])
		_pending_queue.pop_front()
		_flush_queue()
	else:
		get_tree().create_timer(RETRY_DELAY_SEC).timeout.connect(_flush_queue, CONNECT_ONE_SHOT)


# ── Cloud Saves ───────────────────────────────────────────────────────────────

func push_save(slot: int, save_data: Dictionary) -> void:
	if _user_id == "":
		return
	var config: GDScript = _load_config()
	if not config:
		return
	var url: String = config.SUPABASE_URL + "/rest/v1/player_saves"
	var body: String = JSON.stringify({
		"user_id": _user_id,
		"slot_number": slot,
		"save_data": save_data,
		"updated_at": Time.get_datetime_string_from_system() + "Z",
	})
	var headers: PackedStringArray = _auth_headers(config)
	headers.append("Prefer: resolution=merge-duplicates,return=minimal")
	_http_save.request(url, headers, HTTPClient.METHOD_POST, body)
	_save_callback = Callable()


func fetch_saves(callback: Callable) -> void:
	if _user_id == "":
		callback.call([])
		return
	var config: GDScript = _load_config()
	if not config:
		callback.call([])
		return
	var url: String = config.SUPABASE_URL + "/rest/v1/player_saves?user_id=eq.%s&select=slot_number,save_data,updated_at" % _user_id
	var headers: PackedStringArray = _auth_headers(config)
	_save_callback = callback
	_http_save.request(url, headers, HTTPClient.METHOD_GET, "")


func delete_save(slot: int) -> void:
	if _user_id == "":
		return
	var config: GDScript = _load_config()
	if not config:
		return
	var url: String = config.SUPABASE_URL + "/rest/v1/player_saves?user_id=eq.%s&slot_number=eq.%d" % [_user_id, slot]
	var headers: PackedStringArray = _auth_headers(config)
	_http_save.request(url, headers, HTTPClient.METHOD_DELETE, "")
	_save_callback = Callable()


func _on_save_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _save_callback.is_valid():
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code >= 400:
		push_warning("SupabaseService: save request falló result=%d code=%d" % [result, response_code])
		_save_callback.call([])
		_save_callback = Callable()
		return
	var json: JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and json.data is Array:
		_save_callback.call(json.data)
	else:
		_save_callback.call([])
	_save_callback = Callable()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _auth_headers(config: GDScript) -> PackedStringArray:
	var auth: AuthService = EventBus.services.auth as AuthService
	var token: String = auth.get_access_token() if auth and auth.is_authenticated() else config.SUPABASE_ANON_KEY
	return PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + config.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + token,
	])


func _load_config() -> GDScript:
	return load("res://config/backend_config.gd") as GDScript

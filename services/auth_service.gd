## Servicio de autenticación con Supabase Auth.
## Gestiona sign-up, sign-in, sign-out y restauración de sesión entre sesiones.
## Node — necesita árbol para HTTPRequest.
class_name AuthService
extends Node

const SESSION_PATH: String = "user://auth_session.json"

var _access_token: String = ""
var _refresh_token: String = ""
var _user_id: String = ""
var _email: String = ""
var _pending_callback: Callable
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_try_restore_session()


func is_authenticated() -> bool:
	return _access_token != "" and _user_id != ""


func get_access_token() -> String:
	return _access_token


func get_user_id() -> String:
	return _user_id


func get_email() -> String:
	return _email


func sign_up(email: String, password: String, callback: Callable) -> void:
	_pending_callback = callback
	var config := _load_config()
	if not config:
		callback.call(false, "Backend no configurado.")
		return
	var url: String = config.SUPABASE_URL + "/auth/v1/signup"
	var body: String = JSON.stringify({"email": email, "password": password})
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"apikey: " + config.SUPABASE_ANON_KEY,
	]
	_http.request(url, headers, HTTPClient.METHOD_POST, body)


func sign_in(email: String, password: String, callback: Callable) -> void:
	_pending_callback = callback
	var config := _load_config()
	if not config:
		callback.call(false, "Backend no configurado.")
		return
	var url: String = config.SUPABASE_URL + "/auth/v1/token?grant_type=password"
	var body: String = JSON.stringify({"email": email, "password": password})
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"apikey: " + config.SUPABASE_ANON_KEY,
	]
	_http.request(url, headers, HTTPClient.METHOD_POST, body)


func sign_out() -> void:
	_access_token = ""
	_refresh_token = ""
	_user_id = ""
	_email = ""
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)
	if EventBus:
		EventBus.auth_state_changed.emit(false, "")


func _try_restore_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var file: FileAccess = FileAccess.open(SESSION_PATH, FileAccess.READ)
	if not file:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data: Dictionary = json.data
	var expires_at: int = data.get("expires_at", 0)
	if Time.get_unix_time_from_system() < expires_at:
		_access_token = data.get("access_token", "")
		_refresh_token = data.get("refresh_token", "")
		_user_id = data.get("user_id", "")
		_email = data.get("email", "")
		if _user_id != "":
			if EventBus:
				EventBus.auth_state_changed.emit(true, _user_id)
			return
	# Token expired — try to refresh
	var refresh: String = data.get("refresh_token", "")
	if refresh != "":
		_refresh_session(refresh)


func _refresh_session(refresh_token: String) -> void:
	var config := _load_config()
	if not config:
		return
	_pending_callback = func(_ok: bool, _err: String) -> void: pass
	var url: String = config.SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
	var body: String = JSON.stringify({"refresh_token": refresh_token})
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"apikey: " + config.SUPABASE_ANON_KEY,
	]
	_http.request(url, headers, HTTPClient.METHOD_POST, body)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_dispatch_callback(false, "Error de red.")
		return

	var json: JSON = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_dispatch_callback(false, "Respuesta inválida del servidor.")
		return

	var data: Dictionary = json.data
	if response_code == 200 or response_code == 201:
		var user: Dictionary = data.get("user", {})
		_access_token = data.get("access_token", "")
		_refresh_token = data.get("refresh_token", "")
		_user_id = user.get("id", "")
		_email = user.get("email", "")
		var expires_in: int = data.get("expires_in", 3600)
		_persist_session(expires_in)
		if EventBus:
			EventBus.auth_state_changed.emit(true, _user_id)
		_dispatch_callback(true, "")
	else:
		var msg: String = data.get("error_description", data.get("msg", "Error desconocido."))
		_dispatch_callback(false, msg)


func _persist_session(expires_in: int) -> void:
	var session: Dictionary = {
		"access_token": _access_token,
		"refresh_token": _refresh_token,
		"user_id": _user_id,
		"email": _email,
		"expires_at": int(Time.get_unix_time_from_system()) + expires_in,
	}
	var file: FileAccess = FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(session))
		file.close()


func _dispatch_callback(ok: bool, error: String) -> void:
	if _pending_callback.is_valid():
		_pending_callback.call(ok, error)
	_pending_callback = Callable()


func _load_config() -> GDScript:
	return load("res://config/backend_config.gd") as GDScript

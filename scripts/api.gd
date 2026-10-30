extends Node
## Autoload "Api": manda al servidor (carpeta server/) todo lo que hace el jugador.
##
## Los eventos se guardan en una cola y se envían en lotes por HTTP cada pocos segundos.
## Si el servidor está apagado, la cola se guarda en user://api_queue.json y se reenvía
## cuando vuelve: el juego nunca se traba por falta de conexión.
##
## La URL del servidor se configura en res://api_config.cfg  ([api] url="http://...").
## En el celular se puede cambiar desde Ajustes (se guarda en user://settings.cfg y tiene prioridad).

const CONFIG_PATH := "res://api_config.cfg"
const QUEUE_PATH := "user://api_queue.json"
const SETTINGS_PATH := "user://settings.cfg"
const FLUSH_EVERY := 3.0   # segundos entre envíos
const RETRY_AFTER := 8.0   # espera extra si el servidor no responde
const BATCH := 40          # eventos por envío
const MAX_QUEUE := 5000

var base_url := "http://127.0.0.1:8000"
var player_name := ""
var session_id := ""
var session_fresh := false  # partida recién creada que aún no entra a ningún nivel
var online := false

var _queue: Array = []
var _in_flight: Array = []
var _http: HTTPRequest
var _timer := 0.0
var _counter := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		base_url = str(cfg.get_value("api", "url", base_url)).strip_edges().trim_suffix("/")
	var s := ConfigFile.new()
	if s.load(SETTINGS_PATH) == OK:
		player_name = str(s.get_value("player", "name", ""))
		base_url = str(s.get_value("api", "url", base_url)).strip_edges().trim_suffix("/")
	_load_queue()
	_http = HTTPRequest.new()
	_http.timeout = 6.0
	add_child(_http)
	_http.request_completed.connect(_on_sent)


# ---------------------------------------------------------------- partida

## Empieza una partida nueva para este jugador (se llama al darle "Nueva partida").
## perfil: datos opcionales del jugador (edad, sexo, lugar, ingresos) por rangos.
func new_session(name: String, perfil: Dictionary = {}) -> void:
	player_name = name.strip_edges().substr(0, 24)
	if player_name == "":
		player_name = "Jugador"
	session_id = _make_id()
	session_fresh = true
	var s := ConfigFile.new()
	s.load(SETTINGS_PATH)
	s.set_value("player", "name", player_name)
	for k in perfil:
		s.set_value("perfil", k, perfil[k])
	s.save(SETTINGS_PATH)
	track("partida_inicio", {})
	if not perfil.is_empty():
		track("perfil", perfil)


## Último perfil que llenó el jugador (para precargar el formulario).
func saved_profile() -> Dictionary:
	var s := ConfigFile.new()
	var out := {}
	if s.load(SETTINGS_PATH) == OK and s.has_section("perfil"):
		for k in s.get_section_keys("perfil"):
			out[k] = s.get_value("perfil", k)
	return out


## Retoma una partida guardada (botón "Continuar").
func resume(id: String, name: String) -> void:
	if id == "":
		new_session(name)
		return
	session_id = id
	player_name = name if name != "" else player_name
	session_fresh = false


# ---------------------------------------------------------------- eventos

## Registra un evento. tipo: "cobro", "acertijo", "moneda", "bellota", "nivel_fin"...
func track(tipo: String, datos: Dictionary = {}) -> void:
	if session_id == "":
		return
	# Lo que pasa dentro del tutorial no cuenta para la base de datos.
	var scene := get_tree().current_scene
	if tipo != "partida_inicio" and scene and scene.name == "Tutorial":
		return
	if tipo == "nivel_inicio":
		session_fresh = false
	_counter += 1
	var ev := {
		"uid": "%s-%d-%d" % [session_id, Time.get_ticks_usec(), _counter],
		"partida_id": session_id,
		"jugador": player_name,
		"tipo": tipo,
		"nivel": Game.LEVELS[Game.level_index].id,
		"momento": Time.get_datetime_string_from_system(true),
		"datos": datos,
		"estado": Game.snapshot(),
	}
	_queue.append(ev)
	if _queue.size() > MAX_QUEUE:
		_queue = _queue.slice(_queue.size() - MAX_QUEUE)
	_save_queue()


## Fuerza un envío inmediato (al terminar un nivel, por ejemplo).
func flush() -> void:
	if not _in_flight.is_empty() or _queue.is_empty():
		return
	var batch := _queue.slice(0, BATCH)
	var body := JSON.stringify({"eventos": batch})
	var err := _http.request(base_url + "/api/eventos", ["Content-Type: application/json"],
		HTTPClient.METHOD_POST, body)
	if err == OK:
		_in_flight = batch.map(func(e): return e.uid)
	else:
		online = false


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= FLUSH_EVERY:
		_timer = 0.0
		flush()


func _on_sent(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var sent := _in_flight
	_in_flight = []
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		online = true
		_queue = _queue.filter(func(e): return not sent.has(e.uid))
		_save_queue()
		if not _queue.is_empty():
			_timer = FLUSH_EVERY  # quedan más: envía en el siguiente frame
	else:
		online = false
		_timer = -RETRY_AFTER


# ---------------------------------------------------------------- leaderboard

## Pide el top 10 al servidor. cb recibe (ok: bool, filas: Array).
func fetch_leaderboard(criterio: String, cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 5.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h, body: PackedByteArray):
		var rows: Array = []
		var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200
		if ok:
			var data = JSON.parse_string(body.get_string_from_utf8())
			if typeof(data) == TYPE_DICTIONARY:
				rows = data.get("top", [])
			else:
				ok = false
		online = ok
		cb.call(ok, rows)
		req.queue_free())
	if req.request(base_url + "/api/leaderboard?criterio=" + criterio.uri_encode()) != OK:
		cb.call(false, [])
		req.queue_free()


# ---------------------------------------------------------------- servidor

## Cambia la URL del servidor (Ajustes) y la guarda.
func set_server_url(url: String) -> void:
	url = url.strip_edges().trim_suffix("/")
	if url == "":
		return
	if not url.begins_with("http://") and not url.begins_with("https://"):
		url = "http://" + url
	if url.count(":") < 2:  # sin puerto: el servidor usa el 8000
		url += ":8000"
	base_url = url
	var s := ConfigFile.new()
	s.load(SETTINGS_PATH)
	s.set_value("api", "url", base_url)
	s.save(SETTINGS_PATH)
	_timer = FLUSH_EVERY  # reintenta mandar lo pendiente ya


## Comprueba si el servidor responde. cb recibe (ok: bool).
func ping(cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 4.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h, _b):
		online = result == HTTPRequest.RESULT_SUCCESS and code == 200
		cb.call(online)
		req.queue_free())
	if req.request(base_url + "/api/ping") != OK:
		cb.call(false)
		req.queue_free()


# ---------------------------------------------------------------- utilidades

func pending() -> int:
	return _queue.size()


func _make_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%x%04x%04x" % [int(Time.get_unix_time_from_system()), rng.randi() % 0xFFFF, rng.randi() % 0xFFFF]


func _save_queue() -> void:
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_queue))


func _load_queue() -> void:
	if not FileAccess.file_exists(QUEUE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
	if typeof(data) == TYPE_ARRAY:
		_queue = data

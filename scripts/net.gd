extends Node
## Carreras por Wi-Fi local (autoload "Net"): salas, búsqueda de partidas en la red y carrera.
##
## Cada móvil simula su propia canica y envía su posición a los demás.
## El anfitrión (id 1) elige el nivel, da la salida a la vez a todos y lleva la clasificación.

signal players_changed
signal games_changed
## Conectado a una sala como invitado.
signal joined
## Se perdió la conexión (el anfitrión cerró, fallo de red...). `reason` es una clave de traducción.
## No se emite al salir uno mismo.
signal left(reason: String)
signal countdown_begin
signal remote_state(id: int, pos: Vector3, vel: Vector3, rot: Quaternion)
## Posiciones de las canicas de acero enviadas por el anfitrión: [[pos, vel, rot], ...]
signal chasers_state(states: Array)
## Otro jugador ha pisado la baldosa `index`.
signal crumble_remote(index: int)
signal standings_changed
signal race_over

const GAME_PORT := 45124
const DISCOVERY_PORT := 45123
const DISCOVERY_TAG := "MM2026"
const MAX_PLAYERS := 4
## Color de canica por puesto en la sala.
const COLORS := [Color(0.7, 0.85, 1.0), Color(1.0, 0.45, 0.4), Color(0.5, 1.0, 0.45), Color(1.0, 0.85, 0.3)]
## Si alguien tarda en cargar el nivel, la carrera empieza igualmente pasado este tiempo.
const LOAD_TIMEOUT := 8.0

## id -> {name, slot}
var players := {}
var level_index := 0
var in_race := false
## Clasificación: [{id, name, time}] ordenada; time < 0 = no terminó.
var standings := []
## Partidas encontradas en la red. ip -> {name, players, seen}
var found_games := {}

var _pending_name := ""
var _beacon: PacketPeerUDP
var _beacon_timer := 0.0
var _listener: PacketPeerUDP
var _loaded := {}
var _finished := {}
var _countdown_sent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void:
		_reset()
		left.emit("NET_CONNECT_FAILED")
	)
	multiplayer.server_disconnected.connect(func() -> void:
		_reset()
		left.emit("NET_HOST_CLOSED")
	)


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func my_slot() -> int:
	return players.get(my_id(), {}).get("slot", 0)


func color_of(id: int) -> Color:
	return COLORS[players.get(id, {}).get("slot", 0) % COLORS.size()]


# --- Sala -----------------------------------------------------------------

func host(player_name: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players = {1: {name = player_name, slot = 0}}
	level_index = 0
	stop_discovery()
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	players_changed.emit()
	return OK


func join(ip: String, player_name: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, GAME_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_pending_name = player_name
	return OK


func leave() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	_reset()


func select_level(index: int) -> void:
	if is_host():
		level_index = wrapi(index, 0, GameState.LEVELS.size())
		_sync_to_all()


## Direcciones IPv4 de este dispositivo, la más probable primero (para mostrarlas al anfitrión).
## Las 172.16–31 van al final: en un PC suelen ser adaptadores virtuales (Hyper-V, WSL, Docker).
func local_ips() -> Array[String]:
	var ranked := []
	for ip in IP.get_local_addresses():
		if not ip.is_valid_ip_address() or ":" in ip or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		var rank := 2
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			rank = 0
		elif _is_172_private(ip):
			rank = 3
		ranked.append([rank, ip])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var result: Array[String] = []
	for entry in ranked:
		result.append(entry[1])
	return result


func _is_172_private(ip: String) -> bool:
	var parts := ip.split(".")
	return parts.size() == 4 and parts[0] == "172" and int(parts[1]) >= 16 and int(parts[1]) <= 31


func _on_connected() -> void:
	_register.rpc_id(1, _pending_name)
	joined.emit()


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_race or players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var clean := player_name.strip_edges().left(16)
	players[id] = {name = clean if clean != "" else "?", slot = _free_slot()}
	_sync_to_all()


func _free_slot() -> int:
	var used := []
	for info in players.values():
		used.append(info.slot)
	for slot in MAX_PLAYERS:
		if not slot in used:
			return slot
	return 0


func _sync_to_all() -> void:
	_sync_players.rpc(players, level_index)
	players_changed.emit()


@rpc("authority", "reliable")
func _sync_players(new_players: Dictionary, new_level: int) -> void:
	players = new_players
	level_index = new_level
	players_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if not players.has(id):
		return
	players.erase(id)
	players_changed.emit()
	if multiplayer.is_server():
		_sync_to_all()
		if in_race:
			_finished.erase(id)
			_update_standings()


func _reset() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	standings.clear()
	in_race = false
	if _beacon != null:
		_beacon.close()
		_beacon = null


# --- Búsqueda de partidas en la red ------------------------------------------

func start_discovery() -> void:
	stop_discovery()
	found_games.clear()
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null
	games_changed.emit()


func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
		_listener = null


func _process(delta: float) -> void:
	# El anfitrión anuncia su sala cada segundo mientras no hay carrera.
	if _beacon != null and not in_race:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = 1.0
			var info := "%s|%s|%d" % [DISCOVERY_TAG, players.get(1, {}).get("name", "?"), players.size()]
			_beacon.put_packet(info.to_utf8_buffer())

	if _listener != null:
		var changed := false
		while _listener.get_available_packet_count() > 0:
			var text := _listener.get_packet().get_string_from_utf8()
			var ip := _listener.get_packet_ip()
			var parts := text.split("|")
			if parts.size() == 3 and parts[0] == DISCOVERY_TAG:
				found_games[ip] = {name = parts[1], players = int(parts[2]), seen = Time.get_ticks_msec()}
				changed = true
		for ip in found_games.keys():
			if Time.get_ticks_msec() - found_games[ip].seen > 3500:
				found_games.erase(ip)
				changed = true
		if changed:
			games_changed.emit()


# --- Carrera ----------------------------------------------------------------

func start_race() -> void:
	if not is_host():
		return
	_loaded.clear()
	_finished.clear()
	_countdown_sent = false
	_start_race.rpc(level_index)
	get_tree().create_timer(LOAD_TIMEOUT).timeout.connect(func() -> void:
		if in_race and not _countdown_sent:
			_send_countdown()
	)


@rpc("authority", "call_local", "reliable")
func _start_race(level: int) -> void:
	level_index = level
	in_race = true
	standings.clear()
	GameState.current_level = level
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.GAME_SCENE)


## La escena de carrera avisa cuando ha cargado; al estar todos, el anfitrión da la salida.
func notify_loaded() -> void:
	_peer_loaded.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _peer_loaded() -> void:
	if not multiplayer.is_server():
		return
	_loaded[_sender()] = true
	if not _countdown_sent and _loaded.size() >= players.size():
		_send_countdown()


func _send_countdown() -> void:
	_countdown_sent = true
	_begin_countdown.rpc()


@rpc("authority", "call_local", "reliable")
func _begin_countdown() -> void:
	countdown_begin.emit()


func send_state(pos: Vector3, vel: Vector3, rot: Quaternion) -> void:
	_state.rpc(pos, vel, rot)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(pos: Vector3, vel: Vector3, rot: Quaternion) -> void:
	remote_state.emit(multiplayer.get_remote_sender_id(), pos, vel, rot)


## Anfitrión: posiciones de las canicas de acero para los demás.
func send_chasers(states: Array) -> void:
	_chasers.rpc(states)


@rpc("authority", "call_remote", "unreliable_ordered")
func _chasers(states: Array) -> void:
	chasers_state.emit(states)


func send_crumble(index: int) -> void:
	_crumble.rpc(index)


@rpc("any_peer", "call_remote", "reliable")
func _crumble(index: int) -> void:
	crumble_remote.emit(index)


## Avisa al anfitrión de que has terminado. `seconds` < 0 = no llegaste a tiempo.
func report_finish(seconds: float) -> void:
	_finish.rpc_id(1, seconds)


@rpc("any_peer", "call_local", "reliable")
func _finish(seconds: float) -> void:
	if not multiplayer.is_server():
		return
	var id := _sender()
	# Un tiempo sin sentido (NaN, infinito) desordenaría la clasificación: cuenta como no terminado.
	if not is_finite(seconds):
		seconds = -1.0
	if _finished.has(id):
		return
	_finished[id] = seconds
	_update_standings()


func _update_standings() -> void:
	var list := []
	for id in _finished:
		if players.has(id):
			list.append({id = id, name = players[id].name, time = _finished[id]})
	# Primero los que llegaron (por tiempo) y después los que no terminaron.
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (a.time < 0.0) != (b.time < 0.0):
			return b.time < 0.0
		return a.time < b.time
	)
	_sync_standings.rpc(list)
	if list.size() >= players.size():
		_race_over.rpc()


@rpc("authority", "call_local", "reliable")
func _sync_standings(list: Array) -> void:
	standings = list
	standings_changed.emit()


@rpc("authority", "call_local", "reliable")
func _race_over() -> void:
	race_over.emit()


## Anfitrión: todos vuelven a la sala.
func back_to_lobby() -> void:
	if is_host():
		_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _to_lobby() -> void:
	in_race = false
	GameState.go_to_menu("lobby")


## Puesto (1, 2, ...) de un jugador que ha llegado, o 0 si aún no ha llegado o no terminó.
func place_of(id: int) -> int:
	for i in standings.size():
		if standings[i].id == id:
			return i + 1 if standings[i].time >= 0.0 else 0
	return 0


## Texto de la clasificación para los paneles.
func standings_text() -> String:
	var lines := []
	for i in standings.size():
		var entry: Dictionary = standings[i]
		if entry.time >= 0.0:
			lines.append(tr("STANDING_FMT") % [i + 1, entry.name, entry.time])
		else:
			lines.append(tr("DNF_FMT") % entry.name)
	return "\n".join(lines)


func _sender() -> int:
	# En llamadas locales (el anfitrión a sí mismo) el remitente es 0.
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()

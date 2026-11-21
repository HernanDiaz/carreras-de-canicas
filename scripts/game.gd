extends Node3D
## Partida: carga el nivel elegido y gestiona cuenta atrás, caídas, meta, pausa y fin.
## Con Net.in_race es una carrera por Wi-Fi: salida sincronizada, canicas de los demás y clasificación.

## Distancia por debajo del punto más bajo del nivel a la que se considera caída.
const FALL_MARGIN := 8.0
## Segundos que hay que aguantar sobre la meta para ganar.
const GOAL_HOLD_TIME := 3.0
const COUNTDOWN_TIME := 3.0
## En carrera, cada jugador sale desde una esquina distinta de la salida.
const START_OFFSETS := [Vector3(-1.2, 0, 1.2), Vector3(1.2, 0, 1.2), Vector3(-1.2, 0, -1.2), Vector3(1.2, 0, -1.2)]
## Veces por segundo que se envía la posición de la canica a los demás.
const SEND_RATE := 20.0
const MARBLE_RADIUS := 0.5
## Refuerzo del empuje de las canicas de acero en carrera (ajustado para igualar al modo de un jugador).
const CHASER_PUSH_BOOST := 1.4

enum State { WAITING, COUNTDOWN, PLAYING, ENDED }

var level: Level
var state := State.COUNTDOWN
var time_left := 60.0
var elapsed := 0.0
var respawn_point := Vector3.ZERO
var race := false

var _countdown := COUNTDOWN_TIME
var _message_time := 0.0
var _goal_hold := 0.0
var _overlay: Control
var _remotes := {}
var _send_timer := 0.0
var _announced := {}
var _race_finished := false
## Modo espectador (ya has terminado y otros siguen corriendo)
var _spectating := false
var _watch_id := 0
var _spectator_hud: Array[Control] = []
var _watch_label: Label
var _standings_label: Label
## Fantasma de tu mejor vuelta (solo en partida de un jugador) y grabación de la vuelta actual.
var _ghost: Ghost
var _recorder := Ghost.Recorder.new()

@onready var marble: Marble = $Marble
@onready var camera: MarbleCamera = $Camera
@onready var hud: Control = $HUD/Root
@onready var level_label: Label = $HUD/Root/LevelLabel
@onready var time_label: Label = $HUD/Root/TimeLabel
@onready var message_label: Label = $HUD/Root/MessageLabel
@onready var debug_label: Label = $HUD/Root/DebugLabel
@onready var pause_button: Button = $HUD/Root/PauseButton
@onready var calibrate_button: Button = $HUD/Root/CalibrateButton
@onready var tilt_simulator: TiltSimulator = $HUD/Root/TiltSimulator
@onready var world_environment: WorldEnvironment = $WorldEnvironment

## Altura de la niebla bajo la canica (en la salida queda como antes, en -3.5): lo que queda
## muy por debajo se funde con el fondo.
const FOG_BELOW := 4.5
var _environment: Environment


func _ready() -> void:
	hud.theme = UI.make_theme()
	# Copia propia: la altura de la niebla cambia durante la partida (el menú usa la misma).
	_environment = world_environment.environment.duplicate()
	world_environment.environment = _environment
	UI.fit_safe_area(hud)
	race = Net.in_race
	var info: Dictionary = GameState.LEVELS[GameState.current_level]
	level = load(info.script).new()
	level.name = "Level"
	level.marble = marble
	add_child(level)
	level.build()
	level.checkpoint_reached.connect(func(pos: Vector3) -> void: respawn_point = pos)
	level.marble_killed.connect(_on_marble_killed)
	level.marble_caught.connect(func(reason: String) -> void:
		if state == State.PLAYING:
			_goal_hold = 0.0
			_show_message(tr(reason), 3.0)
	)

	time_left = info.time
	level_label.text = tr("HUD_RACE_FMT" if race else "HUD_LEVEL_FMT") % [GameState.current_level + 1, tr(info.name)]
	calibrate_button.text = tr("RECALIBRATE")

	marble.camera = camera
	marble.tilt_simulator = tilt_simulator
	marble.max_tilt_degrees = GameState.tilt_degrees
	marble.invert_x = GameState.invert_x
	marble.invert_y = GameState.invert_y
	camera.target = marble
	debug_label.visible = GameState.show_debug

	pause_button.pressed.connect(_pause)
	calibrate_button.pressed.connect(_on_calibrate_pressed)

	# La canica espera congelada en la salida hasta que acabe la cuenta atrás.
	respawn_point = level.spawn_point
	if race:
		respawn_point += START_OFFSETS[Net.my_slot() % START_OFFSETS.size()]
		_setup_race()
	elif GameState.show_ghost:
		_ghost = Ghost.load_for(GameState.current_level, (marble.get_node("Mesh") as MeshInstance3D).mesh)
		if _ghost != null:
			add_child(_ghost)
	marble.global_position = respawn_point
	marble.stop_in_place()
	camera.global_position = respawn_point + camera.offset
	camera.look_at(respawn_point, Vector3.UP)


func _process(delta: float) -> void:
	# La niebla baja contigo en los niveles que descienden mucho.
	var fog_target := camera.target.global_position.y - FOG_BELOW if camera.target != null else -FOG_BELOW
	_environment.fog_height = lerpf(_environment.fog_height, fog_target, 1.0 - exp(-2.0 * delta))
	match state:
		State.WAITING:
			_show_message(tr("WAITING_OTHERS"), 0.2)
		State.COUNTDOWN:
			_countdown -= delta
			if _countdown > 0.0:
				_show_message("%s\n%d" % [tr(GameState.LEVELS[GameState.current_level].name), ceili(_countdown)], 0.2)
			else:
				state = State.PLAYING
				marble.release()
				var show_hint := GameState.current_level == 0 and not race and not tilt_simulator.has_real_sensor()
				var hint := "\n" + tr("MOUSE_HINT") if show_hint else ""
				_show_message(tr("GO") + hint, 1.2)
		State.PLAYING:
			time_left = maxf(time_left - delta, 0.0)
			elapsed += delta
			if not race:
				_recorder.record(elapsed, marble)
				if _ghost != null:
					_ghost.seek(elapsed)
			if time_left == 0.0:
				marble.stop_in_place()
				_finish(false)
			elif marble.global_position.y < level.lowest_y - FALL_MARGIN:
				# Como en el original: caerte no quita vidas, te cuesta tiempo.
				_respawn("FELL")
			else:
				_update_goal(delta)

	time_label.text = "%.1f" % time_left
	time_label.modulate = Color.RED if time_left < 10.0 else Color.WHITE
	if debug_label.visible:
		debug_label.text = marble.debug_text()

	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			message_label.visible = false


func _physics_process(delta: float) -> void:
	if not race or state == State.WAITING:
		return
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = 1.0 / SEND_RATE
		Net.send_state(marble.global_position, marble.linear_velocity, marble.quaternion)
		if Net.is_host() and not level.chasers.is_empty():
			var states := []
			for chaser in level.chasers:
				states.append([chaser.global_position, chaser.linear_velocity, chaser.quaternion])
			Net.send_chasers(states)

	if state == State.PLAYING:
		for remote in _remotes.values():
			_bump(marble, remote.global_position, remote.velocity, marble.mass)
		if not Net.is_host():
			# Las canicas de acero son marionetas aquí: el choque con la tuya se calcula a mano.
			for chaser in level.chasers:
				_bump(marble, chaser.global_position, chaser.velocity, chaser.mass)
				_chaser_push(chaser)
	if Net.is_host():
		# El anfitrión simula las canicas de acero. Las canicas de los demás solo las apartan
		# (sin rebote): la de acero pesa más y, como en un jugador, sigue empujando.
		for chaser in level.chasers:
			for remote in _remotes.values():
				if remote.visible:
					_bump(chaser, remote.global_position, remote.velocity, marble.mass, false)


func _unhandled_input(event: InputEvent) -> void:
	# Esc en el PC (mientras está en pausa este nodo no recibe eventos; se sale con los botones)
	if event.is_action_pressed("ui_cancel") and (state != State.ENDED or race):
		_pause()
	elif _spectating and _overlay == null:
		if event.is_action_pressed("ui_left"):
			_cycle_watch(-1)
		elif event.is_action_pressed("ui_right"):
			_cycle_watch(1)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Botón "atrás" de Android
			if _overlay != null and (get_tree().paused or race):
				_resume()
			elif state != State.ENDED or (race and not _race_finished):
				_pause()
			elif not race:
				GameState.go_to_menu()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if state == State.PLAYING and not race:
				_pause()


## Hay que quedarse GOAL_HOLD_TIME segundos seguidos sobre la meta; si sales, vuelve a empezar.
func _update_goal(delta: float) -> void:
	if level.marble_on_goal:
		_goal_hold += delta
		if _goal_hold >= GOAL_HOLD_TIME:
			level.set_goal_progress(1.0)
			marble.celebrate(level.goal_center)
			_finish(true)
			return
		_show_message(tr("HOLD_FMT") % ceili(GOAL_HOLD_TIME - _goal_hold), 0.2)
	elif _goal_hold > 0.0:
		_goal_hold = 0.0
		_show_message(tr("BACK_TO_GOAL"), 1.0)
	level.set_goal_progress(_goal_hold / GOAL_HOLD_TIME)


## `reason` es la clave de traducción del aviso (FELL, ACID...).
func _respawn(reason: String) -> void:
	_goal_hold = 0.0
	marble.respawn(respawn_point)
	camera.global_position = respawn_point + camera.offset
	_show_message(tr(reason), 1.0)


func _on_marble_killed(reason: String) -> void:
	if state == State.PLAYING:
		_respawn(reason)


func _finish(won: bool) -> void:
	state = State.ENDED
	if race:
		_finish_race(won)
		return
	pause_button.disabled = true
	if won:
		var record := GameState.complete_level(GameState.current_level, elapsed, _recorder.samples)
		_show_message(tr("GOAL"), 1.3)
		var subtitle := tr("TIME_FMT") % elapsed
		if record:
			subtitle += "\n" + tr("NEW_RECORD")
		var stars := GameState.stars_for(GameState.current_level, elapsed)
		if stars < 3:
			var limits: Array = GameState.LEVELS[GameState.current_level].stars
			subtitle += "\n" + tr("NEXT_STAR_FMT") % limits[2 - stars]
		var buttons := []
		if GameState.has_next_level():
			buttons.append([tr("NEXT_LEVEL"), func() -> void: GameState.play(GameState.current_level + 1)])
		buttons.append([tr("RETRY"), _restart])
		buttons.append([tr("MENU"), GameState.go_to_menu])
		var title := tr("LEVEL_CLEARED") if GameState.has_next_level() else tr("GAME_COMPLETED")
		get_tree().create_timer(1.4).timeout.connect(func() -> void: _show_overlay(title, subtitle, buttons, UI.stars(stars, 64.0)))
	else:
		_show_message(tr("TIME_UP"), 1.2)
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			_show_overlay(tr("TIME_UP"), tr("TRY_AGAIN"), [[tr("RETRY"), _restart], [tr("MENU"), GameState.go_to_menu]])
		)


func _pause() -> void:
	if _overlay != null or (state == State.ENDED and not race) or _race_finished:
		return
	if race:
		# En carrera el juego no se puede detener: solo se ofrece salir.
		var keep := tr("KEEP_WATCHING") if _spectating else tr("KEEP_GOING")
		_show_overlay(tr("RACE_IN_PROGRESS"), tr("RACE_CONTINUES"), [[keep, _resume], [tr("LEAVE_RACE"), _leave_race]])
		return
	get_tree().paused = true
	_show_overlay(tr("PAUSE"), "", [[tr("RESUME"), _resume], [tr("RESTART_LEVEL"), _restart], [tr("MAIN_MENU"), GameState.go_to_menu]])


func _resume() -> void:
	_close_overlay()
	get_tree().paused = false
	if state == State.PLAYING:
		# Al volver puede que sujetes el móvil de otra forma.
		marble.calibrate()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- Carrera ----------------------------------------------------------------

func _setup_race() -> void:
	state = State.WAITING
	var color := Net.color_of(Net.my_id())
	var ball: MeshInstance3D = marble.get_node("Mesh")
	var material: StandardMaterial3D = (ball.mesh as SphereMesh).material.duplicate()
	material.albedo_color = color
	ball.material_override = material

	for id in Net.players:
		if id != Net.my_id():
			_add_remote(id)
	Net.remote_state.connect(_on_remote_state)
	Net.players_changed.connect(_on_players_changed)
	Net.countdown_begin.connect(_on_countdown_begin)
	Net.standings_changed.connect(_on_standings_changed)
	Net.race_over.connect(_on_race_over)
	Net.left.connect(_on_connection_lost)

	# Baldosas que se hunden: la que pisa cualquiera cae para todos.
	level.crumble_triggered.connect(Net.send_crumble)
	Net.crumble_remote.connect(level.trigger_crumble)
	# Canicas de acero: las simula el anfitrión y los demás las reciben por red.
	if not Net.is_host():
		for chaser in level.chasers:
			chaser.set_puppet()
		Net.chasers_state.connect(_on_chasers_state)
	Net.notify_loaded()


func _add_remote(id: int) -> void:
	var remote := RemoteMarble.new()
	remote.setup((marble.get_node("Mesh") as MeshInstance3D).mesh, Net.color_of(id), Net.players[id].name)
	add_child(remote)
	_remotes[id] = remote


func _on_remote_state(id: int, pos: Vector3, vel: Vector3, rot: Quaternion) -> void:
	if _remotes.has(id):
		_remotes[id].push_state(pos, vel, rot)


func _on_chasers_state(states: Array) -> void:
	for i in mini(states.size(), level.chasers.size()):
		level.chasers[i].push_state(states[i][0], states[i][1], states[i][2])


func _on_players_changed() -> void:
	for id in _remotes.keys():
		if not Net.players.has(id):
			_remotes[id].queue_free()
			_remotes.erase(id)
	if _spectating and not _remotes.has(_watch_id):
		_watch_id = _next_watch(Net.my_id(), 1, true)
		_update_watch()


func _on_countdown_begin() -> void:
	# Todos ponen el reloj del nivel a la vez para que las trampas vayan sincronizadas.
	level._time = -COUNTDOWN_TIME
	_countdown = COUNTDOWN_TIME
	state = State.COUNTDOWN


## Choque de `body` contra otra bola que no se simula aquí (canica de otro jugador o de acero),
## como bolas de billar: cada móvil calcula solo el rebote de lo que simula él.
func _bump(body: RigidBody3D, other_pos: Vector3, other_vel: Vector3, other_mass: float, bounce := true) -> void:
	var offset := body.global_position - other_pos
	var distance := offset.length()
	if distance >= MARBLE_RADIUS * 2.0 or distance < 0.001:
		return
	var normal := offset / distance
	var closing := (body.linear_velocity - other_vel).dot(normal)
	if bounce and closing < 0.0:
		# Choque elástico: cuanto más pesa la otra bola, más sale despedida esta.
		var share := 2.0 * other_mass / (body.mass + other_mass)
		body.apply_central_impulse(-closing * share * normal * body.mass)
	# Separarlas si se han metido una dentro de otra.
	body.apply_central_impulse(normal * (MARBLE_RADIUS * 2.0 - distance) * 3.0 * body.mass)


## Mientras una canica de acero (marioneta) toca la tuya, empuja con su fuerza de persecución,
## igual que haría la física si se simulara aquí. Sin esto solo rebotaría en cada choque.
func _chaser_push(chaser: Chaser) -> void:
	var offset := marble.global_position - chaser.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.001 or distance > MARBLE_RADIUS * 2.0 + 0.1:
		return
	# Un poco más de fuerza que la física local para compensar el retardo de la red.
	marble.apply_central_force(offset / distance * chaser.force * CHASER_PUSH_BOOST)


func _finish_race(won: bool) -> void:
	# La escena puede estar saliendo del árbol si el anfitrión ya ha lanzado otra carrera.
	if not is_inside_tree():
		return
	if won:
		_show_message(tr("GOAL"), 1.5)
		Net.report_finish(elapsed)
	else:
		_show_message(tr("TIME_UP"), 1.5)
		Net.report_finish(-1.0)
	# Si eras el último en llegar, la carrera termina dentro de report_finish y la escena puede cambiar ya.
	if is_inside_tree():
		get_tree().create_timer(1.5).timeout.connect(_start_spectating)


## Ya has terminado y otros siguen corriendo: la cámara pasa a seguirlos.
func _start_spectating() -> void:
	if not is_inside_tree() or _race_finished or _spectating:
		return
	_spectating = true
	var place := Net.place_of(Net.my_id())
	_show_message(tr("FINISHED_PLACE_FMT") % place if place > 0 else tr("TIME_OVER_YOU"), 2.5)
	calibrate_button.visible = false
	_build_spectator_hud()
	_watch_id = _next_watch(Net.my_id(), 1, true)
	_update_watch()


func _build_spectator_hud() -> void:
	# Abajo en el centro: < Viendo a Luis >
	var bar := PanelContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -16.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := UI.button("<", func() -> void: _cycle_watch(-1), 96.0)
	prev.focus_mode = Control.FOCUS_NONE
	row.add_child(prev)
	_watch_label = UI.label("", 30)
	_watch_label.custom_minimum_size.x = 440
	_watch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_watch_label)
	var next := UI.button(">", func() -> void: _cycle_watch(1), 96.0)
	next.focus_mode = Control.FOCUS_NONE
	row.add_child(next)
	bar.add_child(row)
	hud.add_child(bar)

	# Arriba a la derecha: clasificación en directo
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	_standings_label = UI.label("", 24)
	_standings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(_standings_label)
	hud.add_child(panel)
	_spectator_hud = [bar, panel]


## Jugadores a los que se puede mirar: los demás (por orden de sala) y tú al final.
func _watch_list() -> Array:
	var ids := _remotes.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return Net.players.get(a, {}).get("slot", 9) < Net.players.get(b, {}).get("slot", 9))
	ids.append(Net.my_id())
	return ids


func _is_racing(id: int) -> bool:
	for entry in Net.standings:
		if entry.id == id:
			return false
	return true


## Siguiente jugador en la dirección `dir`. Con only_racing, se salta a los que ya han terminado si hay alguien corriendo.
func _next_watch(from_id: int, dir: int, only_racing := false) -> int:
	var ids := _watch_list()
	var start := ids.find(from_id)
	for step in range(1, ids.size() + 1):
		var id: int = ids[posmod(start + dir * step, ids.size())]
		if not only_racing or _is_racing(id):
			return id
	return ids[posmod(start + dir, ids.size())]


func _cycle_watch(dir: int) -> void:
	_watch_id = _next_watch(_watch_id, dir)
	_update_watch()


func _update_watch() -> void:
	if not _spectating:
		return
	if _watch_id != Net.my_id() and not _remotes.has(_watch_id):
		_watch_id = Net.my_id()
	var who: String
	if _watch_id == Net.my_id():
		camera.target = marble
		who = tr("YOU")
	else:
		camera.target = _remotes[_watch_id]
		who = Net.players.get(_watch_id, {}).get("name", "?")
	var status := "" if _is_racing(_watch_id) else "  " + tr("AT_GOAL")
	_watch_label.text = tr("WATCHING_FMT") % [who, status]
	_watch_label.modulate = Net.color_of(_watch_id)
	var standings := Net.standings_text()
	_standings_label.text = tr("STANDINGS") + "\n" + (standings if standings != "" else tr("NOBODY_YET"))


func _on_standings_changed() -> void:
	# La escena puede estar saliendo del árbol si el anfitrión ya ha lanzado otra carrera.
	if not is_inside_tree():
		return
	# Avisar cuando otro jugador llega a la meta.
	for entry in Net.standings:
		if entry.id != Net.my_id() and entry.time >= 0.0 and not _announced.has(entry.id):
			_announced[entry.id] = true
			if state == State.PLAYING:
				_show_message(tr("PLAYER_FINISHED_FMT") % entry.name, 2.0)
	if _spectating:
		# Si el jugador que miras acaba de terminar, pasar a otro que siga corriendo.
		if not _is_racing(_watch_id) and _watch_id != Net.my_id():
			var next := _next_watch(_watch_id, 1, true)
			if _is_racing(next):
				_watch_id = next
		_update_watch()


func _on_race_over() -> void:
	# La escena puede estar saliendo del árbol si el anfitrión ya ha lanzado otra carrera.
	if not is_inside_tree():
		return
	_race_finished = true
	_spectating = false
	for control in _spectator_hud:
		control.queue_free()
	_spectator_hud.clear()
	camera.target = marble
	var buttons := []
	var subtitle := Net.standings_text()
	if Net.is_host():
		buttons.append([tr("REMATCH"), func() -> void: Net.start_race()])
		if GameState.current_level + 1 < GameState.LEVELS.size():
			buttons.append([tr("NEXT_LEVEL"), func() -> void:
				Net.select_level(GameState.current_level + 1)
				Net.start_race()
			])
		buttons.append([tr("BACK_TO_LOBBY"), Net.back_to_lobby])
	else:
		subtitle += "\n\n" + tr("HOST_CHOOSING")
	buttons.append([tr("LEAVE"), _leave_race])
	# Esperar a que termine la celebración de quien acaba de llegar.
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		_show_overlay(tr("STANDINGS"), subtitle, buttons)
		_overlay.set_meta("final", true)
	)


func _leave_race() -> void:
	Net.leave()
	GameState.go_to_menu("multi")


func _on_connection_lost(reason: String) -> void:
	# La escena puede estar saliendo del árbol si el anfitrión ya ha lanzado otra carrera.
	if not is_inside_tree():
		return
	state = State.ENDED
	marble.stop_in_place()
	_show_overlay(tr("CONNECTION_LOST"), tr(reason), [[tr("MENU"), func() -> void: GameState.go_to_menu("multi")]])
	_overlay.set_meta("final", true)


# --- Interfaz -----------------------------------------------------------------

func _show_overlay(title: String, subtitle: String, buttons: Array, extra: Control = null) -> void:
	_close_overlay()
	message_label.visible = false
	_message_time = 0.0
	_overlay = UI.overlay(title, subtitle, buttons, extra)
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_overlay)


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _on_calibrate_pressed() -> void:
	marble.calibrate()
	_show_message(tr("CALIBRATED"), 0.8)


## Duración 0 = el mensaje se queda en pantalla.
func _show_message(text: String, duration: float) -> void:
	message_label.text = text
	message_label.visible = true
	_message_time = duration

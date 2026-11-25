extends Node3D
## Menú principal con fondo 3D animado: portada, selección de nivel, carrera Wi-Fi y opciones.

var _screens := {}
var _current := ""
var _t := 0.0
var _marble_visual: MeshInstance3D
var _level_grid: GridContainer
var _suggested_card: Button
var _stars_total: Label
var _ranking_button: Button
var _achievements_button: Button
var _reset_button: Button
var _reset_armed := false
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _net_status: Label
var _games_list: VBoxContainer
var _lobby_info: Label
var _lobby_players: VBoxContainer
var _lobby_level: Label
var _level_prev: Button
var _level_next: Button
var _start_button: Button
var _waiting_box: HBoxContainer
var _waiting_label: Label

@onready var ui_root: Control = $UI/Root
@onready var pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera


func _ready() -> void:
	ui_root.theme = UI.make_theme()
	UI.fit_safe_area(ui_root)
	_build_background()
	camera.look_at(pivot.global_position, Vector3.UP)

	Audio.play_music("menu")
	_screens.main = _build_main()
	_screens.levels = _build_levels()
	_screens.ranking = _build_ranking()
	_screens.options = _build_options()
	_screens.multi = _build_multi()
	_screens.lobby = _build_lobby()
	for screen in _screens.values():
		ui_root.add_child(screen)

	Net.games_changed.connect(func() -> void:
		if _current == "multi":
			_refresh_games()
	)
	Net.players_changed.connect(func() -> void:
		if _current == "lobby":
			_refresh_lobby()
	)
	# Puede llegar progreso de la nube (otro aparato) con el menú abierto.
	GameState.progress_changed.connect(func() -> void:
		if _current == "levels":
			_fill_level_grid()
	)
	GameServices.availability_changed.connect(func() -> void:
		_ranking_button.visible = GameServices.available()
		_achievements_button.visible = GameServices.available()
	)
	Net.joined.connect(func() -> void: _show("lobby"))
	Net.left.connect(func(reason: String) -> void:
		_show("multi")
		_net_status.text = tr(reason)
	)

	var screen: String = GameState.open_screen
	if screen == "lobby" and not Net.is_online():
		screen = "multi"
	_show(screen if _screens.has(screen) else "main")
	GameState.open_screen = ""


func _process(delta: float) -> void:
	_t += delta
	pivot.rotation.y = _t * 0.1
	# Canica decorativa dando vueltas por la plataforma
	var angle := _t * 0.8
	_marble_visual.position = Vector3(cos(angle) * 3.0, 0.5, sin(angle) * 3.0)
	_marble_visual.basis = Basis(Vector3(cos(angle), 0, sin(angle)), -angle * 3.0 / 0.5)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and _current == "options":
		# Si se cierra o se manda al fondo la app con las opciones abiertas, no perderlas.
		GameState.save_data()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current == "main":
			get_tree().quit()
		elif _current == "lobby":
			_leave_lobby()
		elif _current == "ranking":
			_show("levels")
		else:
			_show("main")


func _show(screen_name: String) -> void:
	# Las opciones se guardan al salir de la pantalla, sea con "Volver" o con el botón atrás.
	if _current == "options" and screen_name != "options":
		GameState.save_data()
	if _current == "multi" and screen_name != "multi":
		Net.stop_discovery()
	if screen_name == "multi":
		_net_status.text = ""
		Net.start_discovery()
		_refresh_games()
	if screen_name == "lobby":
		_refresh_lobby()
	if screen_name == "levels":
		_fill_level_grid()
	if screen_name == "options":
		_reset_armed = false
		_reset_button.text = tr("RESET_PROGRESS")
	for key in _screens:
		_screens[key].visible = key == screen_name
	_current = screen_name
	var first := _first_button(_screens[screen_name])
	if screen_name == "levels" and _suggested_card != null:
		first = _suggested_card
	if first != null:
		first.grab_focus()


# --- Pantallas --------------------------------------------------------------

func _build_main() -> Control:
	var box := _screen_box()
	var title := tr("GAME_TITLE").to_upper()
	box.add_child(UI.label(title, 92 if title.length() <= 18 else 76, UI.C_ACCENT))
	box.add_child(UI.spacer(24))
	box.add_child(UI.button(tr("MENU_PLAY"), func() -> void: _show("levels")))
	box.add_child(UI.button(tr("MENU_WIFI"), func() -> void: _show("multi")))
	box.add_child(UI.button(tr("MENU_OPTIONS"), func() -> void: _show("options")))
	# En iOS las apps no pueden cerrarse solas (norma de la App Store): sin botón Salir.
	if OS.get_name() != "iOS":
		box.add_child(UI.button(tr("MENU_QUIT"), func() -> void: get_tree().quit()))
	box.add_child(UI.spacer(8))
	var lang := UI.button(_language_text(), _on_language_pressed, 380.0)
	lang.theme_type_variation = UI.SECONDARY
	lang.custom_minimum_size.y = 60
	lang.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(lang)
	return box.get_parent()


func _build_levels() -> Control:
	var box := _screen_box()
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 12)
	title_row.add_child(UI.label(tr("CHOOSE_LEVEL"), 56, UI.C_ACCENT))
	title_row.add_child(UI.spacer(0))
	var star := UI.stars(1, 40.0, 1)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(star)
	_stars_total = UI.label("", 34, UI.C_STAR)
	title_row.add_child(_stars_total)
	box.add_child(title_row)
	_level_grid = GridContainer.new()
	_level_grid.columns = 3
	_level_grid.add_theme_constant_override("h_separation", 16)
	_level_grid.add_theme_constant_override("v_separation", 16)
	box.add_child(_level_grid)
	box.add_child(UI.spacer(8))
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	bottom_row.add_child(UI.button(tr("BACK"), func() -> void: _show("main"), 300.0))
	# Solo si hay clasificaciones y logros en este aparato (Game Center / Play Juegos).
	_ranking_button = UI.button(tr("WORLD_RANKING"), func() -> void: _show("ranking"), 300.0)
	_ranking_button.visible = GameServices.available()
	bottom_row.add_child(_ranking_button)
	_achievements_button = UI.button(tr("ACHIEVEMENTS"), GameServices.show_achievements, 300.0)
	_achievements_button.visible = GameServices.available()
	bottom_row.add_child(_achievements_button)
	box.add_child(bottom_row)
	return box.get_parent()


## Elige de qué nivel ver la clasificación mundial (se abre la pantalla del sistema).
func _build_ranking() -> Control:
	var box := _screen_box()
	var title := UI.label(tr("WORLD_RANKING"), 56, UI.C_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for i in GameState.LEVELS.size():
		var index := i
		var card := UI.button("%d. %s" % [i + 1, tr(GameState.LEVELS[i].name)], func() -> void: GameServices.show_level(index), 330.0)
		card.custom_minimum_size.y = 110
		card.add_theme_font_size_override("font_size", 26)
		grid.add_child(card)
	box.add_child(grid)
	box.add_child(UI.spacer(8))
	var back := UI.button(tr("BACK"), func() -> void: _show("levels"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	return box.get_parent()


func _fill_level_grid() -> void:
	for child in _level_grid.get_children():
		child.queue_free()
	# Nivel sugerido (el foco empieza en él): el primero desbloqueado sin superar o, si están
	# todos superados, el último que se jugó.
	var suggested := GameState.current_level
	for i in GameState.LEVELS.size():
		if GameState.is_unlocked(i) and not GameState.best_times.has(i):
			suggested = i
			break
	_suggested_card = null
	for i in GameState.LEVELS.size():
		var info: Dictionary = GameState.LEVELS[i]
		var detail: String
		if not GameState.is_unlocked(i):
			detail = tr("LOCKED")
		elif GameState.best_times.has(i):
			detail = tr("RECORD_FMT") % GameState.best_times[i]
		else:
			detail = tr("NOT_COMPLETED")
		var index := i
		var card := UI.button("%d. %s\n%s" % [i + 1, tr(info.name), detail], func() -> void: GameState.play(index), 330.0)
		card.custom_minimum_size.y = 130
		card.add_theme_font_size_override("font_size", 26)
		card.disabled = not GameState.is_unlocked(i)
		if GameState.is_unlocked(i):
			# Estrellas en la esquina de arriba a la derecha de la tarjeta.
			var stars := UI.stars(GameState.stars_of(i), 22.0)
			stars.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			stars.offset_left = -84.0
			stars.offset_top = 8.0
			stars.offset_right = -10.0
			stars.offset_bottom = 30.0
			card.add_child(stars)
			if i == suggested:
				_suggested_card = card
		_level_grid.add_child(card)
	_stars_total.text = "%d / %d" % [GameState.total_stars(), GameState.LEVELS.size() * 3]


func _build_options() -> Control:
	var box := _screen_box()
	# Muchas opciones: menos separación para que quepan en la altura de un móvil.
	box.add_theme_constant_override("separation", 8)
	box.add_child(UI.label(tr("MENU_OPTIONS"), 56, UI.C_ACCENT))

	var tilt_label := UI.label("", 28)
	var slider := HSlider.new()
	slider.min_value = 10
	slider.max_value = 35
	slider.step = 1
	slider.value = GameState.tilt_degrees
	slider.custom_minimum_size = Vector2(440, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var refresh := func() -> void:
		var mode := tr("OPT_AUTO_MODE") if not GameState.tilt_custom else tr("OPT_MANUAL_MODE")
		tilt_label.text = tr("OPT_TILT_FMT") % [int(GameState.tilt_degrees), mode]
	refresh.call()
	# Mover el deslizador fija el valor; "Auto" vuelve al recomendado para este aparato.
	var setting := {auto = false}
	slider.value_changed.connect(func(value: float) -> void:
		GameState.tilt_degrees = value
		GameState.tilt_custom = not setting.auto
		refresh.call()
	)
	var auto := UI.button(tr("OPT_AUTO"), func() -> void:
		setting.auto = true
		slider.value = GameState.default_tilt()
		setting.auto = false
		GameState.tilt_custom = false
		refresh.call()
	, 110.0)
	auto.theme_type_variation = UI.SECONDARY
	auto.custom_minimum_size.y = 56
	var tilt_row := HBoxContainer.new()
	tilt_row.add_theme_constant_override("separation", 16)
	tilt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tilt_row.add_child(slider)
	tilt_row.add_child(auto)
	box.add_child(tilt_label)
	box.add_child(tilt_row)

	box.add_child(_check(tr("OPT_INVERT_X"), GameState.invert_x,
		func(on: bool) -> void: GameState.invert_x = on))
	box.add_child(_check(tr("OPT_INVERT_Y"), GameState.invert_y,
		func(on: bool) -> void: GameState.invert_y = on))
	box.add_child(_check(tr("OPT_GHOST"), GameState.show_ghost,
		func(on: bool) -> void: GameState.show_ghost = on))
	box.add_child(_check(tr("OPT_SENSOR"), GameState.show_debug,
		func(on: bool) -> void: GameState.show_debug = on))
	# Música, sonidos y vibración en una fila (más estrechos) para no alargar la pantalla.
	var sound_row := HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 12)
	sound_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sound_row.add_child(_check(tr("OPT_MUSIC"), GameState.music_on, func(on: bool) -> void:
		GameState.music_on = on
		Audio.apply_settings()
	, 260.0))
	sound_row.add_child(_check(tr("OPT_SOUND"), GameState.sound_on, func(on: bool) -> void:
		GameState.sound_on = on
		Audio.apply_settings()
	, 260.0))
	sound_row.add_child(_check(tr("OPT_VIBRATION"), GameState.vibration_on, func(on: bool) -> void:
		GameState.vibration_on = on
		Audio.vibrate(40)
	, 260.0))
	box.add_child(sound_row)

	# Los dos últimos botones van en fila para que la pantalla quepa en la altura de un móvil.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_reset_button = UI.button(tr("RESET_PROGRESS"), _on_reset_pressed, 272.0)
	_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_reset_button)
	var back := UI.button(tr("BACK"), func() -> void: _show("main"), 272.0)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	box.add_child(row)
	return box.get_parent()


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = tr("CONFIRM_AGAIN")
		return
	GameState.reset_progress()
	_reset_armed = false
	_reset_button.text = tr("PROGRESS_RESET")


func _language_text() -> String:
	var text := tr("LANGUAGE") + ": "
	if GameState.language == "":
		text += "%s (%s)" % [tr("LANGUAGE_AUTO"), tr("LANGUAGE_NAME")]
	else:
		text += tr("LANGUAGE_NAME")
	# Para quien no entienda el idioma actual, "Language" siempre aparece en inglés.
	if not TranslationServer.get_locale().begins_with("en"):
		text += "  ·  Language"
	return text


func _on_language_pressed() -> void:
	GameState.cycle_language()
	GameState.open_screen = "main"
	# Reconstruir el menú con los textos en el idioma nuevo.
	get_tree().reload_current_scene()


# --- Carrera Wi-Fi --------------------------------------------------------------

func _build_multi() -> Control:
	var box := _screen_box()
	box.add_child(UI.label(tr("MENU_WIFI"), 56, UI.C_ACCENT))

	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 16)
	_name_edit = _line_edit(GameState.player_name, tr("YOUR_NAME"))
	_name_edit.max_length = 16
	_name_edit.text_changed.connect(func(text: String) -> void: GameState.player_name = text.strip_edges())
	host_row.add_child(_name_edit)
	host_row.add_child(UI.button(tr("CREATE_GAME"), _on_host_pressed, 300.0))
	box.add_child(host_row)

	box.add_child(UI.label(tr("GAMES_ON_NETWORK"), 26, UI.C_MUTED))
	_games_list = VBoxContainer.new()
	_games_list.add_theme_constant_override("separation", 10)
	box.add_child(_games_list)

	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 16)
	_ip_edit = _line_edit("", tr("HOST_IP"))
	ip_row.add_child(_ip_edit)
	ip_row.add_child(UI.button(tr("JOIN_BY_IP"), func() -> void: _join(_ip_edit.text.strip_edges()), 300.0))
	box.add_child(ip_row)

	_net_status = UI.label("", 24, Color(1.0, 0.75, 0.5))
	box.add_child(_net_status)
	var back := UI.button(tr("BACK"), func() -> void:
		GameState.save_data()
		_show("main")
	)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	return box.get_parent()


func _refresh_games() -> void:
	for child in _games_list.get_children():
		child.queue_free()
	if Net.found_games.is_empty():
		_games_list.add_child(UI.label(tr("SEARCHING"), 24, UI.C_MUTED))
		return
	for ip in Net.found_games:
		var game: Dictionary = Net.found_games[ip]
		var full: bool = game.players >= Net.MAX_PLAYERS
		var text := tr("JOIN_GAME_FMT") % [game.name, game.players, Net.MAX_PLAYERS]
		var b := UI.button(text, func() -> void: _join(ip), 616.0)
		b.disabled = full
		_games_list.add_child(b)


func _on_host_pressed() -> void:
	GameState.save_data()
	if Net.host(_player_name()) != OK:
		_net_status.text = tr("HOST_FAILED")
		return
	_show("lobby")


func _join(ip: String) -> void:
	if not ip.is_valid_ip_address():
		_net_status.text = tr("INVALID_IP")
		return
	GameState.save_data()
	if Net.join(ip, _player_name()) != OK:
		_net_status.text = tr("CONNECT_FAILED")
		return
	_net_status.text = tr("CONNECTING_FMT") % ip


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else tr("DEFAULT_PLAYER")


func _build_lobby() -> Control:
	var box := _screen_box()
	# Dentro de un panel para que la lista de jugadores se lea sobre el fondo animado.
	var center := box.get_parent()
	center.remove_child(box)
	var panel := PanelContainer.new()
	center.add_child(panel)
	panel.add_child(box)
	box.add_child(UI.label(tr("LOBBY_TITLE"), 52, UI.C_ACCENT))
	_lobby_info = UI.label("", 24, UI.C_MUTED)
	box.add_child(_lobby_info)
	_lobby_players = VBoxContainer.new()
	box.add_child(_lobby_players)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_level_prev = UI.button("<", func() -> void: Net.select_level(Net.level_index - 1), 88.0)
	_lobby_level = UI.label("", 30)
	_lobby_level.custom_minimum_size.x = 440
	_level_next = UI.button(">", func() -> void: Net.select_level(Net.level_index + 1), 88.0)
	level_row.add_child(_level_prev)
	level_row.add_child(_lobby_level)
	level_row.add_child(_level_next)
	box.add_child(level_row)

	# Invitados: espera bien visible, con un reloj animado.
	_waiting_box = HBoxContainer.new()
	_waiting_box.add_theme_constant_override("separation", 20)
	_waiting_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_waiting_box.add_child(WaitSpinner.new())
	_waiting_label = UI.label("", 34, UI.C_ACCENT)
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_waiting_box.add_child(_waiting_label)
	box.add_child(_waiting_box)

	_start_button = UI.button(tr("START_RACE"), func() -> void: Net.start_race(), 420.0)
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_start_button)
	# Salir es discreto y pide confirmación para no hacerlo sin querer.
	box.add_child(UI.confirm_button(tr("LEAVE_LOBBY"), tr("LEAVE_CONFIRM"), _leave_lobby))
	return center


func _refresh_lobby() -> void:
	var host := Net.is_host()
	if host:
		var ips := Net.local_ips()
		_lobby_info.text = tr("LOBBY_HOST_IP_FMT") % (", ".join(ips.slice(0, 2)) if not ips.is_empty() else tr("UNKNOWN"))
	else:
		_lobby_info.text = tr("LOBBY_JOINED")
		_waiting_label.text = tr("WAITING_HOST_FMT") % Net.players.get(1, {}).get("name", "?")
	_waiting_box.visible = not host

	for child in _lobby_players.get_children():
		child.queue_free()
	var ids := Net.players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return Net.players[a].slot < Net.players[b].slot)
	for id in ids:
		var suffix := "  " + tr("HOST_TAG") if id == 1 else ""
		if id == Net.my_id():
			suffix += "  " + tr("YOU_TAG")
		_lobby_players.add_child(UI.label("●  " + Net.players[id].name + suffix, 28, Net.color_of(id)))
	for i in Net.MAX_PLAYERS - ids.size():
		_lobby_players.add_child(UI.label("·  " + tr("FREE_SLOT"), 28, UI.C_MUTED))

	var info: Dictionary = GameState.LEVELS[Net.level_index]
	_lobby_level.text = tr("LEVEL_FMT" if host else "RACE_LEVEL_FMT") % [Net.level_index + 1, tr(info.name)]
	_level_prev.visible = host
	_level_next.visible = host
	_start_button.visible = host


func _leave_lobby() -> void:
	Net.leave()
	_show("multi")


# --- Utilidades -------------------------------------------------------------

func _line_edit(text: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(300, 88)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return edit


## Crea una pantalla centrada y devuelve su VBox (la pantalla es su padre).
func _screen_box() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	return box


## Botón de activar/desactivar que muestra "Sí"/"No" (más claro en pantalla táctil que una casilla).
func _check(text: String, value: bool, on_toggled: Callable, min_width := 560.0) -> Button:
	var toggle := UI.button("", func() -> void: pass, min_width)
	toggle.custom_minimum_size.y = 68
	toggle.toggle_mode = true
	toggle.button_pressed = value
	var refresh := func(on: bool) -> void:
		toggle.text = "%s:  %s" % [text, tr("YES") if on else tr("NO")]
	refresh.call(value)
	toggle.toggled.connect(func(on: bool) -> void:
		refresh.call(on)
		on_toggled.call(on)
	)
	return toggle


func _first_button(node: Node) -> BaseButton:
	for child in node.get_children():
		if child is BaseButton and not child.disabled:
			return child
		var found := _first_button(child)
		if found != null:
			return found
	return null


## Pequeño circuito decorativo que se ve detrás del menú.
func _build_background() -> void:
	var decor := Level.new()
	add_child(decor)
	decor.add_platform(Vector3(0, 0, 0), Vector3(10, 2, 10))
	decor.add_spinner(Vector3(0, 0, 0), 3.4, 60.0, 2)
	for corner in [Vector3(-3.8, 0, -3.8), Vector3(3.8, 0, -3.8), Vector3(-3.8, 0, 3.8), Vector3(3.8, 0, 3.8)]:
		decor.add_bumper(corner)
	decor.add_ramp(Vector3(0, 0, -5), Vector3(0, -3, -12), 3.0)
	decor.add_platform(Vector3(0, -3, -16), Vector3(8, 2, 8), Level.S_ICE)
	decor.add_patroller(Vector3(-3, -3, -16), Vector3(3, -3, -16), 3.0)
	decor.add_block(Vector3(8, 0, 0), Vector3(6, 1, 2), Level.S_BRIDGE)
	decor.add_platform(Vector3(15, 0, 0), Vector3(8, 2, 8))
	decor.add_goal(Vector3(15, 0, 0))

	var marble_scene: Node = load("res://scenes/marble.tscn").instantiate()
	_marble_visual = MeshInstance3D.new()
	_marble_visual.mesh = marble_scene.get_node("Mesh").mesh
	marble_scene.free()
	add_child(_marble_visual)

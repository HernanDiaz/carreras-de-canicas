extends Node
## Prueba rápida de todos los niveles (no se exporta: tools/ está excluido).
## Carga cada nivel, espera a que acabe la cuenta atrás y comprueba que la canica está apoyada
## en la salida y no se cae. Imprime "SMOKE OK" o "SMOKE FAIL ..." y sale con código 0 o 1.
##
## Uso: Godot --headless --path . --fixed-fps 60 res://tools/smoke_test.tscn

const GAME_SCENE := preload("res://scenes/game.tscn")
const FRAMES_AFTER_GO := 90

var _failures: Array[String] = []


func _ready() -> void:
	# Nada de lo que pase en la prueba se guarda: el progreso del jugador queda intacto.
	GameState.persist = false
	GameState.show_ghost = false
	_check_cloud_merge()
	_check_ghost()
	_check_camera_lead()
	_check_wasd()
	_check_stick()
	_check_bad_save()
	_check_suggested()
	_check_bad_options()
	_check_bad_ghost()
	_check_voices()
	_check_rumble()
	_check_beacon()
	_check_net_state()
	_check_unknown_level()
	_check_service_ids()
	await _check_respawn_protection()
	await _check_speed_trail()
	_check_catapult_aim()
	await _check_coaster_routes()
	await _check_overlay_fits()
	await _check_menu_fits()
	for i in GameState.LEVELS.size():
		# Estrellas con sentido: 3 estrellas exige menos tiempo que 2, y ambas caben en el límite.
		var info: Dictionary = GameState.LEVELS[i]
		if not (0.0 < info.stars[0] and info.stars[0] < info.stars[1] and info.stars[1] < info.time):
			_failures.append("nivel %d: estrellas %s no encajan con el límite %s" % [i + 1, info.stars, info.time])
		await _check_level(i)
	await _check_endings()
	if _failures.is_empty():
		print("SMOKE OK (%d niveles)" % GameState.LEVELS.size())
	else:
		for failure in _failures:
			print("SMOKE FAIL ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


## La pantalla de fin de nivel más cargada (4 botones, estrellas y 3 líneas) cabe en 1280x720,
## en todos los idiomas.
func _check_overlay_fits() -> void:
	var holder := Control.new()
	holder.theme = UI.make_theme()
	holder.size = Vector2(1280, 720)
	add_child(holder)
	for locale in TranslationServer.get_loaded_locales():
		TranslationServer.set_locale(locale)
		var subtitle := "%s   ·   %s\n%s  (-0.84)\n%s" % [tr("TIME_FMT") % 123.4, tr("FALLS_FMT") % 12,
			tr("NEW_RECORD"), tr("NEXT_STAR_FMT") % 45.0]
		var buttons := []
		for key in ["NEXT_LEVEL", "RETRY", "WORLD_RANKING", "MENU"]:
			buttons.append([tr(key), func() -> void: pass])
		var overlay := UI.overlay(tr("LEVEL_CLEARED"), subtitle, buttons, UI.stars(3, 64.0))
		holder.add_child(overlay)
		await get_tree().process_frame
		var panel: Control = overlay.get_child(1).get_child(0)
		var need := panel.get_combined_minimum_size()
		if need.y > 720.0 or need.x > 1280.0:
			_failures.append("pantalla de fin de nivel (%s) mide %s y no cabe en 1280x720" % [locale, need])
		overlay.free()
		# Tiempo agotado: 3 botones en una columna, sin estrellas, y el récord con la siguiente estrella.
		subtitle = "%s
%s
%s" % [tr("TRY_AGAIN"), tr("RECORD_FMT") % 123.4, tr("NEXT_STAR_FMT") % 45.0]
		overlay = UI.overlay(tr("TIME_UP"), subtitle, buttons.slice(1))
		holder.add_child(overlay)
		await get_tree().process_frame
		panel = overlay.get_child(1).get_child(0)
		need = panel.get_combined_minimum_size()
		if need.y > 720.0 or need.x > 1280.0:
			_failures.append("pantalla de tiempo agotado (%s) mide %s y no cabe en 1280x720" % [locale, need])
		overlay.free()
		# Pausa: nombre del nivel (todos), récord y siguiente estrella, con 3 botones.
		for i in GameState.LEVELS.size():
			subtitle = "%d. %s
%s
%s" % [i + 1, tr(GameState.LEVELS[i].name), tr("RECORD_FMT") % 123.4,
				tr("NEXT_STAR_FMT") % 45.0]
			var pause_buttons := []
			for key in ["RESUME", "RESTART_LEVEL", "MAIN_MENU"]:
				pause_buttons.append([tr(key), func() -> void: pass])
			overlay = UI.overlay(tr("PAUSE"), subtitle, pause_buttons)
			holder.add_child(overlay)
			await get_tree().process_frame
			panel = overlay.get_child(1).get_child(0)
			need = panel.get_combined_minimum_size()
			if need.y > 720.0 or need.x > 1280.0:
				_failures.append("pausa del nivel %d (%s) mide %s y no cabe en 1280x720" % [i + 1, locale, need])
			overlay.free()
	GameState.apply_language()
	holder.free()


## Todas las pantallas del menú caben en 1280x720 en todos los idiomas (con los botones de
## clasificación y logros visibles, el caso más ancho).
func _check_menu_fits() -> void:
	var menu_scene: PackedScene = load("res://scenes/menu.tscn")
	for locale in TranslationServer.get_loaded_locales():
		TranslationServer.set_locale(locale)
		var menu: Node = menu_scene.instantiate()
		add_child(menu)
		menu._ranking_button.visible = true
		menu._achievements_button.visible = true
		menu._continue_button.visible = true
		menu._continue_button.text = tr("CONTINUE_FMT") % 9
		# El aviso más largo de la pantalla de Wi-Fi.
		menu._net_status.text = tr("NET_VERSION_MISMATCH")
		# Elegir nivel con dos estados: todo bloqueado/sin superar, y todo con récord.
		var saved := [GameState.best_times.duplicate(), GameState.unlocked]
		for full in [false, true]:
			GameState.unlocked = GameState.LEVELS.size() if full else 2
			GameState.best_times = {}
			if full:
				for i in GameState.LEVELS.size():
					GameState.best_times[i] = 123.4
			menu._fill_level_grid()
			menu._fill_ranking_grid()
			# Con más de 9 niveles salen flechas y puntos de página: también tienen que caber.
			for pager: Dictionary in menu._pagers:
				for node: Control in [pager.prev, pager.next, pager.dots]:
					node.visible = true
				pager.dots.text = "●  ○  ○"
			await get_tree().process_frame
			for screen_name: String in menu._screens:
				var screen: Control = menu._screens[screen_name]
				var need := (screen.get_child(0) as Control).get_combined_minimum_size()
				if need.y > 720.0 or need.x > 1280.0:
					_failures.append("menú %s (%s) mide %s y no cabe en 1280x720" % [screen_name, locale, need])
		GameState.best_times = saved[0]
		GameState.unlocked = saved[1]
		if locale == TranslationServer.get_loaded_locales()[0]:
			# Esc / B del mando: de Clasificación a Elegir nivel, de ahí al principal, y ahí nada.
			var cancel := InputEventAction.new()
			cancel.action = "ui_cancel"
			cancel.pressed = true
			var path := []
			menu._show("ranking")
			for _i in 3:
				menu._unhandled_input(cancel)
				path.append(menu._current)
			if path != ["levels", "main", "main"]:
				_failures.append("menú: Esc va por %s (debe levels, main, main)" % [path])
			# Teclas 1-9 en Elegir nivel: solo niveles desbloqueados, sin eco ni otras teclas.
			var saved_unlocked := GameState.unlocked
			GameState.unlocked = 2
			var got := []
			for c in [[KEY_1, false], [KEY_2, false], [KEY_3, false], [KEY_KP_2, false], [KEY_1, true], [KEY_A, false]]:
				var k := InputEventKey.new()
				k.physical_keycode = c[0]
				k.pressed = true
				k.echo = c[1]
				got.append(menu._level_for_key(k))
			GameState.unlocked = saved_unlocked
			if got != [0, 1, -1, 1, -1, -1]:
				_failures.append("menú: teclas de nivel dan %s (debe [0, 1, -1, 1, -1, -1])" % [got])
			# Páginas de 9 niveles.
			var pages := [menu.page_count(0), menu.page_count(9), menu.page_count(10), menu.page_count(18),
				menu.page_count(19), menu.page_of(8), menu.page_of(9), menu.page_range(1, 12), menu.page_range(0, 9)]
			if str(pages) != str([1, 1, 2, 2, 3, 0, 1, [9, 12], [0, 9]]):
				_failures.append("menú: cálculo de páginas %s" % [pages])
			var steps := []
			for c in [[JOY_BUTTON_LEFT_SHOULDER, 0], [JOY_BUTTON_RIGHT_SHOULDER, 0], [-1, KEY_PAGEUP], [-1, KEY_PAGEDOWN], [-1, KEY_A]]:
				var ev: InputEvent
				if c[0] >= 0:
					ev = InputEventJoypadButton.new()
					ev.button_index = c[0]
				else:
					ev = InputEventKey.new()
					ev.physical_keycode = c[1]
				ev.pressed = true
				steps.append(menu._page_step(ev))
			if steps != [-1, 1, -1, 1, 0]:
				_failures.append("menú: LB/RB y Re Pág/Av Pág dan %s" % [steps])
			# Con los 9 niveles de ahora: una página, sin flechas, con los 9 en las dos pantallas.
			menu._show("levels")
			menu._set_page(1)
			var cards: int = menu._level_grid.get_child_count()
			var ranking_cards: int = menu._ranking_grid.get_child_count()
			var arrows: bool = menu._pagers[0].prev.visible
			if GameState.LEVELS.size() > 9:
				# Página 2: los niveles del 10 en adelante, con flechas; la tecla 1 es el nivel 10.
				var saved_pages := [GameState.unlocked, menu._level_page]
				GameState.unlocked = GameState.LEVELS.size()
				var wanted := mini(GameState.LEVELS.size() - 9, 9)
				var page2: Array = [menu._level_page, cards, menu._pagers[0].prev.disabled, menu._pagers[0].next.disabled,
					menu._pagers[0].dots.text]
				var key1 := InputEventKey.new()
				key1.physical_keycode = KEY_1
				key1.pressed = true
				page2.append(menu._level_for_key(key1))
				if page2[0] != 1 or page2[1] != wanted or page2[2] or not arrows or page2[5] != 9:
					_failures.append("menú: página 2 = %s, flechas %s" % [page2, arrows])
				menu._set_page(0)
				if menu._level_grid.get_child_count() != 9 or not menu._pagers[0].prev.disabled:
					_failures.append("menú: al volver a la página 1 hay %d tarjetas" % menu._level_grid.get_child_count())
				# Actualización con niveles nuevos: el 10 sale con "¡Nuevo!" solo la primera vez.
				var saved_seen := GameState.levels_seen
				GameState.levels_seen = 9
				menu._show("levels")
				menu._set_page(1)
				var badge_first: bool = menu._level_grid.get_child(0).has_node("NewBadge")
				var seen_after := GameState.levels_seen
				menu._show("levels")
				menu._set_page(1)
				var badge_again: bool = menu._level_grid.get_child(0).has_node("NewBadge")
				if not badge_first or badge_again or seen_after != GameState.LEVELS.size():
					_failures.append("menú: marca de nivel nuevo: primera vez %s, otra vez %s, vistos %d"
						% [badge_first, badge_again, seen_after])
				GameState.levels_seen = saved_seen
				menu._set_page(0)
				GameState.unlocked = saved_pages[0]
			if GameState.LEVELS.size() <= 9 and (menu._level_page != 0 or cards != GameState.LEVELS.size()
					or ranking_cards != GameState.LEVELS.size() or arrows):
				_failures.append("menú: con %d niveles, página %d, %d tarjetas (%d en clasificación), flechas %s"
					% [GameState.LEVELS.size(), menu._level_page, cards, ranking_cards, arrows])
			# Intro en el campo de IP intenta unirse (con una IP mala solo avisa; no conecta).
			menu._net_status.text = ""
			menu._ip_edit.text_submitted.emit(" no es una ip ")
			if menu._net_status.text != tr("INVALID_IP"):
				_failures.append("menú: Intro en el campo de IP no hace nada")
		menu.free()
	GameState.apply_language()


## Pantallas de final: superar el nivel 1 dos veces (la segunda sin batir el récord) y agotar
## el tiempo. Comprueba que salen los textos y botones esperados. Nada se guarda (persist=false).
func _check_endings() -> void:
	var gs := GameState
	var saved := [gs.best_times.duplicate(), gs.unlocked, gs.achievements.duplicate()]
	gs.best_times = {}
	gs.unlocked = 1
	for attempt in ["primera", "sin récord", "tiempo"]:
		gs.current_level = 0
		var game: Node = GAME_SCENE.instantiate()
		add_child(game)
		while game.state != game.State.PLAYING:
			await get_tree().physics_frame
		# El récord aparece bajo el contador solo si ya hay uno.
		var has_label: bool = game.has_node("HUD/Root/RecordLabel")
		if has_label != (attempt != "primera"):
			_failures.append("final (%s): etiqueta de récord en el HUD = %s" % [attempt, has_label])
		if has_label:
			# Por debajo del récord la etiqueta sigue viva; al pasarlo, se apaga.
			game.elapsed = 10.0
			game._update_record_label()
			var alive: bool = game._record_label.modulate.a > 0.5
			game.elapsed = 31.0
			game._update_record_label()
			for _i in 40:
				await get_tree().process_frame
			if not alive or game._record_label.modulate.a > 0.5:
				_failures.append("final (%s): la etiqueta de récord no se apaga al pasarlo" % attempt)
		game.elapsed = 30.0 if attempt == "primera" else 55.0
		if attempt == "tiempo":
			# Fantasma de 100 s que avanza 1 m por muestra: debe seguir moviéndose tras el final.
			var samples := PackedFloat32Array()
			for i in 2001:
				samples.append_array([float(i), 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0])
			game._ghost = Ghost.from_samples(samples, SphereMesh.new())
			game.add_child(game._ghost)
		game._finish(attempt != "tiempo")
		for _i in 120:  # el panel aparece a los 1.2-1.4 s
			await get_tree().process_frame
		if AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Audio.MUSIC_BUS)) > -5.0:
			_failures.append("final (%s): la música no baja" % attempt)
		if game._overlay == null:
			_failures.append("final (%s): no aparece el panel" % attempt)
		else:
			var text := _texts(game._overlay)
			var record := tr("RECORD_FMT") % 30.0
			match attempt:
				"primera":
					_expect_end(gs.best_times.get(0) == 30.0, attempt, "no guarda el récord")
					_expect_end(tr("NEXT_LEVEL") in text and tr("RETRY") in text, attempt, "faltan botones: " + str(text))
				"sin récord":
					_expect_end(gs.best_times.get(0) == 30.0, attempt, "un tiempo peor no debe ser récord")
					_expect_end(text.any(func(t: String) -> bool: return record in t and "+25.00" in t), attempt,
						"falta el récord con la diferencia: " + str(text))
					# Con 30 s ya tienes 2 estrellas: la siguiente es la 3.ª (menos de 25 s), no la 2.ª.
					var hint := tr("NEXT_STAR_FMT") % 25.0
					_expect_end(text.any(func(t: String) -> bool: return hint in t), attempt,
						"la siguiente estrella debe contar desde tu mejor marca: " + str(text))
				"tiempo":
					var ghost_x: float = game._ghost.position.x
					_expect_end(ghost_x > 55.0 * Ghost.RATE + 10.0, attempt, "el fantasma se queda congelado (x = %s)" % ghost_x)
					_expect_end(tr("NEXT_LEVEL") in text, attempt, "falta Siguiente nivel (ya desbloqueado)")
					# Igual que en la pausa: recuerda lo que hay que batir.
					var goal := tr("NEXT_STAR_FMT") % 25.0
					_expect_end(text.any(func(t: String) -> bool: return record in t and goal in t), attempt,
						"falta el récord y la siguiente estrella: " + str(text))
		game.queue_free()
		await get_tree().process_frame
	gs.best_times = saved[0]
	gs.unlocked = saved[1]
	gs.achievements = saved[2]
	Audio.duck_music(false)


func _expect_end(condition: bool, attempt: String, what: String) -> void:
	if not condition:
		_failures.append("final (%s): %s" % [attempt, what])


## Textos de todos los Label y Button bajo `node`.
func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child in node.find_children("*", "", true, false):
		if child is Label or child is Button:
			out.append(child.text)
	return out


## Fantasma: lo que se graba es lo que se reproduce, también tras guardarlo y leerlo del disco.
func _check_ghost() -> void:
	var body := Node3D.new()
	add_child(body)
	var recorder := Ghost.Recorder.new()
	recorder.record(0.0, body)
	body.position = Vector3(10, 2, -4)
	recorder.record(1.0, body)
	var ghost := Ghost.from_samples(recorder.samples, SphereMesh.new())
	if ghost == null:
		_failures.append("fantasma: no se crea con una vuelta de 1 s")
	else:
		ghost.seek(0.5 / Ghost.RATE)  # a medio camino entre la 1.ª y la 2.ª muestra
		if not ghost.position.is_equal_approx(Vector3(5, 1, -2)):
			_failures.append("fantasma: no interpola entre muestras (%s)" % ghost.position)
		ghost.seek(99.0)
		if not ghost.position.is_equal_approx(Vector3(10, 2, -4)):
			_failures.append("fantasma: al acabar no se queda en el último punto (%s)" % ghost.position)
		ghost.free()
	# Guardar y leer del disco (en un nivel que no existe, para no tocar los del jugador).
	const TEST_INDEX := 998
	GameState.persist = true
	GameState.save_ghost(TEST_INDEX, recorder.samples)
	GameState.persist = false
	var loaded := GameState.load_ghost(TEST_INDEX)
	DirAccess.remove_absolute(GameState._ghost_path(TEST_INDEX))
	if loaded != recorder.samples:
		_failures.append("fantasma: lo leído del disco no coincide con lo guardado")
	body.free()


## Sonidos: se usan voces libres antes de cortar uno que suena (la fanfarria no se corta).
## Mando: la vibración llega con la fuerza pedida (media si no se dice) y con la duración bien.
func _check_rumble() -> void:
	for c in [[-1.0, Vector2(0.5, 0.25)], [0.4, Vector2(0.4, 0.2)], [3.0, Vector2(1.0, 0.5)]]:
		Audio.rumble(0, 120, c[0])
		var got := Input.get_joy_vibration_strength(0)
		if not got.is_equal_approx(c[1]):
			_failures.append("vibración del mando con amplitud %s: %s" % [c[0], got])
		if not is_equal_approx(Input.get_joy_vibration_duration(0), 0.12):
			_failures.append("vibración del mando dura %s" % Input.get_joy_vibration_duration(0))
	Input.stop_joy_vibration(0)


## Anuncio de sala por Wi-Fi: nombres con "|", espacios o vacíos, y paquetes ajenos o rotos.
func _check_beacon() -> void:
	for c in [["Luis", 2, "Luis"], ["A|B", 3, "A|B"], ["  ", 1, "?"], ["|", 4, "|"],
			["Nombre larguísimo de verdad", 1, "Nombre larguísim"]]:
		var game := Net.parse_beacon(Net.beacon_text(Net.clean_name(c[0]), c[1]))
		if game.get("name") != c[2] or game.get("players") != c[1]:
			_failures.append("anuncio de sala de %s: %s" % [c[0], game])
	for bad in ["", "hola", "OTRO|Luis|2", Net.DISCOVERY_TAG + "|Luis", Net.DISCOVERY_TAG + "|Luis|x",
			Net.DISCOVERY_TAG + "|Luis|0", Net.DISCOVERY_TAG + "|Luis|99"]:
		if not Net.parse_beacon(bad).is_empty():
			_failures.append("anuncio de sala raro aceptado: %s" % bad)


## Estados de canica por red: los normales pasan; NaN, infinitos o rotación nula no.
func _check_net_state() -> void:
	var q := Quaternion.IDENTITY
	if not Net.state_ok(Vector3(1, 2, 3), Vector3.ZERO, q):
		_failures.append("red: un estado normal se descarta")
	for bad in [[Vector3(NAN, 0, 0), Vector3.ZERO, q], [Vector3.ZERO, Vector3(0, INF, 0), q],
			[Vector3.ZERO, Vector3.ZERO, Quaternion(0, 0, 0, 0)], [Vector3.ZERO, Vector3.ZERO, Quaternion(NAN, 0, 0, 1)]]:
		if Net.state_ok(bad[0], bad[1], bad[2]):
			_failures.append("red: estado raro aceptado %s" % [bad])


## Anfitrión con una versión con más niveles: no se carga un nivel que no existe; se sale
## de la sala avisando.
func _check_unknown_level() -> void:
	var reasons := []
	var on_left := func(reason: String) -> void: reasons.append(reason)
	Net.left.connect(on_left)
	var level := GameState.current_level
	Net._sync_players({}, GameState.LEVELS.size())
	Net._start_race(-1)
	Net.left.disconnect(on_left)
	if reasons != ["NET_VERSION_MISMATCH", "NET_VERSION_MISMATCH"]:
		_failures.append("red: nivel desconocido da %s" % [reasons])
	if GameState.current_level != level or Net.in_race:
		_failures.append("red: se intenta cargar un nivel que no existe")


## Clasificaciones de Game Center y Play Juegos: sin repetir ni vacías, como mucho una por nivel
## y las mismas en las dos tiendas. Un nivel nuevo puede no tenerla aún (se avisa); hay que
## crearla en las dos consolas. Y cada logro que se desbloquea existe.
func _check_service_ids() -> void:
	for ids in [GameServices.IOS_IDS, GameServices.ANDROID_IDS]:
		var unique := {}
		for id in ids:
			unique[id] = true
		if ids.size() > GameState.LEVELS.size() or unique.size() != ids.size() or unique.has(""):
			_failures.append("clasificaciones: %d identificadores (%d distintos) para %d niveles"
				% [ids.size(), unique.size(), GameState.LEVELS.size()])
	if GameServices.IOS_IDS.size() != GameServices.ANDROID_IDS.size():
		_failures.append("clasificaciones: %d en iOS y %d en Android" % [GameServices.IOS_IDS.size(), GameServices.ANDROID_IDS.size()])
	for i in GameState.LEVELS.size():
		if not GameServices.has_leaderboard(i):
			print("SMOKE aviso: el nivel %d aún no tiene clasificación en las tiendas" % (i + 1))
	var regex := RegEx.create_from_string(r'GameServices\.unlock\("([a-z_]+)"\)')
	for path in ["res://scripts/game.gd", "res://scripts/net.gd", "res://scripts/menu.gd", "res://scripts/game_services.gd"]:
		for m in regex.search_all(FileAccess.get_file_as_string(path)):
			if not GameServices.ACHIEVEMENTS.has(m.get_string(1)):
				_failures.append("logro desconocido en %s: %s" % [path.get_file(), m.get_string(1)])


## Recién reaparecida, una canica de acero al lado no la persigue; pasado el margen, sí.
func _check_respawn_protection() -> void:
	var marble := Marble.new()
	var chaser := Chaser.new()
	add_child(marble)
	add_child(chaser)
	marble.global_position = Vector3(2, 0, 0)
	var before := chaser._nearest_target()
	marble.respawn(Vector3(2, 0, 0))
	var protected := chaser._nearest_target()
	for _i in int(Marble.RESPAWN_PROTECTION * 60.0) + 5:
		marble._protection = maxf(marble._protection - 1.0 / 60.0, 0.0)
	var after := chaser._nearest_target()
	if absf(Marble.blink_loops() * Marble.BLINK_STEP * 2.0 - Marble.RESPAWN_PROTECTION) > Marble.BLINK_STEP * 2.0:
		_failures.append("el parpadeo al reaparecer (%d ciclos) no dura lo que la protección" % Marble.blink_loops())
	if before == Vector3.INF or protected != Vector3.INF or after == Vector3.INF:
		_failures.append("protección al reaparecer: antes %s, recién reaparecida %s, después %s" % [before, protected, after])
	marble.free()
	chaser.free()
	await get_tree().process_frame


## La catapulta calcula el tiro: integrando la caída con esa velocidad se llega al objetivo.
func _check_catapult_aim() -> void:
	var g := Vector3(0, -9.8, 0)
	var from := Vector3(0, 0.5, 0)
	var to := Vector3(3, 6.5, -20)
	var v := Level.catapult_velocity(from, to, 1.4, g)
	var end := from + v * 1.4 + g * 1.4 * 1.4 / 2.0
	if end.distance_to(to) > 0.01:
		_failures.append("catapulta: el tiro acaba en %s (debe %s)" % [end, to])


## Nivel 10 (Montaña rusa) recorrido a ciegas, tramo a tramo: inclinando hacia delante se baja
## por el tobogán, se pasa el trampolín y la catapulta te sube; el medio tubo te deja abajo y
## el último salto llega a la meta.
func _check_coaster_routes() -> void:
	var level: Level = load("res://levels/level_10.gd").new()
	var marble: Marble = load("res://scenes/marble.tscn").instantiate()
	var camera := Camera3D.new()
	level.marble = marble
	add_child(level)
	level.build()
	add_child(camera)
	add_child(marble)
	marble.camera = camera
	marble.release()
	var goal := level.goal_center
	var marks := level.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return n.has_meta("catapult_target"))
	if marks.size() != 1 or (marks[0] as Node3D).position.distance_to(Vector3(0, -8.95, -86)) > 0.01:
		_failures.append("catapulta: la diana del aterrizaje no está donde cae (%s)" % [marks])
	# El arco de puntos sube y baja: el punto más alto queda por encima de la salida y de la diana.
	var arc := level.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return n.has_meta("catapult_arc"))
	var top := -INF
	for d: Node3D in arc:
		top = maxf(top, d.position.y)
	if arc.size() != Level.CATAPULT_DOTS - 1 or top < -8.4:
		_failures.append("catapulta: arco de %d puntos, el más alto a %.1f" % [arc.size(), top])
	# [nombre, salida, acción, segundos, comprobación]
	var routes := [
		["tobogán, trampolín y catapulta", Vector3(0, 1, -7), "ui_up", 12.0,
			func(p: Vector3) -> bool: return p.z < -83.5 and p.y > -9.6 and absf(p.x) < 4.0],
		["catapulta", Vector3(0, -14, -62), "ui_up", 6.0,
			func(p: Vector3) -> bool: return p.z < -83.5 and p.y > -9.6 and absf(p.x) < 4.0],
		["medio tubo", Vector3(2, -8, -88), "ui_right", 8.0,
			func(p: Vector3) -> bool: return p.distance_to(goal - Vector3(13, 0, 0)) < 4.0 and p.y > goal.y - 0.6],
		["último salto", goal + Vector3(-12, 1, 0), "ui_right", 6.0,
			func(p: Vector3) -> bool: return Vector2(p.x - goal.x, p.z - goal.z).length() < 3.5 and absf(p.y - goal.y - 0.5) < 0.15],
	]
	# Tiempo del recorrido entero (sin el tramo "catapulta", que repite parte del primero).
	var run_time := 0.0
	for route in routes:
		marble.respawn(route[1])
		await get_tree().physics_frame
		if route[2] != "":
			Input.action_press(route[2])
		var reached := false
		var frames := 0
		for _i in int(route[3] * 60.0):
			frames += 1
			await get_tree().physics_frame
			if _i % 15 == 0 and OS.has_environment("TRACE_ROUTES"):
				print("TRACE %s %.2f %s v=%s suelo=%s" % [route[0], _i / 60.0, marble.global_position.snapped(Vector3.ONE * 0.01), marble.linear_velocity.snapped(Vector3.ONE * 0.1), marble.is_grounded()])
			if route[4].call(marble.global_position):
				reached = true
				break
		if route[2] != "":
			Input.action_release(route[2])
		var pos := marble.global_position
		if not reached:
			_failures.append("nivel 10, %s: acaba en %s" % [route[0], pos.snapped(Vector3.ONE * 0.1)])
		else:
			print("SMOKE nivel 10, %s: bien en %.1f s (%s)" % [route[0], frames / 60.0, pos.snapped(Vector3.ONE * 0.1)])
		if route[0] != "catapulta":
			run_time += frames / 60.0
	# Las tres estrellas, a tiro: a ciegas (sin atajos ni girar bien) ya se baja de su tiempo.
	var stars: Array = GameState.LEVELS[9].stars
	print("SMOKE nivel 10: recorrido a ciegas en %.1f s (estrellas %s)" % [run_time, stars])
	if run_time > stars[0]:
		_failures.append("nivel 10: a ciegas tarda %.1f s, más que las tres estrellas (%s)" % [run_time, stars[0]])
	marble.free()
	camera.free()
	level.free()


## Estela de velocidad: sale yendo deprisa y no parada ni recién reaparecida.
func _check_speed_trail() -> void:
	var marble: Marble = load("res://scenes/marble.tscn").instantiate()
	add_child(marble)
	await get_tree().physics_frame
	var still := marble.is_trailing()
	marble.linear_velocity = Vector3(12, 0, 0)
	await get_tree().physics_frame
	var fast := marble.is_trailing()
	marble.respawn(Vector3(0, 5, 0))
	await get_tree().physics_frame
	var respawned := marble.is_trailing()
	if still or not fast or respawned:
		_failures.append("estela: parada %s, deprisa %s, al reaparecer %s" % [still, fast, respawned])
	marble.free()


func _check_voices() -> void:
	var sound_was: bool = GameState.sound_on
	GameState.sound_on = true
	for v in Audio._voices:
		v.stop()
	Audio.play("win")
	var win_voice: AudioStreamPlayer = null
	for v in Audio._voices:
		if v.playing:
			win_voice = v
	if win_voice == null:
		print("SMOKE aviso: sin audio en este modo, no se comprueban las voces")
	else:
		# Llena las demás voces, libera una y suena otro golpe: por turno tocaría la fanfarria.
		for _i in Audio.VOICES - 1:
			Audio.play("tick", -80.0)
		for v in Audio._voices:
			if v != win_voice:
				v.stop()
				break
		Audio.play("tick", -80.0)
		if win_voice.stream != Audio.SOUNDS["win"] or not win_voice.playing:
			_failures.append("sonido: la fanfarria se corta aunque hay voces libres")
	for v in Audio._voices:
		v.stop()
	# Un nombre que no existe no rompe nada (ni cambia la música que suena).
	var music_before: String = Audio._music_name
	Audio.play("no_existe")
	Audio.play_music("no_existe")
	if Audio._music_name != music_before:
		_failures.append("sonido: una música desconocida cambia la actual")
	GameState.sound_on = sound_was


## Fantasmas con datos rotos (cortados, NaN, rotación nula) se descartan en vez de dar errores.
func _check_bad_ghost() -> void:
	var good := PackedFloat32Array([0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1])
	var mesh := SphereMesh.new()
	var ghost := Ghost.from_samples(good, mesh)
	if ghost == null:
		_failures.append("fantasma: uno válido se descarta")
	else:
		ghost.free()
	var cut := good.slice(0, 12)
	var nan := good.duplicate()
	nan[9] = NAN
	var zero_rot := good.duplicate()
	zero_rot[14] = 0.0
	for bad: PackedFloat32Array in [cut, nan, zero_rot]:
		var g := Ghost.from_samples(bad, mesh)
		if g != null:
			_failures.append("fantasma: se acepta uno roto (%d datos)" % bad.size())
			g.free()


## Opciones con tipos equivocados en el archivo: se ignoran (sin error) y lo válido se carga.
func _check_bad_options() -> void:
	var gs := GameState
	var fields := ["unlocked", "best_times", "achievements", "resets", "review_stage", "tilt_degrees",
		"tilt_custom", "invert_x", "invert_y", "show_debug", "show_ghost", "music_on", "sound_on",
		"vibration_on", "player_name", "language", "last_ip", "levels_seen", "camera_shake"]
	var saved := {}
	for f in fields:
		var v: Variant = gs.get(f)
		saved[f] = v.duplicate() if v is Dictionary or v is Array else v
	gs.music_on = true
	gs.player_name = "Ana"
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "desbloqueados", "muchos")
	cfg.set_value("progreso", "logros", ["first_win", 7])
	cfg.set_value("opciones", "inclinacion", 90)
	cfg.set_value("opciones", "musica", "no")
	cfg.set_value("opciones", "nombre", 42)
	cfg.set_value("opciones", "idioma", "klingon")
	cfg.set_value("opciones", "invertir_x", true)
	cfg.set_value("opciones", "ultima_ip", "999.1.2.3")
	gs._apply_config(cfg)
	# Sin "niveles_vistos" (partida de antes de la marca de nuevo) cuenta como 9 niveles vistos.
	var got := [gs.unlocked, gs.achievements, gs.tilt_degrees, gs.music_on, gs.player_name, gs.language, gs.invert_x, gs.last_ip, gs.levels_seen]
	var want := [1, ["first_win"], 35.0, true, "Ana", "", true, "", GameState.LEVELS_BEFORE_SEEN]
	cfg.set_value("opciones", "ultima_ip", "192.168.1.20")
	gs._apply_config(cfg)
	if gs.last_ip != "192.168.1.20":
		_failures.append("opciones: la última IP buena no se carga (%s)" % gs.last_ip)
	if str(got) != str(want):
		_failures.append("opciones dañadas: se cargan %s (debe %s)" % [got, want])
	for f in fields:
		if f == "achievements":
			gs.achievements.assign(saved[f])
		else:
			gs.set(f, saved[f])


## Continuar: primero el nivel sin superar; con todos superados, el primero sin 3 estrellas.
func _check_suggested() -> void:
	var gs := GameState
	var saved := [gs.best_times.duplicate(), gs.unlocked, gs.current_level]
	var n: int = gs.LEVELS.size()
	gs.best_times = {0: 1.0, 1: 1.0}
	gs.unlocked = 3
	if gs.suggested_level() != 2:
		_failures.append("continuar: con 2 superados sugiere %d (debe 2)" % gs.suggested_level())
	gs.unlocked = n
	for i in n:
		gs.best_times[i] = 1.0  # 3 estrellas
	gs.best_times[4] = 9999.0  # 1 estrella
	gs.current_level = 7
	if gs.suggested_level() != 4:
		_failures.append("continuar: con todo superado sugiere %d (debe 4, sin 3 estrellas)" % gs.suggested_level())
	gs.best_times[4] = 1.0
	if gs.suggested_level() != 7:
		_failures.append("continuar: con todo a 3 estrellas sugiere %d (debe el último jugado)" % gs.suggested_level())
	gs.best_times = saved[0]
	gs.unlocked = saved[1]
	gs.current_level = saved[2]


## Un archivo guardado con basura no rompe nada: solo se cargan los récords válidos.
func _check_bad_save() -> void:
	var saved: Dictionary = GameState.best_times.duplicate()
	var cfg := ConfigFile.new()
	cfg.set_value("records", "0", 31.5)
	cfg.set_value("records", "1", 40)
	cfg.set_value("records", "99", 10.0)
	cfg.set_value("records", "-1", 10.0)
	cfg.set_value("records", "abc", 10.0)
	cfg.set_value("records", "2", "rapido")
	cfg.set_value("records", "3", 0.0)
	GameState._read_records(cfg)
	if GameState.best_times != {0: 31.5, 1: 40.0}:
		_failures.append("guardado dañado: se cargan %s" % GameState.best_times)
	GameState.total_stars()  # no debe salirse de la lista de niveles
	GameState.best_times = saved


## WASD mueve como las flechas (por posición física) y en diagonal no va más rápido.
func _check_wasd() -> void:
	var marble := Marble.new()
	if marble._wasd() != Vector2.ZERO:
		_failures.append("WASD: hay movimiento sin pulsar nada")
	for code in [KEY_W, KEY_D]:
		_press(code, true)
	var v: Vector2 = marble._wasd()
	if not v.is_equal_approx(Vector2(1, 1).normalized()):
		_failures.append("WASD: W+D da %s" % v)
	for code in [KEY_W, KEY_D]:
		_press(code, false)
	_press(KEY_S, true)
	if not marble._wasd().is_equal_approx(Vector2(0, -1)):
		_failures.append("WASD: S da %s" % marble._wasd())
	_press(KEY_S, false)
	marble.free()


## Stick: media palanca ya mueve (con ui_* no hacía nada), en reposo no, y a fondo da 1.
func _check_stick() -> void:
	var marble := Marble.new()
	var cases := [[Vector2(0, 0), 0.0, 0.0], [Vector2(0.1, 0), 0.0, 0.0], [Vector2(0.4, 0), 0.05, 0.5],
		[Vector2(1, 0), 0.99, 1.01], [Vector2(0, -1), 0.99, 1.01]]
	for c in cases:
		_tilt_stick(c[0])
		var v: Vector2 = marble._stick(0)
		if v.length() < c[1] or v.length() > c[2]:
			_failures.append("stick %s da %s" % [c[0], v])
	_tilt_stick(Vector2(0, -1))
	if marble._stick(0).y <= 0.0:
		_failures.append("stick hacia arriba no va hacia delante: %s" % marble._stick(0))
	_tilt_stick(Vector2.ZERO)
	marble.free()


func _tilt_stick(v: Vector2) -> void:
	for axis in [[JOY_AXIS_LEFT_X, v.x], [JOY_AXIS_LEFT_Y, v.y]]:
		var motion := InputEventJoypadMotion.new()
		motion.device = 0
		motion.axis = axis[0]
		motion.axis_value = axis[1]
		Input.parse_input_event(motion)
	Input.flush_buffered_events()


func _press(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	Input.parse_input_event(key)
	Input.flush_buffered_events()


## Cámara: centrada con la canica parada o congelada; se adelanta hacia donde rueda, con tope.
func _check_camera_lead() -> void:
	var camera := MarbleCamera.new()
	var body := RigidBody3D.new()
	camera.target = body
	if camera._lead() != Vector3.ZERO:
		_failures.append("cámara: se adelanta con la canica parada")
	body.linear_velocity = Vector3(4, -9, 0)
	var lead := camera._lead()
	if not lead.is_equal_approx(Vector3(4 * camera.lead_time, 0, 0)):
		_failures.append("cámara: adelanto incorrecto (%s); no debe contar la velocidad vertical" % lead)
	body.linear_velocity = Vector3(0, 0, -100)
	if camera._lead().length() > camera.max_lead + 0.001:
		_failures.append("cámara: el adelanto pasa del máximo")
	body.freeze = true
	if camera._lead() != Vector3.ZERO:
		_failures.append("cámara: se adelanta con la canica congelada (salida, meta)")
	# Temblor: dentro del tope mientras dura y vuelve a cero sin dejar la cámara desplazada.
	camera.target = null
	camera.shake(1.0)
	var moved := false
	for i in 30:
		camera._process(1.0 / 60.0)
		moved = moved or camera.h_offset != 0.0 or camera.v_offset != 0.0
		if absf(camera.h_offset) > camera.max_shake or absf(camera.v_offset) > camera.max_shake:
			_failures.append("cámara: el temblor pasa del tope")
			break
	if not moved:
		_failures.append("cámara: shake() no mueve la cámara")
	if camera.h_offset != 0.0 or camera.v_offset != 0.0:
		_failures.append("cámara: el temblor no se apaga (%s, %s)" % [camera.h_offset, camera.v_offset])
	# Zoom con la velocidad: igual parado y despacio, más lejos deprisa, con tope.
	var zooms := [camera.zoom_for(0.0), camera.zoom_for(camera.zoom_from), camera.zoom_for(12.0), camera.zoom_for(40.0)]
	if zooms[0] != camera._base_size or zooms[1] != zooms[0] or zooms[2] <= zooms[0] 			or not is_equal_approx(zooms[3], camera._base_size + camera.speed_zoom):
		_failures.append("cámara: zoom con la velocidad %s" % [zooms])
	# Con la opción de temblor quitada, shake() no hace nada.
	GameState.camera_shake = false
	camera.shake(1.0)
	camera._process(1.0 / 60.0)
	GameState.camera_shake = true
	if camera.h_offset != 0.0 or camera.v_offset != 0.0:
		_failures.append("cámara: tiembla con la opción de temblor quitada")
	camera.free()
	body.free()


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures.append("nube: " + what)


## Mezcla del progreso de la nube (GameState.merge_cloud) con casos típicos y datos raros.
func _check_cloud_merge() -> void:
	var gs := GameState
	var saved := [gs.best_times.duplicate(), gs.achievements.duplicate(), gs.resets, gs.unlocked]
	gs.best_times = {0: 30.0, 1: 50.0}
	gs.achievements = ["a"]
	gs.resets = 0
	gs.unlocked = 3

	var remote := JSON.stringify({resets = 0, times = {"0": 25.0, "1": 60.0, "4": 40.0}, achievements = ["b"]})
	_expect(gs.merge_cloud(remote), "una mezcla con mejoras debería cambiar algo")
	_expect(is_equal_approx(gs.best_times[0], 25.0), "se queda con el mejor tiempo (nivel 1)")
	_expect(is_equal_approx(gs.best_times[1], 50.0), "no empeora un récord local (nivel 2)")
	_expect(gs.best_times.has(4) and gs.unlocked == 6, "un nivel nuevo de la nube desbloquea el siguiente")
	_expect(gs.achievements.has("a") and gs.achievements.has("b"), "une los logros")
	_expect(not gs.merge_cloud(remote), "mezclar dos veces lo mismo no cambia nada")

	_expect(not gs.merge_cloud("no es json"), "ignora texto que no es JSON")
	_expect(not gs.merge_cloud("[1, 2]"), "ignora JSON que no es un diccionario")
	gs.merge_cloud(JSON.stringify({resets = 0, times = {"x": 1.0, "99": 1.0, "2": -5.0}}))
	_expect(not gs.best_times.has(2) and not gs.best_times.has(99) and is_equal_approx(gs.best_times[0], 25.0),
		"ignora niveles inexistentes, claves no numéricas y tiempos no positivos")

	# Reinicio en otro aparato: se borran los récords de aquí y se adoptan los de la nube.
	gs.merge_cloud(JSON.stringify({resets = 1, times = {"0": 33.0}}))
	_expect(gs.resets == 1 and gs.best_times.size() == 1 and is_equal_approx(gs.best_times[0], 33.0),
		"un reinicio más reciente en la nube manda")
	_expect(gs.achievements.has("a"), "los logros sobreviven al reinicio")
	# Datos viejos (de antes del reinicio de aquí): no deben resucitar récords.
	_expect(not gs.merge_cloud(JSON.stringify({resets = 0, times = {"0": 10.0}})), "ignora récords anteriores al reinicio")

	gs.best_times = saved[0]
	gs.achievements = saved[1]
	gs.resets = saved[2]
	gs.unlocked = saved[3]


func _check_level(index: int) -> void:
	GameState.current_level = index
	var game: Node = GAME_SCENE.instantiate()
	add_child(game)
	var marble: Marble = game.marble
	if index == 0:
		# El contador redondea hacia arriba: rojo solo cuando ya marca menos de 10.
		# Pista al salir: en el PC (sin sensor) la del ratón; en carrera ninguna.
		if game._start_hint() != "
" + tr("MOUSE_HINT"):
			_failures.append("nivel 1: falta la pista del ratón al salir")
		game.race = true
		if game._start_hint() != "":
			_failures.append("nivel 1: en carrera no debe haber pista")
		game.race = false
		# Consejo de nivel: el del nivel 10 sale hasta superarlo; un nivel sin consejo, nada.
		var saved_best: Dictionary = GameState.best_times.duplicate()
		GameState.best_times.erase(9)
		GameState.current_level = 9
		var tip_before: String = game._start_hint()
		GameState.best_times[9] = 30.0
		var tip_after: String = game._start_hint()
		GameState.current_level = 4
		var no_tip: String = game._start_hint()
		GameState.current_level = 0
		GameState.best_times = saved_best
		if tip_before != "\n" + tr("LEVEL_10_TIP") or tip_after != "" or no_tip != "":
			_failures.append("consejo de nivel: antes %s, después %s, sin consejo %s" % [tip_before, tip_after, no_tip])
		# Los avisos grandes (¡Ya! + pista, nombre del nivel) caben en pantalla en todos los idiomas.
		var label: Label = game.message_label
		for locale in TranslationServer.get_loaded_locales():
			TranslationServer.set_locale(locale)
			for text in [tr("GO") + "
" + tr("MOUSE_HINT"), tr("GO") + "
" + tr("TILT_HINT"), tr("GO") + "
" + tr("LEVEL_10_TIP"),
					"%s
3" % tr(GameState.LEVELS[8].name), tr("HOLD_FMT") % 3]:
				label.text = text
				label.size = Vector2(label.offset_right - label.offset_left, 0.0)
				var need := Vector2(maxf(label.size.x, label.get_minimum_size().x), label.get_minimum_size().y)
				if need.x > 1280.0 or need.y > 400.0:
					_failures.append("aviso (%s) mide %s y no cabe: %s" % [locale, need, text.replace("
", " / ")])
			# Cabecera ("Nivel N / nombre") y botón de calibrar: ninguno pisa el contador.
			for i in GameState.LEVELS.size():
				game.level_label.text = tr("HUD_LEVEL_FMT") % [i + 1, tr(GameState.LEVELS[i].name)]
				var w: float = game.level_label.get_minimum_size().x
				if game.level_label.offset_left + w > 640.0 - 120.0:
					_failures.append("cabecera (%s) nivel %d mide %.0f px y pisa el contador" % [locale, i + 1, w])
			for key in ["RECALIBRATE", "CALIBRATED"]:
				game.calibrate_button.text = tr(key)
				var bw: float = game.calibrate_button.get_minimum_size().x
				# Crece hacia la izquierda: basta con que no llegue al contador.
				if 1280.0 + game.calibrate_button.offset_right - bw < 640.0 + 120.0:
					_failures.append("botón calibrar (%s) mide %.0f px y pisa el contador" % [locale, bw])
		# Modo espectador (carrera): la barra "< Viendo a ... >" con un nombre largo cabe.
		game._build_spectator_hud()
		var bar: Control = game._spectator_hud[0]
		for locale in TranslationServer.get_loaded_locales():
			TranslationServer.set_locale(locale)
			game._watch_label.text = tr("WATCHING_FMT") % ["WWWWWWWWWWWWWWWW", "  " + tr("AT_GOAL")]
			var bw: float = bar.get_combined_minimum_size().x
			if bw > 1280.0:
				_failures.append("barra de espectador (%s) mide %.0f px y no cabe" % [locale, bw])
		for node in game._spectator_hud:
			node.queue_free()
		game._spectator_hud.clear()
		GameState.apply_language()
		label.visible = false
		var time_before: float = game.time_left
		for case in [[60.0, "60.0", false], [9.96, "10.0", false], [9.9, "9.9", true], [0.04, "0.1", true], [0.0, "0.0", true]]:
			game.time_left = case[0]
			game._update_time_label()
			var red: bool = game.time_label.modulate == Color.RED
			if game.time_label.text != case[1] or red != case[2]:
				_failures.append("contador: con %s muestra %s (rojo %s)" % [case[0], game.time_label.text, red])
		game.time_left = time_before
		# Meta: un bote corto (menos de GOAL_GRACE) no reinicia la cuenta; salir de verdad, sí.
		game.level.marble_on_goal = true
		game._update_goal(1.0)
		game.level.marble_on_goal = false
		game._update_goal(0.1)
		var kept: float = game._goal_hold
		game._update_goal(0.2)
		if not is_equal_approx(kept, 1.0) or game._goal_hold != 0.0:
			_failures.append("meta: tras un bote queda %s (debe 1.0) y al salir %s (debe 0)" % [kept, game._goal_hold])
		# Tiempo agotado aguantando en la meta: la cuenta de la meta termina; fuera, se acabó.
		var time_saved: float = game.time_left
		game.time_left = 0.0
		var up := []
		for c in [[false, 0.0, 0.0], [true, 0.0, 0.0], [false, 1.0, 0.1], [false, 1.0, 0.3]]:
			game.level.marble_on_goal = c[0]
			game._goal_hold = c[1]
			game._off_goal = c[2]
			up.append(game._time_up())
		game.time_left = 5.0
		up.append(game._time_up())
		if up != [true, false, false, true, false]:
			_failures.append("tiempo agotado en la meta: %s (debe [true, false, false, true, false])" % [up])
		game.level.marble_on_goal = false
		game._goal_hold = 0.0
		game._off_goal = 0.0
		game.time_left = time_saved
		# R reinicia al momento, pero no si se mantiene pulsada (eco), con otra tecla ni en carrera.
		var key := InputEventKey.new()
		key.physical_keycode = KEY_R
		key.pressed = true
		if not game._is_quick_restart(key):
			_failures.append("nivel 1: R no reinicia")
		key.echo = true
		var echo_ok: bool = game._is_quick_restart(key)
		key.echo = false
		key.physical_keycode = KEY_T
		var other_ok: bool = game._is_quick_restart(key)
		key.physical_keycode = KEY_R
		game.race = true
		var race_ok: bool = game._is_quick_restart(key)
		game.race = false
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_BACK
		pad.pressed = true
		if not game._is_quick_restart(pad):
			_failures.append("nivel 1: Select/Back del mando no reinicia")
		pad.button_index = JOY_BUTTON_START
		if game._is_quick_restart(pad) or not game._is_joy(pad, JOY_BUTTON_START):
			_failures.append("nivel 1: Start del mando debe pausar, no reiniciar")
		if echo_ok or other_ok or race_ok:
			_failures.append("nivel 1: R reinicia cuando no debe (eco %s, otra tecla %s, carrera %s)" % [echo_ok, other_ok, race_ok])
		# Mandar la app al fondo en la cuenta atrás pausa la partida; al volver sigue.
		for _i in 30:
			await get_tree().physics_frame
		Input.joy_connection_changed.emit(0, false)
		if not get_tree().paused or game._overlay == null:
			_failures.append("nivel 1: no se pausa al desconectarse el mando")
		game._resume()
		game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		if not get_tree().paused or game._overlay == null:
			_failures.append("nivel 1: no se pausa al ir al fondo en la cuenta atrás")
		var pause_texts := _texts(game._overlay)
		if not pause_texts.any(func(t: String) -> bool: return tr(GameState.LEVELS[0].name) in t):
			_failures.append("nivel 1: la pausa no dice en qué nivel estás: %s" % [pause_texts])
		var music_bus := AudioServer.get_bus_index(Audio.MUSIC_BUS)
		for _i in 30:
			await get_tree().process_frame
		if AudioServer.get_bus_volume_db(music_bus) > -5.0:
			_failures.append("nivel 1: la música no baja en la pausa")
		# Esc / Start con la pausa abierta (el foco está en un botón del panel) reanudan.
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null or not game._overlay.is_ancestor_of(focused):
			_failures.append("nivel 1: la pausa no pone el foco en un botón")
			game._resume()
		else:
			focused.gui_input.emit(cancel)
			if get_tree().paused or game._overlay != null:
				_failures.append("nivel 1: Esc con la pausa abierta no reanuda")
				game._resume()
		for _i in 30:
			await get_tree().process_frame
		if absf(AudioServer.get_bus_volume_db(music_bus)) > 0.5:
			_failures.append("nivel 1: la música no vuelve a su volumen al reanudar")
	# Cuenta atrás (3 s a 60 fps fijos) y un rato rodando sin tocar nada.
	var frames := 0
	while game.state != game.State.PLAYING and frames < 400:
		await get_tree().physics_frame
		frames += 1
	for _i in FRAMES_AFTER_GO:
		await get_tree().physics_frame
	var level: Level = game.level
	var name := "nivel %d" % (index + 1)
	# Bloques iguales comparten malla (ver Level._add_box).
	var boxes := 0
	var unique := {}
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (node as MeshInstance3D).mesh
		if m is BoxMesh:
			boxes += 1
			unique[m] = true
	print("SMOKE %s: %d bloques, %d mallas" % [name, boxes, unique.size()])
	if boxes > 10 and unique.size() == boxes:
		_failures.append("%s: ningún bloque comparte malla" % name)
	# Canicas de acero y gusanos comparten mallas (ver Chaser._build_shared y Worm._segment_mesh).
	var chaser_meshes := {}
	for chaser in level.chasers:
		for node in chaser.find_children("*", "MeshInstance3D", false, false):
			chaser_meshes[(node as MeshInstance3D).mesh] = true
	if level.chasers.size() > 1 and chaser_meshes.size() > 2:
		_failures.append("%s: las canicas de acero no comparten malla (%d)" % [name, chaser_meshes.size()])
	var worm_meshes := {}
	var worms := level.find_children("*", "Worm", true, false)
	for worm in worms:
		for part in worm.find_children("*", "MeshInstance3D", true, false):
			worm_meshes[part.mesh] = true
	# 9 segmentos + agujero (2) + boca, ojo, pupila, antena y punta.
	if worms.size() > 1 and worm_meshes.size() > Worm.SEGMENTS + 7:
		_failures.append("%s: los gusanos no comparten malla (%d)" % [name, worm_meshes.size()])
	if level.goal_center == Vector3.ZERO or level.goal_center.distance_to(level.spawn_point) < 5.0:
		_failures.append("%s: la meta no está colocada (%s)" % [name, level.goal_center])
	if game.state != game.State.PLAYING:
		_failures.append("%s: no empieza (estado %d)" % [name, game.state])
	elif not marble.is_grounded():
		_failures.append("%s: la canica no está sobre el suelo en %s" % [name, marble.global_position])
	elif marble.global_position.distance_to(level.spawn_point) > 3.0:
		_failures.append("%s: la canica se ha movido sola hasta %s" % [name, marble.global_position])
	elif game._respawns > 0:
		_failures.append("%s: la canica ha reaparecido sin tocar nada" % name)
	elif index == 0:
		# Reaparición: vuelve al punto de control, se apoya y termina visible tras el parpadeo.
		game._respawn("FELL")
		for _i in 90:
			await get_tree().physics_frame
		var mesh: Node3D = marble.get_node("Mesh")
		if not marble.is_grounded() or not mesh.visible or not marble.visible:
			_failures.append("%s: tras reaparecer, suelo=%s visible=%s" % [name, marble.is_grounded(), mesh.visible])
	game.queue_free()
	await get_tree().process_frame

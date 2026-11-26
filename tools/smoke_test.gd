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
	_check_bad_save()
	_check_suggested()
	_check_bad_options()
	_check_bad_ghost()
	_check_voices()
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
		menu._fill_level_grid()
		await get_tree().process_frame
		for screen_name: String in menu._screens:
			var screen: Control = menu._screens[screen_name]
			var need := (screen.get_child(0) as Control).get_combined_minimum_size()
			if need.y > 720.0 or need.x > 1280.0:
				_failures.append("menú %s (%s) mide %s y no cabe en 1280x720" % [screen_name, locale, need])
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
		"vibration_on", "player_name", "language"]
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
	gs._apply_config(cfg)
	var got := [gs.unlocked, gs.achievements, gs.tilt_degrees, gs.music_on, gs.player_name, gs.language, gs.invert_x]
	var want := [1, ["first_win"], 35.0, true, "Ana", "", true]
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
		# Los avisos grandes (¡Ya! + pista, nombre del nivel) caben en pantalla en todos los idiomas.
		var label: Label = game.message_label
		for locale in TranslationServer.get_loaded_locales():
			TranslationServer.set_locale(locale)
			for text in [tr("GO") + "
" + tr("MOUSE_HINT"), tr("GO") + "
" + tr("TILT_HINT"),
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

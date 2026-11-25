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
	await _check_overlay_fits()
	await _check_menu_fits()
	for i in GameState.LEVELS.size():
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
		game.elapsed = 30.0 if attempt == "primera" else 55.0
		game._finish(attempt != "tiempo")
		for _i in 120:  # el panel aparece a los 1.2-1.4 s
			await get_tree().process_frame
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
					_expect_end(tr("NEXT_LEVEL") in text, attempt, "falta Siguiente nivel (ya desbloqueado)")
		game.queue_free()
		await get_tree().process_frame
	gs.best_times = saved[0]
	gs.unlocked = saved[1]
	gs.achievements = saved[2]


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
		# Mandar la app al fondo en la cuenta atrás pausa la partida; al volver sigue.
		for _i in 30:
			await get_tree().physics_frame
		game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		if not get_tree().paused or game._overlay == null:
			_failures.append("nivel 1: no se pausa al ir al fondo en la cuenta atrás")
		game._resume()
	# Cuenta atrás (3 s a 60 fps fijos) y un rato rodando sin tocar nada.
	var frames := 0
	while game.state != game.State.PLAYING and frames < 400:
		await get_tree().physics_frame
		frames += 1
	for _i in FRAMES_AFTER_GO:
		await get_tree().physics_frame
	var level: Level = game.level
	var name := "nivel %d" % (index + 1)
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

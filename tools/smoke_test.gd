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
	for i in GameState.LEVELS.size():
		await _check_level(i)
	if _failures.is_empty():
		print("SMOKE OK (%d niveles)" % GameState.LEVELS.size())
	else:
		for failure in _failures:
			print("SMOKE FAIL ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


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

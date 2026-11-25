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
	# Que la prueba no toque las opciones del jugador (fantasma desactivado, sin sonido).
	GameState.show_ghost = false
	for i in GameState.LEVELS.size():
		await _check_level(i)
	if _failures.is_empty():
		print("SMOKE OK (%d niveles)" % GameState.LEVELS.size())
	else:
		for failure in _failures:
			print("SMOKE FAIL ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


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
	game.queue_free()
	await get_tree().process_frame

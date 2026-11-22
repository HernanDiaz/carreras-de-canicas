extends Node
## Sonido y vibración (autoload "Audio"): efectos, música de fondo y sus opciones.
## Los sonidos se generan con tools/make_sounds.py (síntesis propia, sin grabaciones ajenas).
## El sonido de rodar y las músicas se repiten en bucle (opción "Loop Mode" al importarlos).

const SOUNDS := {
	roll = preload("res://sounds/roll.wav"),
	hit = preload("res://sounds/hit.wav"),
	land = preload("res://sounds/land.wav"),
	fall = preload("res://sounds/fall.wav"),
	zap = preload("res://sounds/zap.wav"),
	respawn = preload("res://sounds/respawn.wav"),
	beep = preload("res://sounds/beep.wav"),
	go = preload("res://sounds/go.wav"),
	tick = preload("res://sounds/tick.wav"),
	win = preload("res://sounds/win.wav"),
	lose = preload("res://sounds/lose.wav"),
	star = preload("res://sounds/star.wav"),
	click = preload("res://sounds/click.wav"),
	achievement = preload("res://sounds/achievement.wav"),
}
const MUSIC := {
	menu = preload("res://sounds/music_menu.wav"),
	game = preload("res://sounds/music_game.wav"),
}
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
## Volumen de la música (más baja que los efectos para que no canse).
const MUSIC_DB := -9.0
const VOICES := 10

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween


func _ready() -> void:
	# La música y los clics siguen sonando con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_bus(MUSIC_BUS)
	_add_bus(SFX_BUS)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_voices.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	_music.volume_db = MUSIC_DB
	add_child(_music)
	apply_settings()
	# Clic en todos los botones del juego, estén donde estén.
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is BaseButton:
			(node as BaseButton).pressed.connect(play.bind("click"))
	)


func _add_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


## Aplica las opciones de música y sonidos (se llama al cambiarlas).
func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not GameState.music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not GameState.sound_on)


## Efecto de sonido. `volume_db` y `pitch` permiten variarlo (golpes más o menos fuertes...).
func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not GameState.sound_on:
		return
	var player := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Cambia la música de fondo ("menu", "game" o "" para silencio) con un fundido corto.
func play_music(music_name: String) -> void:
	if music_name == _music_name:
		return
	_music_name = music_name
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -40.0, 0.4)
	_music_tween.tween_callback(func() -> void:
		if music_name == "":
			_music.stop()
			return
		_music.stream = MUSIC[music_name]
		_music.volume_db = -40.0
		_music.play()
	)
	if music_name != "":
		_music_tween.tween_property(_music, "volume_db", MUSIC_DB, 0.8)


## Reproductor propio para un sonido continuo (rodar), que controla quien lo crea.
func make_loop(sound_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = SOUNDS[sound_name]
	player.bus = SFX_BUS
	return player


## Vibración corta (en el PC no hace nada).
func vibrate(milliseconds: int, amplitude := -1.0) -> void:
	if GameState.vibration_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds, amplitude)

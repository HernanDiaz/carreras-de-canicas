extends Node
## Clasificaciones mundiales y logros (autoload "GameServices"): Game Center en iOS y Servicios
## de Juegos de Google Play en Android. En el PC (o si el jugador no ha iniciado sesión) los logros
## solo se guardan en el aparato y se envían al iniciar sesión.
## Cada nivel tiene su clasificación de mejores tiempos (menos es mejor).

## Identificadores en App Store Connect (los elegimos nosotros).
const IOS_IDS := [
	"level_1_time", "level_2_time", "level_3_time", "level_4_time", "level_5_time",
	"level_6_time", "level_7_time", "level_8_time", "level_9_time",
]
## Identificadores que genera Play Console al crear cada clasificación.
const ANDROID_IDS := [
	"CgkI69erkqoTEAIQAA", "CgkI69erkqoTEAIQAQ", "CgkI69erkqoTEAIQAg",
	"CgkI69erkqoTEAIQAw", "CgkI69erkqoTEAIQBA", "CgkI69erkqoTEAIQBQ",
	"CgkI69erkqoTEAIQBg", "CgkI69erkqoTEAIQBw", "CgkI69erkqoTEAIQCA",
]

## Logros. La clave es también su identificador en App Store Connect; `android` es el que
## genera Play Console. Los textos de cada logro están en las dos consolas (no en el juego).
const ACHIEVEMENTS := {
	first_goal = {android = ""},     # Supera tu primer nivel
	three_stars = {android = ""},    # Consigue 3 estrellas en un nivel
	beat_ghost = {android = ""},     # Mejora un récord tuyo (bate a tu fantasma)
	steady_hand = {android = ""},    # Supera un nivel del 5 al 9 sin caerte
	close_call = {android = ""},     # Llega a la meta con menos de 3 segundos de margen
	wifi_win = {android = ""},       # Gana una carrera Wi-Fi
	all_levels = {android = ""},     # Supera los 9 niveles
	all_stars = {android = ""},      # Consigue las 27 estrellas
}

## Cambia cuando se inicia sesión (o falla): el menú muestra u oculta los botones.
signal availability_changed

var _game_center: Object
var _play_games: Object
var _signed_in := false
## Qué abrir al terminar de iniciar sesión en Android: nivel (>= 0), logros (-2) o nada (-1).
var _pending_show := -1
const _SHOW_ACHIEVEMENTS := -2


func _ready() -> void:
	# Logros que ya corresponden por el progreso guardado (por ejemplo, de la versión anterior).
	check_progress(true)
	if Engine.has_singleton("GameCenterKit"):
		_game_center = Engine.get_singleton("GameCenterKit")
		_game_center.authenticated.connect(_on_authenticated)
		_game_center.authenticate()
	elif Engine.has_singleton("GodotPlayGameServices") and ANDROID_IDS[0] != "":
		_play_games = Engine.get_singleton("GodotPlayGameServices")
		_play_games.initialize()
		_play_games.userAuthenticated.connect(func(ok: bool) -> void: _on_authenticated(ok, ""))
		# Play Games inicia sesión solo al abrir el juego; esto pregunta el resultado.
		_play_games.isAuthenticated()


## true si hay clasificaciones y logros en este aparato (aunque aún no se haya iniciado sesión
## en Android: al pulsar el botón se pide).
func available() -> bool:
	return _signed_in or _play_games != null


## Envía un tiempo. Game Center y Play Games ya se quedan con el mejor de cada jugador.
func submit(level_index: int, seconds: float) -> void:
	if not _signed_in:
		return
	# Game Center ("tiempo transcurrido a la centésima") cuenta en centésimas;
	# Play Games (formato "Tiempo") en milésimas.
	if _game_center != null:
		_game_center.submit_score(IOS_IDS[level_index], int(round(seconds * 100.0)))
	elif _play_games != null:
		_play_games.submitScore(ANDROID_IDS[level_index], int(round(seconds * 1000.0)))


## Abre la clasificación del nivel con la pantalla propia del sistema.
func show_level(level_index: int) -> void:
	_show(level_index)


## Abre la lista de logros del sistema.
func show_achievements() -> void:
	_show(_SHOW_ACHIEVEMENTS)


func _show(what: int) -> void:
	if _game_center != null and _signed_in:
		if what == _SHOW_ACHIEVEMENTS:
			_game_center.show_achievements()
		else:
			_game_center.show_leaderboard(IOS_IDS[what])
	elif _play_games != null:
		if _signed_in:
			_show_play_games(what)
		else:
			_pending_show = what
			_play_games.signIn()


func _show_play_games(what: int) -> void:
	if what == _SHOW_ACHIEVEMENTS:
		_play_games.showAchievements()
	else:
		_play_games.showLeaderboard(ANDROID_IDS[what])


## Consigue un logro (si ya lo tenías no hace nada). Suena (salvo `quiet`) y se envía si hay
## sesión iniciada.
func unlock(key: String, quiet := false) -> void:
	if not ACHIEVEMENTS.has(key) or GameState.achievements.has(key):
		return
	GameState.achievements.append(key)
	GameState.save_data()
	if not quiet:
		Audio.play("achievement")
	_report(key)


## Logros que dependen del progreso guardado (niveles superados y estrellas).
func check_progress(quiet := false) -> void:
	var levels := GameState.LEVELS.size()
	if not GameState.best_times.is_empty():
		unlock("first_goal", quiet)
	for index in levels:
		if GameState.stars_of(index) == 3:
			unlock("three_stars", quiet)
	if GameState.best_times.size() >= levels:
		unlock("all_levels", quiet)
	if GameState.total_stars() >= levels * 3:
		unlock("all_stars", quiet)


func _report(key: String) -> void:
	if not _signed_in:
		return
	if _game_center != null:
		_game_center.report_achievement(key, 100.0)
	elif _play_games != null and ACHIEVEMENTS[key].android != "":
		_play_games.unlockAchievement(ACHIEVEMENTS[key].android)


func _on_authenticated(ok: bool, _error: String) -> void:
	_signed_in = ok
	if ok:
		_submit_saved_progress()
		if _pending_show != -1 and _play_games != null:
			_show_play_games(_pending_show)
	_pending_show = -1
	availability_changed.emit()


## Los récords y logros conseguidos antes de tener sesión (o sin conexión) también cuentan.
func _submit_saved_progress() -> void:
	for index in GameState.best_times:
		submit(index, GameState.best_times[index])
	for key in GameState.achievements:
		_report(key)

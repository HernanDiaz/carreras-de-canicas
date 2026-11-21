extends Node
## Clasificaciones mundiales (autoload "Leaderboards"): Game Center en iOS y Servicios de
## Juegos de Google Play en Android. En el PC (o si el jugador no ha iniciado sesión) no hace nada.
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

## Cambia cuando se inicia sesión (o falla): el menú muestra u oculta los botones.
signal availability_changed

var _game_center: Object
var _play_games: Object
var _signed_in := false
## Nivel cuya clasificación se abrirá al terminar de iniciar sesión (-1 = ninguno).
var _pending_show := -1


func _ready() -> void:
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


## true si hay clasificaciones en este aparato (aunque aún no se haya iniciado sesión en Android:
## al pulsar el botón se pide).
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
	if _game_center != null and _signed_in:
		_game_center.show_leaderboard(IOS_IDS[level_index])
	elif _play_games != null:
		if _signed_in:
			_play_games.showLeaderboard(ANDROID_IDS[level_index])
		else:
			_pending_show = level_index
			_play_games.signIn()


func _on_authenticated(ok: bool, _error: String) -> void:
	_signed_in = ok
	if ok:
		_submit_saved_records()
		if _pending_show >= 0 and _play_games != null:
			_play_games.showLeaderboard(ANDROID_IDS[_pending_show])
	_pending_show = -1
	availability_changed.emit()


## Los récords conseguidos antes de tener clasificaciones (o sin conexión) también cuentan.
func _submit_saved_records() -> void:
	for index in GameState.best_times:
		submit(index, GameState.best_times[index])

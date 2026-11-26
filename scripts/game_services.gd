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
	first_goal = {android = "CgkI69erkqoTEAIQDQ"},     # Supera tu primer nivel
	three_stars = {android = "CgkI69erkqoTEAIQDA"},    # Consigue 3 estrellas en un nivel
	beat_ghost = {android = "CgkI69erkqoTEAIQDw"},     # Mejora un récord tuyo (bate a tu fantasma)
	steady_hand = {android = "CgkI69erkqoTEAIQCw"},    # Supera un nivel del 5 al 9 sin caerte
	close_call = {android = "CgkI69erkqoTEAIQDg"},     # Llega a la meta con menos de 3 segundos de margen
	wifi_win = {android = "CgkI69erkqoTEAIQEA"},       # Gana una carrera Wi-Fi
	all_levels = {android = "CgkI69erkqoTEAIQEQ"},     # Supera todos los niveles
	all_stars = {android = "CgkI69erkqoTEAIQEg"},      # Consigue todas las estrellas
}

## Pedir la valoración de la tienda al superar por primera vez este número de niveles.
const REVIEW_AFTER_LEVELS := [3, 9]
## Nombre del guardado en la nube (Juegos guardados de Play Juegos / clave de iCloud).
const CLOUD_NAME := "progreso"

## Cambia cuando se inicia sesión (o falla): el menú muestra u oculta los botones.
signal availability_changed

var _game_center: Object
var _play_games: Object
var _signed_in := false
## Qué abrir al terminar de iniciar sesión en Android: nivel (>= 0), logros (-2) o nada (-1).
var _pending_show := -1
const _SHOW_ACHIEVEMENTS := -2
## Extras nativos de iOS (valoración e iCloud), compilados con el plugin de Game Center.
var _ios_extras: Object
## Ya se ha mezclado la copia de la nube (antes no se sube nada, para no pisarla).
var _cloud_ready := false
var _cloud_upload_pending := false
var _cloud_conflicts := 0
var _review_manager: Object


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
		_play_games.gameLoaded.connect(_on_snapshot_loaded)
		_play_games.conflictEmitted.connect(_on_snapshot_conflict)
		# Play Games inicia sesión solo al abrir el juego; esto pregunta el resultado.
		_play_games.isAuthenticated()
	# Progreso en iCloud (en iOS no depende de Game Center).
	GameState.progress_changed.connect(_on_progress_changed)
	if Engine.has_singleton("IosExtras"):
		_ios_extras = Engine.get_singleton("IosExtras")
		_ios_extras.cloud_changed.connect(_load_icloud)
		_ios_extras.cloud_sync()
		_load_icloud()


## true si hay clasificaciones y logros en este aparato (aunque aún no se haya iniciado sesión
## en Android: al pulsar el botón se pide).
func available() -> bool:
	return _signed_in or _play_games != null


## true si el nivel tiene clasificación en las dos tiendas. Un nivel nuevo no la tiene hasta
## que se crea en App Store Connect y en Play Console y se añade a IOS_IDS y ANDROID_IDS.
func has_leaderboard(level_index: int) -> bool:
	return level_index >= 0 and level_index < mini(IOS_IDS.size(), ANDROID_IDS.size())


## Envía un tiempo. Game Center y Play Games ya se quedan con el mejor de cada jugador.
func submit(level_index: int, seconds: float) -> void:
	if not _signed_in or not has_leaderboard(level_index):
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
	if what != _SHOW_ACHIEVEMENTS and not has_leaderboard(what):
		return
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
	GameState.progress_changed.emit()
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
		if _play_games != null:
			# Progreso guardado en la nube de Play Juegos (lo crea si aún no existe).
			_play_games.loadGame(CLOUD_NAME, true)
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


# --- Valoración en la tienda ---

## Pide la valoración la primera vez que se superan 3 niveles y al terminarlos todos.
## La ventana es la del sistema y es él quien decide si se muestra (tiene un límite de veces).
func maybe_request_review() -> void:
	var stage := 0
	for levels: int in REVIEW_AFTER_LEVELS:
		if GameState.best_times.size() >= levels:
			stage += 1
	if stage <= GameState.review_stage:
		return
	GameState.review_stage = stage
	GameState.save_data()
	request_review()


func request_review() -> void:
	if _ios_extras != null:
		_ios_extras.request_review()
	elif OS.get_name() == "Android":
		_request_review_android()


## API de valoraciones dentro de la app de Google Play (com.google.android.play:review, que
## añade addons/marble_extras al exportar), llamada directamente desde GDScript.
func _request_review_android() -> void:
	if not Engine.has_singleton("AndroidRuntime"):
		return
	var activity: Object = Engine.get_singleton("AndroidRuntime").getActivity()
	var factory: Object = JavaClassWrapper.wrap("com.google.android.play.core.review.ReviewManagerFactory")
	if activity == null or factory == null:
		return
	_review_manager = factory.create(activity)
	if _review_manager == null:
		return
	_wait_task(_review_manager.requestReviewFlow(), func(info: Object) -> void:
		_review_manager.launchReviewFlow(activity, info)
	)


## Espera a que termine una Task de Google Play y llama a `on_success` con su resultado.
func _wait_task(task: Object, on_success: Callable, tries := 100) -> void:
	if task == null or tries <= 0:
		return
	if not task.isComplete():
		get_tree().create_timer(0.1).timeout.connect(_wait_task.bind(task, on_success, tries - 1))
		return
	if task.isSuccessful():
		on_success.call(task.getResult())


# --- Progreso en la nube ---

func _on_progress_changed() -> void:
	# Se agrupan los cambios seguidos (récord + logros) en una sola subida.
	if _cloud_upload_pending:
		return
	_cloud_upload_pending = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		_cloud_upload_pending = false
		_upload_cloud()
	)


func _upload_cloud() -> void:
	if not _cloud_ready:
		return
	var data := GameState.cloud_data()
	if _ios_extras != null:
		_ios_extras.cloud_set(CLOUD_NAME, data)
	elif _play_games != null and _signed_in:
		_play_games.saveGame(CLOUD_NAME, "Marble Races", data.to_utf8_buffer(), 0, GameState.total_stars())


## Mezcla lo que llega de la nube y, si aquí había algo que allí no, lo sube.
func _merge_cloud(text: String) -> void:
	_cloud_ready = true
	if GameState.merge_cloud(text):
		check_progress(true)
		if _signed_in:
			_submit_saved_progress()
	if GameState.cloud_data() != text:
		_upload_cloud()


func _load_icloud() -> void:
	_merge_cloud(_ios_extras.cloud_get(CLOUD_NAME))


func _on_snapshot_loaded(json_data: String) -> void:
	var snapshot: Variant = JSON.parse_string(json_data)
	_merge_cloud(_snapshot_text(snapshot.get("content") if snapshot is Dictionary else null))


## Dos aparatos guardaron a la vez: se mezclan las dos versiones (no se pierde nada).
func _on_snapshot_conflict(json_data: String) -> void:
	var conflict: Variant = JSON.parse_string(json_data)
	if not conflict is Dictionary:
		return
	for key: String in ["serverSnapshot", "conflictingSnapshot"]:
		var snapshot: Variant = conflict.get(key)
		if snapshot is Dictionary and GameState.merge_cloud(_snapshot_text(snapshot.get("content"))):
			check_progress(true)
	# Se vuelve a subir lo mezclado, pero solo una vez por partida: el plugin no permite
	# resolver el conflicto, y si siguiera habiéndolo se repetiría sin fin.
	_cloud_ready = true
	_cloud_conflicts += 1
	if _cloud_conflicts == 1:
		_upload_cloud()


## El contenido de un guardado de Play Juegos llega como lista de bytes.
func _snapshot_text(content: Variant) -> String:
	if content is Array:
		return PackedByteArray(content).get_string_from_utf8()
	if content is PackedByteArray:
		return content.get_string_from_utf8()
	if content is String:
		return content
	return ""

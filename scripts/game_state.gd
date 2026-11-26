extends Node
## Estado global (autoload "GameState"): lista de niveles, progreso guardado y opciones.

const SAVE_PATH := "user://progreso.cfg"
const GHOST_DIR := "user://fantasmas"
## Tope de datos de un fantasma (de sobra: 10 minutos son ~96 000).
const MAX_GHOST_FLOATS := 1_000_000
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

## El progreso (récords, logros o un reinicio) ha cambiado: se sube a la nube y el menú
## se actualiza. También llega cuando se recibe progreso nuevo de la nube.
signal progress_changed

## Para añadir un nivel: crea su script en res://levels/, añádelo aquí y pon su nombre
## (clave LEVEL_N) en locale/translations.csv. `name` es la clave de traducción: usa tr(name).
## `stars` = tiempos máximos para conseguir 3 y 2 estrellas (terminarlo ya da 1).
const LEVELS := [
	{name = "LEVEL_1", script = "res://levels/level_01.gd", time = 60.0, stars = [25.0, 38.0]},
	{name = "LEVEL_2", script = "res://levels/level_02.gd", time = 60.0, stars = [42.0, 52.0]},
	{name = "LEVEL_3", script = "res://levels/level_03.gd", time = 75.0, stars = [22.0, 35.0]},
	{name = "LEVEL_4", script = "res://levels/level_04.gd", time = 75.0, stars = [34.0, 50.0]},
	{name = "LEVEL_5", script = "res://levels/level_05.gd", time = 80.0, stars = [29.0, 45.0]},
	{name = "LEVEL_6", script = "res://levels/level_06.gd", time = 100.0, stars = [70.0, 85.0]},
	{name = "LEVEL_7", script = "res://levels/level_07.gd", time = 120.0, stars = [80.0, 100.0]},
	{name = "LEVEL_8", script = "res://levels/level_08.gd", time = 100.0, stars = [50.0, 70.0]},
	{name = "LEVEL_9", script = "res://levels/level_09.gd", time = 140.0, stars = [52.0, 85.0]},
	# Tiempos provisionales: hay que ajustarlos jugándolo en el móvil.
	{name = "LEVEL_10", script = "res://levels/level_10.gd", time = 100.0, stars = [50.0, 70.0]},
]

## Idiomas disponibles (columnas de locale/translations.csv). "" = el del sistema.
const LANGUAGES := ["", "en", "es", "pt_BR", "fr", "de", "it", "ru", "tr", "id", "vi", "hi", "ar", "ja", "ko", "zh_CN"]

var current_level := 0
## Cuántos niveles hay desbloqueados (el primero siempre lo está).
var unlocked := 1
## Mejor tiempo por nivel, en segundos. Clave: índice del nivel.
var best_times := {}
## Logros conseguidos (claves de GameServices.ACHIEVEMENTS). Se guardan aquí para enviarlos
## a Game Center / Play Juegos aunque se consigan sin conexión o sin haber iniciado sesión.
var achievements: Array[String] = []
## Veces que se ha reiniciado el progreso (en cualquier aparato). Sirve para que, al mezclar con
## la copia de la nube, un reinicio no se deshaga con los récords antiguos de otro aparato.
var resets := 0
## false en las pruebas automáticas (tools/smoke_test.gd): no se escribe nada en disco.
var persist := true
## Hasta qué punto de REVIEW_AFTER_LEVELS se ha pedido ya la valoración.
var review_stage := 0

# Opciones
var tilt_degrees := 20.0
## false = la inclinación máxima se elige sola según el tamaño de pantalla.
var tilt_custom := false
var invert_x := false
var invert_y := false
var show_debug := false
## Mostrar la canica fantasma de tu mejor vuelta.
var show_ghost := true
var music_on := true
var sound_on := true
var vibration_on := true
var player_name := ""
## IP de la última partida por Wi-Fi a la que te uniste (se rellena sola la próxima vez).
var last_ip := ""
## Idioma elegido a mano ("" = automático, el del sistema).
var language := ""

## Pantalla que abre el menú al volver de una partida ("levels", "lobby"...). Vacío = portada.
var open_screen := ""


func _ready() -> void:
	# La física va a 60 Hz y sin interpolar: en móviles de 90/120 Hz pintar más de 60 imágenes
	# por segundo no se ve más suave (la canica se mueve 60 veces), solo gasta batería y calienta.
	if OS.has_feature("mobile"):
		Engine.max_fps = Engine.physics_ticks_per_second
	load_data()
	apply_language()
	if not tilt_custom:
		tilt_degrees = default_tilt()
	if player_name == "":
		player_name = "%s %d" % [tr("DEFAULT_PLAYER"), randi_range(10, 99)]


func apply_language() -> void:
	TranslationServer.set_locale(language if language != "" else OS.get_locale())


## Pasa al siguiente idioma de la lista (automático → inglés → español → …).
func cycle_language() -> void:
	language = LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()]
	apply_language()
	save_data()


func play(index: int) -> void:
	Net.leave()
	current_level = index
	get_tree().paused = false
	Audio.duck_music(false)
	get_tree().change_scene_to_file(GAME_SCENE)


func go_to_menu(screen := "levels") -> void:
	open_screen = screen
	get_tree().paused = false
	Audio.duck_music(false)
	get_tree().change_scene_to_file(MENU_SCENE)


## Inclinación máxima por defecto: en un móvil se mueve sin querer más que una tablet,
## así que necesita más grados para la misma fuerza.
func default_tilt() -> float:
	return 26.0 if is_phone() else 20.0


## true en móviles (pantalla de menos de 7,5 pulgadas); false en tablets y PC.
func is_phone() -> bool:
	if not OS.has_feature("mobile"):
		return false
	var dpi := DisplayServer.screen_get_dpi()
	if dpi <= 0:
		return false
	return Vector2(DisplayServer.screen_get_size()).length() / dpi < 7.5


func has_next_level() -> bool:
	return current_level + 1 < LEVELS.size()


func is_unlocked(index: int) -> bool:
	return index < unlocked


## Nivel que toca jugar: el primero desbloqueado sin superar; si están todos superados, el
## primero al que le faltan estrellas; y si ya tienes todas, el último que se jugó.
func suggested_level() -> int:
	for i in LEVELS.size():
		if is_unlocked(i) and not best_times.has(i):
			return i
	if unlocked >= LEVELS.size():
		for i in LEVELS.size():
			if stars_of(i) < 3:
				return i
	return current_level


## Registra un nivel superado. Devuelve true si es un nuevo récord.
## `ghost` es la vuelta grabada: se guarda como fantasma si es récord.
func complete_level(index: int, seconds: float, ghost := PackedFloat32Array()) -> bool:
	unlocked = clampi(maxi(unlocked, index + 2), 1, LEVELS.size())
	var record: bool = not best_times.has(index) or seconds < best_times[index]
	if record:
		best_times[index] = seconds
		if not ghost.is_empty():
			save_ghost(index, ghost)
	save_data()
	progress_changed.emit()
	return record


## Estrellas (1 a 3) que da un tiempo en un nivel; 0 si no está superado.
func stars_for(index: int, seconds: float) -> int:
	var limits: Array = LEVELS[index].stars
	if seconds <= limits[0]:
		return 3
	return 2 if seconds <= limits[1] else 1


func stars_of(index: int) -> int:
	return stars_for(index, best_times[index]) if best_times.has(index) else 0


func total_stars() -> int:
	var total := 0
	for index in LEVELS.size():
		total += stars_of(index)
	return total


func reset_progress() -> void:
	resets += 1
	_clear_records()
	save_data()
	progress_changed.emit()


func _clear_records() -> void:
	unlocked = 1
	best_times.clear()
	# Los logros ya conseguidos no se pierden (en Game Center / Play Juegos tampoco).
	for index in LEVELS.size():
		if persist:
			DirAccess.remove_absolute(_ghost_path(index))


## Progreso que se guarda en la nube (iCloud / Juegos guardados de Play Juegos), en JSON.
## Las opciones no: cada aparato tiene las suyas. Los fantasmas tampoco (ocupan mucho).
func cloud_data() -> String:
	var times := {}
	for index in best_times:
		times[str(index)] = best_times[index]
	return JSON.stringify({version = 1, resets = resets, times = times, achievements = achievements})


## Mezcla el progreso de la nube con el de este aparato: se queda con el mejor tiempo de
## cada nivel y con todos los logros. Devuelve true si ha cambiado algo aquí.
func merge_cloud(text: String) -> bool:
	var json := JSON.new()
	if text == "" or json.parse(text) != OK or not json.data is Dictionary:
		return false
	var data: Dictionary = json.data
	var changed := false
	var remote_achievements: Variant = data.get("achievements", [])
	if remote_achievements is Array:
		for key: Variant in remote_achievements:
			if key is String and not achievements.has(key):
				achievements.append(key)
				changed = true
	var remote_resets := int(data.get("resets", 0))
	if remote_resets > resets:
		# Se reinició el progreso en otro aparato después de lo último que hay aquí.
		resets = remote_resets
		_clear_records()
		changed = true
	var times: Variant = data.get("times", {})
	if remote_resets == resets and times is Dictionary:
		for key: Variant in times:
			if not str(key).is_valid_int():
				continue
			var index := int(key)
			var seconds := float(times[key])
			if index < 0 or index >= LEVELS.size() or seconds <= 0.0:
				continue
			if not best_times.has(index) or seconds < best_times[index]:
				best_times[index] = seconds
				changed = true
	if changed:
		for index in best_times:
			unlocked = clampi(maxi(unlocked, index + 2), 1, LEVELS.size())
		save_data()
		progress_changed.emit()
	return changed


func save_ghost(index: int, samples: PackedFloat32Array) -> void:
	if not persist:
		return
	DirAccess.make_dir_recursive_absolute(GHOST_DIR)
	var file := FileAccess.open(_ghost_path(index), FileAccess.WRITE)
	if file != null:
		file.store_buffer(samples.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD))
		file.store_32(samples.size())


func load_ghost(index: int) -> PackedFloat32Array:
	var file := FileAccess.open(_ghost_path(index), FileAccess.READ)
	if file == null or file.get_length() < 4:
		return PackedFloat32Array()
	var packed := file.get_buffer(file.get_length() - 4)
	var count := file.get_32()
	# Un archivo dañado podría pedir una cantidad absurda de memoria: mejor sin fantasma.
	if count == 0 or count > MAX_GHOST_FLOATS:
		return PackedFloat32Array()
	return packed.decompress(count * 4, FileAccess.COMPRESSION_ZSTD).to_float32_array()


## Récords del archivo guardado. Se ignora lo que no tenga sentido (claves raras, niveles que
## no existen en esta versión, tiempos no positivos) para que un archivo dañado no rompa el menú.
func _read_records(cfg: ConfigFile) -> void:
	best_times.clear()
	if not cfg.has_section("records"):
		return
	for key in cfg.get_section_keys("records"):
		var value: Variant = cfg.get_value("records", key)
		if not key.is_valid_int() or not (value is float or value is int):
			continue
		var index := int(key)
		if index >= 0 and index < LEVELS.size() and float(value) > 0.0:
			best_times[index] = float(value)


func _ghost_path(index: int) -> String:
	return "%s/nivel_%d.bin" % [GHOST_DIR, index + 1]


func save_data() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "desbloqueados", unlocked)
	for index in best_times:
		cfg.set_value("records", str(index), best_times[index])
	cfg.set_value("progreso", "logros", achievements)
	cfg.set_value("progreso", "reinicios", resets)
	cfg.set_value("progreso", "valoracion", review_stage)
	cfg.set_value("opciones", "inclinacion", tilt_degrees)
	cfg.set_value("opciones", "inclinacion_elegida", tilt_custom)
	cfg.set_value("opciones", "invertir_x", invert_x)
	cfg.set_value("opciones", "invertir_y", invert_y)
	cfg.set_value("opciones", "datos_sensor", show_debug)
	cfg.set_value("opciones", "fantasma", show_ghost)
	cfg.set_value("opciones", "musica", music_on)
	cfg.set_value("opciones", "sonidos", sound_on)
	cfg.set_value("opciones", "vibracion", vibration_on)
	cfg.set_value("opciones", "nombre", player_name)
	cfg.set_value("opciones", "ultima_ip", last_ip)
	cfg.set_value("opciones", "idioma", language)
	cfg.save(SAVE_PATH)


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_apply_config(cfg)


## Aplica lo leído del archivo. Cada valor se comprueba: si tiene un tipo que no toca (archivo
## dañado o editado a mano) se queda el valor por defecto en vez de dar error al arrancar.
func _apply_config(cfg: ConfigFile) -> void:
	unlocked = clampi(_value(cfg, "progreso", "desbloqueados", 1), 1, LEVELS.size())
	_read_records(cfg)
	achievements.assign(_value(cfg, "progreso", "logros", []).filter(func(a: Variant) -> bool: return a is String))
	resets = maxi(_value(cfg, "progreso", "reinicios", 0), 0)
	review_stage = _value(cfg, "progreso", "valoracion", 0)
	# Si una actualización añade niveles, el siguiente al último superado queda desbloqueado.
	for index in best_times:
		unlocked = clampi(maxi(unlocked, index + 2), 1, LEVELS.size())
	tilt_degrees = clampf(_value(cfg, "opciones", "inclinacion", tilt_degrees), 10.0, 35.0)
	tilt_custom = _value(cfg, "opciones", "inclinacion_elegida", false)
	invert_x = _value(cfg, "opciones", "invertir_x", invert_x)
	invert_y = _value(cfg, "opciones", "invertir_y", invert_y)
	show_debug = _value(cfg, "opciones", "datos_sensor", show_debug)
	show_ghost = _value(cfg, "opciones", "fantasma", show_ghost)
	music_on = _value(cfg, "opciones", "musica", music_on)
	sound_on = _value(cfg, "opciones", "sonidos", sound_on)
	vibration_on = _value(cfg, "opciones", "vibracion", vibration_on)
	player_name = _value(cfg, "opciones", "nombre", player_name)
	last_ip = _value(cfg, "opciones", "ultima_ip", "")
	if not last_ip.is_valid_ip_address():
		last_ip = ""
	language = _value(cfg, "opciones", "idioma", language)
	if language not in LANGUAGES:
		language = ""


## Valor del archivo si es del mismo tipo que `default` (un entero vale donde se espera un
## decimal); si no, `default`.
func _value(cfg: ConfigFile, section: String, key: String, default: Variant) -> Variant:
	var value: Variant = cfg.get_value(section, key, default)
	if typeof(value) == typeof(default):
		return value
	if default is float and value is int:
		return float(value)
	return default

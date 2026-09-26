extends Node
## Estado global (autoload "GameState"): lista de niveles, progreso guardado y opciones.

const SAVE_PATH := "user://progreso.cfg"
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

## Para añadir un nivel: crea su script en res://levels/, añádelo aquí y pon su nombre
## (clave LEVEL_N) en locale/translations.csv. `name` es la clave de traducción: usa tr(name).
const LEVELS := [
	{name = "LEVEL_1", script = "res://levels/level_01.gd", time = 60.0},
	{name = "LEVEL_2", script = "res://levels/level_02.gd", time = 60.0},
	{name = "LEVEL_3", script = "res://levels/level_03.gd", time = 75.0},
	{name = "LEVEL_4", script = "res://levels/level_04.gd", time = 75.0},
	{name = "LEVEL_5", script = "res://levels/level_05.gd", time = 80.0},
	{name = "LEVEL_6", script = "res://levels/level_06.gd", time = 100.0},
]

## Idiomas disponibles (columnas de locale/translations.csv). "" = el del sistema.
const LANGUAGES := ["", "en", "es", "pt_BR", "fr", "de", "it", "ru", "tr", "id", "vi", "hi", "ar", "ja", "ko", "zh_CN"]

var current_level := 0
## Cuántos niveles hay desbloqueados (el primero siempre lo está).
var unlocked := 1
## Mejor tiempo por nivel, en segundos. Clave: índice del nivel.
var best_times := {}

# Opciones
var tilt_degrees := 20.0
## false = la inclinación máxima se elige sola según el tamaño de pantalla.
var tilt_custom := false
var invert_x := false
var invert_y := false
var show_debug := false
var player_name := ""
## Idioma elegido a mano ("" = automático, el del sistema).
var language := ""

## Pantalla que abre el menú al volver de una partida ("levels", "lobby"...). Vacío = portada.
var open_screen := ""


func _ready() -> void:
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
	get_tree().change_scene_to_file(GAME_SCENE)


func go_to_menu(screen := "levels") -> void:
	open_screen = screen
	get_tree().paused = false
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


## Registra un nivel superado. Devuelve true si es un nuevo récord.
func complete_level(index: int, seconds: float) -> bool:
	unlocked = clampi(maxi(unlocked, index + 2), 1, LEVELS.size())
	var record: bool = not best_times.has(index) or seconds < best_times[index]
	if record:
		best_times[index] = seconds
	save_data()
	return record


func reset_progress() -> void:
	unlocked = 1
	best_times.clear()
	save_data()


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progreso", "desbloqueados", unlocked)
	for index in best_times:
		cfg.set_value("records", str(index), best_times[index])
	cfg.set_value("opciones", "inclinacion", tilt_degrees)
	cfg.set_value("opciones", "inclinacion_elegida", tilt_custom)
	cfg.set_value("opciones", "invertir_x", invert_x)
	cfg.set_value("opciones", "invertir_y", invert_y)
	cfg.set_value("opciones", "datos_sensor", show_debug)
	cfg.set_value("opciones", "nombre", player_name)
	cfg.set_value("opciones", "idioma", language)
	cfg.save(SAVE_PATH)


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked = clampi(cfg.get_value("progreso", "desbloqueados", 1), 1, LEVELS.size())
	best_times.clear()
	if cfg.has_section("records"):
		for key in cfg.get_section_keys("records"):
			best_times[int(key)] = float(cfg.get_value("records", key))
	tilt_degrees = cfg.get_value("opciones", "inclinacion", tilt_degrees)
	tilt_custom = cfg.get_value("opciones", "inclinacion_elegida", false)
	invert_x = cfg.get_value("opciones", "invertir_x", invert_x)
	invert_y = cfg.get_value("opciones", "invertir_y", invert_y)
	show_debug = cfg.get_value("opciones", "datos_sensor", show_debug)
	player_name = cfg.get_value("opciones", "nombre", player_name)
	language = cfg.get_value("opciones", "idioma", language)

extends SceneTree
## Genera las capturas para la App Store con el render real del juego.
## Uso (necesita ventana, no --headless):
##   godot --path . --resolution 640x360 -s res://tools/screenshots.gd
## Salida: build/screenshots/<idioma>/<dispositivo>_<n>.png

const OUT_DIR := "res://build/screenshots"

## Tamaños exigidos por App Store Connect (horizontal). `ui` es el tamaño virtual de la
## interfaz: 720 de alto como en el juego, y el ancho según la proporción de la pantalla.
const DEVICES := {
	# App Store Connect pide la pantalla de 6,5" (las demás se generan a partir de esta)
	"iphone65": {size = Vector2i(2778, 1284), ui = Vector2i(1558, 720)},
	"ipad13": {size = Vector2i(2752, 2064), ui = Vector2i(960, 720)},
	# Google Play: el teléfono admite como mucho una proporción 2:1. Sin la interfaz del juego.
	"android": {size = Vector2i(1920, 1080), ui = Vector2i(1280, 720), hud = false},
	# Gráfico de funciones de Google Play: sin interfaz ni texto (el título se añade aparte)
	"feature": {size = Vector2i(1024, 500), ui = Vector2i(1475, 720), hud = false, caption = false},
}

const CAPTIONS := {
	"en": [
		"Watch out for hungry worms",
		"Dodge crushers and conveyor belts",
		"Spiral slides and wild descents",
		"Brave the wind and the maze",
		"Climb the great tower",
		"Race your friends over Wi‑Fi",
	],
	"es": [
		"Cuidado con los gusanos hambrientos",
		"Esquiva prensas y cintas transportadoras",
		"Toboganes en espiral y bajadas de vértigo",
		"Desafía al viento y al laberinto",
		"Sube a la gran torre",
		"Echa carreras con tus amigos por Wi‑Fi",
	],
}

## Cada captura: nivel, posición de la canica y, si hace falta, el tiempo del nivel al colocarla
## (`time`) y cuándo se toma: al llegar el nivel a `shoot_at` segundos, cuando el gusano está
## junto a la canica (`worm`) o, si no, a los 60 fotogramas. Renderizar a este tamaño es lento,
## así que contar fotogramas no sirve para momentos concretos.
const SHOTS := [
	# El gusano sale del agujero y va a por la canica (se toma antes de que se la coma)
	{level = 6, marble = Vector3(0.2, -3.5, -22.2), worm = true},
	# Pasillo de prensas: la del medio está cayendo
	{level = 6, marble = Vector3(0, -3.5, -52.25), time = 2.43},
	# Tobogán en espiral bajando hacia la meta
	{level = 6, marble = Vector3(25.24, -10.18, -134.8)},
	# Cresta con viento de costado y el laberinto detrás (en plena racha)
	{level = 7, marble = Vector3(8.5, -5.0, -60.5), time = 0.4, shoot_at = 1.6},
	# Subida a la torre esquivando barriles
	{level = 8, marble = Vector3(1.2, 2.7, -9.5), time = 1.0},
	# Carrera en la cima de la torre
	{level = 8, marble = Vector3(20.5, 10.5, -44.5), rivals = true},
]

## Rivales de la captura de carrera, colocados respecto a la canica.
const RIVALS := [
	{name = "Ana", slot = 1, offset = Vector3(-2.2, 0, 1.6)},
	{name = "Luis", slot = 2, offset = Vector3(1.9, 0, -1.2)},
	{name = "Sofía", slot = 3, offset = Vector3(-0.8, 0, -2.6)},
]

var _jobs := []
var _job := -1
var _frame := 0
var _viewport: SubViewport
var _scene: Node
var _placed := false


func _initialize() -> void:
	for locale in CAPTIONS:
		for device in _devices():
			for i in SHOTS.size():
				_jobs.append({locale = locale, device = device, index = i})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# La primera captura se lanza en el primer fotograma: antes, el autoload GameState
	# todavía no ha aplicado el idioma del sistema y lo pisaría.


## Dispositivos a generar: todos, o solo los indicados tras "--" (p. ej. -- android).
func _devices() -> Array:
	var wanted := OS.get_cmdline_user_args()
	if wanted.is_empty():
		return DEVICES.keys()
	return DEVICES.keys().filter(func(d: String) -> bool: return d in wanted)


func _next() -> void:
	if _viewport != null:
		_viewport.queue_free()
		_viewport = null
	_job += 1
	if _job >= _jobs.size():
		print("Listo: %d capturas en %s" % [_jobs.size(), ProjectSettings.globalize_path(OUT_DIR)])
		quit()
		return
	var job: Dictionary = _jobs[_job]
	var device: Dictionary = DEVICES[job.device]
	var shot: Dictionary = SHOTS[job.index]
	TranslationServer.set_locale(job.locale)

	_viewport = SubViewport.new()
	_viewport.size = device.size
	_viewport.size_2d_override = device.ui
	_viewport.size_2d_override_stretch = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	root.get_node("GameState").current_level = shot.level
	_scene = load("res://scenes/game.tscn").instantiate()
	_viewport.add_child(_scene)
	if device.get("caption", true):
		_add_caption(CAPTIONS[job.locale][job.index], device.ui.x)
	_frame = 0
	_placed = false


func _process(_delta: float) -> bool:
	if _job == -1:
		_next()
		return false
	if _viewport == null:
		return false
	_frame += 1
	var shot: Dictionary = SHOTS[_jobs[_job].index]

	if not _placed:
		_scene._countdown = 0.0
		if _scene.state == _scene.State.PLAYING:
			_place(shot)
			_placed = true
			_frame = 0
		return false

	if _frame >= 20 and _ready_to_shoot(shot):
		var job: Dictionary = _jobs[_job]
		var path := "%s/%s/%s_%d.png" % [OUT_DIR, job.locale, job.device, job.index + 1]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		_viewport.get_texture().get_image().save_png(path)
		print("  %s" % path)
		_next()
	return false


func _ready_to_shoot(shot: Dictionary) -> bool:
	if shot.has("worm"):
		# Con la boca abierta a punto de alcanzarla, pero sin habérsela comido aún.
		for node in _scene.level.get_children():
			var worm := node as Worm
			if worm != null and worm._emerge >= 1.0:
				var head: Vector3 = worm._points[0]
				var marble: Vector3 = _scene.marble.global_position
				return Vector2(head.x - marble.x, head.z - marble.z).length() < 1.9
		return false
	if shot.has("shoot_at"):
		return _scene.level._time >= shot.shoot_at
	return _frame >= 60


## Coloca la canica (quieta) donde queda bien la foto y quita los mensajes de la partida.
func _place(shot: Dictionary) -> void:
	var marble: RigidBody3D = _scene.marble
	marble.stop_in_place()
	marble.global_position = shot.marble
	marble.rotation = Vector3(0.4, 1.1, 0.2)
	var camera: Camera3D = _scene.camera
	camera.global_position = shot.marble + camera.offset
	_scene.message_label.visible = false
	_scene.hud.visible = DEVICES[_jobs[_job].device].get("hud", true)
	_scene._message_time = 0.0
	if shot.has("time"):
		_scene.level._time = shot.time
	if shot.get("rivals", false):
		var mesh: Mesh = (marble.get_node("Mesh") as MeshInstance3D).mesh
		for rival in RIVALS:
			var remote := RemoteMarble.new()
			_scene.add_child(remote)
			remote.setup(mesh, root.get_node("Net").COLORS[rival.slot], rival.name)
			remote.push_state(shot.marble + rival.offset, Vector3.ZERO, Quaternion(Vector3.UP, rival.slot))


## Franja inferior con el texto de la captura.
func _add_caption(text: String, ui_width: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var band := ColorRect.new()
	band.color = Color(0.05, 0.02, 0.13, 0.82)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -118.0
	layer.add_child(band)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	# En iPad la interfaz es más estrecha (960 frente a 1564): letra más pequeña para que quepa.
	label.add_theme_font_size_override("font_size", 50 if ui_width > 1200 else 38)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.06))
	label.add_theme_constant_override("outline_size", 10)
	band.add_child(label)
	_viewport.add_child(layer)

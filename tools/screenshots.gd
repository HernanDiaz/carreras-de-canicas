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
}

const CAPTIONS := {
	"en": [
		"Tilt your phone to roll",
		"Ramps, bridges and tricky tracks",
		"Dodge the steel marbles",
		"Time your moves past the pendulums",
		"Race your friends over Wi‑Fi",
	],
	"es": [
		"Inclina el móvil para rodar",
		"Rampas, puentes y pistas con trampa",
		"Esquiva las canicas de acero",
		"Esquiva los péndulos a tiempo",
		"Echa carreras con tus amigos por Wi‑Fi",
	],
}

## Cada captura: escena y, en las de partida, nivel y posición de la canica.
const SHOTS := [
	{scene = "menu"},
	{scene = "game", level = 0, marble = Vector3(0.0, -1.2, -7.5)},
	{scene = "game", level = 3, marble = Vector3(0.6, -1.5, -14.5)},
	{scene = "game", level = 4, marble = Vector3(0.0, 0.5, -29.0)},
	{scene = "game", level = 0, marble = Vector3(0.9, -2.5, -13.2), rivals = true},
]

const RIVALS := [
	{name = "Ana", slot = 1, pos = Vector3(-1.3, -2.5, -12.0)},
	{name = "Luis", slot = 2, pos = Vector3(1.8, -2.5, -15.6)},
	{name = "Sofía", slot = 3, pos = Vector3(-0.4, -1.5, -9.8)},
]

var _jobs := []
var _job := -1
var _frame := 0
var _viewport: SubViewport
var _scene: Node
var _placed := false


func _initialize() -> void:
	for locale in CAPTIONS:
		for device in DEVICES:
			for i in SHOTS.size():
				_jobs.append({locale = locale, device = device, index = i})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# La primera captura se lanza en el primer fotograma: antes, el autoload GameState
	# todavía no ha aplicado el idioma del sistema y lo pisaría.


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

	if shot.scene == "menu":
		root.get_node("GameState").open_screen = "main"
		_scene = load("res://scenes/menu.tscn").instantiate()
	else:
		root.get_node("GameState").current_level = shot.level
		_scene = load("res://scenes/game.tscn").instantiate()
	_viewport.add_child(_scene)
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

	if shot.scene == "menu" and _frame == 2:
		_hide_menu_extras()

	if shot.scene == "game" and not _placed:
		_scene._countdown = 0.0
		if _scene.state == _scene.State.PLAYING:
			_place(shot)
			_placed = true
			_frame = 0
		return false

	if _frame == 60:
		var job: Dictionary = _jobs[_job]
		var path := "%s/%s/%s_%d.png" % [OUT_DIR, job.locale, job.device, job.index + 1]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		_viewport.get_texture().get_image().save_png(path)
		print("  %s" % path)
		_next()
	return false


## Coloca la canica (quieta) donde queda bien la foto y quita los mensajes de la partida.
func _place(shot: Dictionary) -> void:
	var marble: RigidBody3D = _scene.marble
	marble.stop_in_place()
	marble.global_position = shot.marble
	marble.rotation = Vector3(0.4, 1.1, 0.2)
	var camera: Camera3D = _scene.camera
	camera.global_position = shot.marble + camera.offset
	_scene.message_label.visible = false
	_scene._message_time = 0.0
	if shot.get("rivals", false):
		var mesh: Mesh = (marble.get_node("Mesh") as MeshInstance3D).mesh
		for rival in RIVALS:
			var remote := RemoteMarble.new()
			_scene.add_child(remote)
			remote.setup(mesh, root.get_node("Net").COLORS[rival.slot], rival.name)
			remote.push_state(rival.pos, Vector3.ZERO, Quaternion(Vector3.UP, rival.slot))


## En iPhone no existe el botón Salir, y el de idioma quedaría tapado por el texto de la captura.
func _hide_menu_extras() -> void:
	for button in _scene.find_children("*", "Button", true, false):
		if button.text == tr("MENU_QUIT") or button.theme_type_variation == UI.SECONDARY:
			button.visible = false


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

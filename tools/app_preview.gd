extends SceneTree
## Graba el vídeo de vista previa de la App Store: varios clips de los niveles jugados por un
## piloto automático, cada uno con su texto. Se renderiza en un SubViewport del tamaño exacto
## que pide App Store Connect (el modo Movie Maker usa el tamaño del proyecto) y se guarda cada
## fotograma; --fixed-fps hace que cada fotograma avance exactamente 1/30 s:
##   godot --path . --resolution 640x360 --fixed-fps 30 -s res://tools/app_preview.gd -- es 1920x886
## Escribe build/preview/<idioma>_<tamaño>/f00000000.png... y segments.txt (los fotogramas de
## cada clip), que tools/make_preview.py une en un .mp4 con ffmpeg.

const OUT_DIR := "res://build/preview"
const Y := -1.5

const CAPTIONS := {
	"en": [
		"Tilt to roll… and run from the worms!",
		"Time your moves past the crushers",
		"Fight the wind on wobbly seesaws",
		"Dodge the barrels up the tower",
		"9 wild levels. Race your friends!",
	],
	"es": [
		"¡Inclina para rodar… y huye de los gusanos!",
		"Calcula el momento bajo las prensas",
		"Lucha contra el viento en los balancines",
		"Esquiva los barriles hasta la torre",
		"9 niveles de locura. ¡Reta a tus amigos!",
	],
}

## Cada clip: nivel, dónde empieza la canica, el tiempo del nivel al empezar (para que las
## trampas estén en el punto adecuado), cuánto dura y los puntos de paso del piloto.
## Un paso con `wait` espera a que la fase (periodo, desfase) esté entre lo y hi.
var clips := [
	{level = 6, start = Vector3(0.6, -3.5, -20.3), seconds = 5.5, steps = [
		{to = Vector3(0.6, Y, -20.3), pause = 0.5},
		{to = Vector3(2.4, Y, -22.0), speed = 3.0},
		{to = Vector3(2.0, Y, -25.5), speed = 3.0},
		{to = Vector3(-1.5, Y, -25.8), speed = 3.0},
		{to = Vector3(0, Y, -26.5), speed = 3.0},
		{to = Vector3(0, Y, -38), speed = 6.0},
	]},
	{level = 6, start = Vector3(0, -3.5, -47.6), seconds = 5.5, steps = [
		{to = Vector3(0, Y, -48.4), speed = 3.0, stop = true},
		{to = Vector3(0, Y, -48.4), wait = [2.6, 0.0, 0.87, 0.93]},
		{to = Vector3(0, Y, -52.25), speed = 4.0, stop = true},
		{to = Vector3(0, Y, -52.25), wait = [2.6, 0.4, 0.87, 0.93]},
		{to = Vector3(0, Y, -55.75), speed = 4.0, stop = true},
		{to = Vector3(0, Y, -55.75), wait = [2.6, 0.8, 0.87, 0.93]},
		{to = Vector3(0, Y, -62), speed = 4.0},
	]},
	{level = 7, start = Vector3(0, -3.5, -36.5), time = 3.3, seconds = 6.0, steps = [
		{to = Vector3(0, Y, -42.8), speed = 4.0},
		{to = Vector3(0, Y, -47.5), speed = 2.5},
		{to = Vector3(0, Y, -52), speed = 2.5},
		{to = Vector3(0, Y, -57), speed = 2.5},
	]},
	# Sube por el carril izquierdo justo después de que pase su barril, mientras otro baja
	# rodando por el carril de al lado
	{level = 8, start = Vector3(-1.2, 1.6, -6.0), time = 4.4, seconds = 4.0, steps = [
		{to = Vector3(-1.2, Y, -15.5), speed = 4.6},
		{to = Vector3(-0.5, Y, -19), speed = 3.0},
	]},
	# Desde media espiral del tobogán hasta la meta
	{level = 6, start = Vector3(27.8, -11.0, -132.24), seconds = 7.0, steps = [
		# Espiral del tobogán: eje (24, -131), radio 4, 1,25 vueltas
		{spiral = true},
		{to = Vector3(29, Y, -135), speed = 4.0},
		{to = Vector3(32, Y, -135), speed = 2.0, stop = true},
	]},
]

var _locale := "en"
var _out_dir := OUT_DIR
var _size := Vector2i(1920, 886)
var _viewport: SubViewport
var _saved := 0
var _clip := -1
var _scene: Node
var _steps: Array = []
var _step := 0
var _frame := 0
var _clip_start := -1
var _clip_time := 0.0
var _placed := false
var _lane := 1.2
var _pause_left := -1.0
var _segments := PackedStringArray()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and CAPTIONS.has(args[0]):
		_locale = args[0]
	if args.size() > 1:
		var parts := args[1].split("x")
		_size = Vector2i(int(parts[0]), int(parts[1]))
	_out_dir = "%s/%s_%dx%d" % [OUT_DIR, _locale, _size.x, _size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_viewport = SubViewport.new()
	_viewport.size = _size
	# Interfaz de 720 de alto, como en el juego; el ancho según la proporción.
	_viewport.size_2d_override = Vector2i(roundi(720.0 * _size.x / _size.y), 720)
	_viewport.size_2d_override_stretch = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)


func _process(delta: float) -> bool:
	_frame += 1
	if _clip == -1:
		# Primer fotograma: el autoload GameState ya ha aplicado el idioma del sistema.
		TranslationServer.set_locale(_locale)
		_next_clip()
		return false
	var clip: Dictionary = clips[_clip]
	_scene._countdown = 0.0
	_scene.message_label.visible = false
	if _scene._overlay != null:
		# El juego se pausa solo si la ventana pierde el foco: se reanuda y, si ya se estaba
		# grabando el clip, se repite para que no salga el menú de pausa en el vídeo.
		_scene._resume()
		if _clip_start != -1:
			print("clip %d: pausa, se repite" % _clip)
			_saved = _clip_start
			_clip -= 1
			_next_clip()
		return false
	if _scene.state != _scene.State.PLAYING:
		return false
	if not _placed:
		_place(clip)
		return false
	if _clip_start == -1:
		# Unos fotogramas para que la cámara llegue a su sitio.
		if _clip_time > 0.25:
			_clip_start = _saved
		_clip_time += delta
		return false
	_clip_time += delta
	_viewport.get_texture().get_image().save_png("%s/f%08d.png" % [_out_dir, _saved])
	_saved += 1
	if _clip_time >= clip.seconds + 0.25:
		_segments.append("%d %d" % [_clip_start, _saved])
		print("clip %d: fotogramas %d-%d" % [_clip, _clip_start, _saved])
		_next_clip()
	return false


func _physics_process(_delta: float) -> bool:
	if _placed and _scene != null and _scene.state == _scene.State.PLAYING:
		_drive()
	return false


func _next_clip() -> void:
	_release_keys()
	if _scene != null:
		_scene.queue_free()
		_scene = null
	_clip += 1
	if _clip >= clips.size():
		var file := FileAccess.open(_out_dir + "/segments.txt", FileAccess.WRITE)
		file.store_string("\n".join(_segments) + "\n")
		file.close()
		print("Listo: %d clips" % clips.size())
		quit()
		return
	var clip: Dictionary = clips[_clip]
	root.get_node("GameState").current_level = clip.level
	_scene = load("res://scenes/game.tscn").instantiate()
	_viewport.add_child(_scene)
	_add_caption(CAPTIONS[_locale][_clip])
	_placed = false
	_clip_start = -1
	_clip_time = 0.0
	_step = 0
	_steps = _expand_steps(clip.steps)


## Sustituye el paso `spiral` por puntos a lo largo del tobogán del nivel 7.
func _expand_steps(steps: Array) -> Array:
	var out := []
	for s in steps:
		if s.get("spiral", false):
			for i in range(4, 11):
				var a := 2.5 * PI * i / 10.0
				out.append({to = Vector3(24 - 4 * cos(a), Y, -131 - 4 * sin(a)), speed = 5.0})
		else:
			out.append(s)
	return out


func _place(clip: Dictionary) -> void:
	var marble: RigidBody3D = _scene.marble
	marble.respawn(clip.start)
	_scene.respawn_point = clip.start
	_scene.camera.global_position = clip.start + _scene.camera.offset
	if clip.has("time"):
		_scene.level._time = clip.time
	_placed = true


func _drive() -> void:
	var m: RigidBody3D = _scene.marble
	if _step >= _steps.size():
		_release_keys()
		return
	var s: Dictionary = _steps[_step]
	var target: Vector3 = s.to
	var desired := Vector3.ZERO
	if s.has("pause"):
		desired = (target - m.global_position) * 2.0
		_pause_left = (s.pause if _pause_left < 0.0 else _pause_left) - 1.0 / Engine.physics_ticks_per_second
		if _pause_left <= 0.0:
			_pause_left = -1.0
			_step += 1
	elif s.has("wait"):
		desired = (target - m.global_position) * 2.0
		var w: Array = s.wait
		var p := fposmod(_scene.level._time / w[0] + w[1], 1.0)
		if p > w[2] and p < w[3]:
			_step += 1
	else:
		if s.get("climb", false):
			target.x = _best_lane(m)
		var to := target - m.global_position
		to.y = 0.0
		var dist := to.length()
		var speed: float = s.speed
		if s.get("stop", false):
			speed = minf(speed, dist * 1.5)
		desired = to.normalized() * speed if dist > 0.01 else Vector3.ZERO
		if dist < (0.4 if s.get("stop", false) else 1.0) and not s.get("climb", false) or \
				(s.get("climb", false) and m.global_position.z < target.z + 0.5):
			_step += 1
	var vel := m.linear_velocity
	vel.y = 0.0
	var err := desired - vel
	var cam: Camera3D = _scene.camera
	var right := cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -cam.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	_press(clampf(err.dot(right) * 1.5, -1, 1), clampf(err.dot(forward) * 1.5, -1, 1))


## Carril de la rampa de barriles (x = ±1.2) con el barril más lejano por delante.
func _best_lane(m: Node3D) -> float:
	if _threat(m, _lane) < 4.0 and _threat(m, -_lane) > _threat(m, _lane):
		_lane = -_lane
	return _lane


func _threat(m: Node3D, lane: float) -> float:
	var gap := INF
	for b in _scene.level.get_children():
		if b is AnimatableBody3D and b.visible and b.get_child(0) is CollisionShape3D \
				and b.get_child(0).shape is CylinderShape3D and absf(b.global_position.x) < 2.5 \
				and b.global_position.z > -15.5 and b.global_position.z < -2.5 \
				and signf(b.global_position.x) == signf(lane) and b.global_position.z < m.global_position.z + 0.8:
			gap = minf(gap, m.global_position.z - b.global_position.z)
	return gap


func _press(x: float, y: float) -> void:
	_release_keys()
	if x > 0.0:
		Input.action_press("ui_right", x)
	elif x < 0.0:
		Input.action_press("ui_left", -x)
	if y > 0.0:
		Input.action_press("ui_up", y)
	elif y < 0.0:
		Input.action_press("ui_down", -y)


func _release_keys() -> void:
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(action)


## Franja inferior con el texto del clip (como en las capturas).
func _add_caption(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var band := ColorRect.new()
	band.color = Color(0.05, 0.02, 0.13, 0.82)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -110.0
	layer.add_child(band)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.add_theme_font_size_override("font_size", 46 if _viewport.size_2d_override.x > 1200 else 36)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.06))
	label.add_theme_constant_override("outline_size", 10)
	band.add_child(label)
	_scene.add_child(layer)

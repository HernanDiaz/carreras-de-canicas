class_name Marble
extends RigidBody3D
## Canica controlada por la inclinación del móvil (o flechas del teclado en PC).

@export var roll_force := 20.0
## Fracción de control que conservas en el aire.
@export var air_control := 0.3
## Fracción de control sobre hielo.
@export var ice_control := 0.3
## Fuerza con la que la canica acompaña a una plataforma móvil.
@export var platform_grip := 12.0
## Grados de inclinación respecto a la posición calibrada para empuje máximo.
@export var max_tilt_degrees := 20.0
@export var dead_zone := 0.06
## Curva de respuesta: 1 = lineal; más alto = los primeros grados empujan poco (control fino)
## y la fuerza crece rápido al acercarse a max_tilt_degrees.
@export var response_exponent := 1.5
## Suavizado del control (más alto = responde más rápido, pero con más temblor).
@export var input_smoothing := 12.0
## Filtro del sensor: el de gravedad ya viene filtrado; el acelerómetro recoge el pulso de la mano.
@export var gravity_filter := 25.0
@export var accelerometer_filter := 7.0
@export var max_speed := 12.0
## Si en tu móvil algún eje va al revés, activa estas opciones.
@export var invert_x := false
@export var invert_y := false

## Golpe contra algo (pared, otra canica) o aterrizaje: `strength` es el cambio brusco de
## velocidad en m/s y `landing` dice si ha sido sobre todo vertical (caer al suelo).
signal impact(strength: float, landing: bool)

## Cambio de velocidad mínimo (m/s, sin contar la gravedad) que cuenta como golpe.
const IMPACT_THRESHOLD := 2.2
## Zona muerta del stick analógico (los sticks gastados no vuelven del todo al centro).
const STICK_DEAD_ZONE := 0.15
## Segundos tras reaparecer en los que canicas de acero y gusanos no te persiguen: si uno
## ronda el punto de control, te daría tiempo a apartarte en vez de caer una y otra vez.
const RESPAWN_PROTECTION := 1.5

var camera: Camera3D
## Sustituye al sensor en el PC (arrastrar con el ratón).
var tilt_simulator: TiltSimulator
var controls_enabled := false

var _neutral := Vector3.ZERO
var _input := Vector2.ZERO
var _grounded := false
var _on_ice := false
var _ground_velocity := Vector3.ZERO
## Aceleración que da el suelo (cintas transportadoras).
var _ground_push := Vector3.ZERO
var _ground_grip := 0.0
var _sensor := Vector3.ZERO
var _sensor_source := ""
var _pending_respawn: Variant = null
var _tween: Tween
var _blink_tween: Tween
var _last_velocity := Vector3.ZERO
## Fotogramas en los que no se detectan golpes (tras reaparecer, la velocidad cambia de golpe).
var _impact_mute := 0
var _impact_cooldown := 0.0
var _protection := 0.0
## Consulta de suelo reutilizada (se hace en cada paso de física).
var _ground_query := PhysicsRayQueryParameters3D.new()


## Guarda la posición actual del móvil como "plano".
func _ready() -> void:
	# Si se duerme, no se despierta cuando desaparece el suelo (trampillas).
	can_sleep = false
	add_to_group(Chaser.TARGET_GROUP)


func calibrate() -> void:
	_neutral = _read_sensor()


func respawn(pos: Vector3) -> void:
	# Un RigidBody se teletransporta en _integrate_forces para no pelearse con la física.
	_stop_tween()
	visible = true
	freeze = false
	_pending_respawn = pos
	sleeping = false
	_impact_mute = 3
	_protection = RESPAWN_PROTECTION
	_blink()


## Parpadeo corto al reaparecer, para encontrar la canica de un vistazo.
func _blink() -> void:
	var mesh: Node3D = get_node_or_null("Mesh")
	if mesh == null:
		return
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops(4)
	_blink_tween.tween_callback(mesh.hide).set_delay(0.08)
	_blink_tween.tween_callback(mesh.show).set_delay(0.08)


## Devuelve la canica a la física y activa los controles (inicio de partida).
func release() -> void:
	freeze = false
	sleeping = false
	controls_enabled = true
	calibrate()


## Detiene la canica en seco y la saca de la física (fin de partida).
func stop_in_place() -> void:
	controls_enabled = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


## Un gusano se ha comido la canica: desaparece y se queda quieta hasta reaparecer.
func swallow() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	visible = false


## Lleva la canica al centro de la meta, la eleva y la hace girar.
func celebrate(center: Vector3) -> void:
	stop_in_place()
	_stop_tween()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", center + Vector3(0, 0.5, 0), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", center + Vector3(0, 1.1, 0), 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation:y", rotation.y + TAU * 3.0, 1.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func debug_text() -> String:
	return "sensor (%s): %s   input: %s   suelo: %s" % [
		_sensor_source, _read_sensor().snapped(Vector3.ONE * 0.1), _input.snapped(Vector2.ONE * 0.01), _grounded]


## Aplica la zona muerta y la curva de respuesta a una inclinación ya normalizada (1 = max_tilt_degrees).
static func shape_tilt(v: Vector2, dead: float, exponent: float) -> Vector2:
	var amount := v.length()
	if amount <= dead:
		return Vector2.ZERO
	var t := minf((amount - dead) / (1.0 - dead), 1.0)
	return v / amount * pow(t, exponent)


## Recién reaparecida: los enemigos no la persiguen todavía.
func is_protected() -> bool:
	return _protection > 0.0


func is_grounded() -> bool:
	return _grounded


func _physics_process(delta: float) -> void:
	_protection = maxf(_protection - delta, 0.0)
	_update_sensor(delta)
	_grounded = _check_grounded()
	_detect_impact(delta)
	if _grounded and _ground_velocity != Vector3.ZERO:
		# Una bola sobre una plataforma que acelera rueda hacia atrás y se cae;
		# en los juegos se "pega" a la plataforma igualando su velocidad.
		var relative := _ground_velocity - linear_velocity
		relative.y = 0.0
		apply_central_force(relative * mass * _ground_grip)
	if _grounded and _ground_push != Vector3.ZERO:
		apply_central_force(_ground_push * mass)
	var target := _read_input() if controls_enabled else Vector2.ZERO
	_input = _input.lerp(target, 1.0 - exp(-input_smoothing * delta))
	if _input.length() < 0.01 or camera == null:
		return

	# Las direcciones son relativas a la cámara: inclinar "hacia delante" mueve la canica hacia arriba en pantalla.
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var dir := right * _input.x + forward * _input.y

	var flat_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat_velocity.dot(dir.normalized()) < max_speed:
		apply_central_force(dir * roll_force * _control_factor())


func _detect_impact(delta: float) -> void:
	_impact_cooldown = maxf(_impact_cooldown - delta, 0.0)
	var velocity := linear_velocity
	var change := velocity - _last_velocity - get_gravity() * delta
	_last_velocity = velocity
	if freeze or not visible or _pending_respawn != null:
		_impact_mute = 2
		return
	if _impact_mute > 0:
		_impact_mute -= 1
		return
	var strength := change.length()
	if strength >= IMPACT_THRESHOLD and _impact_cooldown == 0.0:
		_impact_cooldown = 0.08
		impact.emit(strength, change.y > 0.0 and change.y > Vector2(change.x, change.z).length())


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_respawn != null:
		state.transform = Transform3D(Basis.IDENTITY, _pending_respawn)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_pending_respawn = null


## Lee el sensor y lo filtra. get_gravity() ya viene filtrado; si el móvil no lo tiene se usa
## el acelerómetro, que también recoge el temblor de la mano, y se filtra bastante más.
func _update_sensor(delta: float) -> void:
	var raw := Input.get_gravity()
	var rate := gravity_filter
	_sensor_source = "gravedad"
	if raw == Vector3.ZERO:
		raw = Input.get_accelerometer()
		rate = accelerometer_filter
		_sensor_source = "acelerómetro"
	if raw == Vector3.ZERO and tilt_simulator != null:
		raw = tilt_simulator.gravity
		rate = gravity_filter
		_sensor_source = "ratón"
	if _sensor == Vector3.ZERO:
		_sensor = raw
	else:
		_sensor = _sensor.lerp(raw, 1.0 - exp(-rate * delta))


func _read_sensor() -> Vector3:
	if _sensor == Vector3.ZERO:
		_update_sensor(0.0)
	return _sensor


func _read_input() -> Vector2:
	# Stick del mando: analógico, con la misma curva que el sensor.
	for device in Input.get_connected_joypads():
		var stick := _stick(device)
		if stick != Vector2.ZERO:
			return stick
	# Teclado para probar en el PC: control directo, sin curva.
	var keys := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	if keys == Vector2.ZERO:
		keys = _wasd()
	if keys != Vector2.ZERO:
		return keys

	var sensor := _read_sensor()
	if sensor == Vector3.ZERO:
		return Vector2.ZERO
	var delta := sensor - _neutral
	var v := _to_screen_axes(Vector2(delta.x, delta.y)) / (9.81 * sin(deg_to_rad(max_tilt_degrees)))
	if invert_x:
		v.x = -v.x
	if invert_y:
		v.y = -v.y
	return shape_tilt(v, dead_zone, response_exponent)


## Stick izquierdo de un mando. Las acciones ui_* también lo leen, pero con zona muerta 0.5:
## media palanca no hacía nada y luego empujaba de golpe.
func _stick(device: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), -Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	return shape_tilt(v.limit_length(1.0), STICK_DEAD_ZONE, response_exponent)


## WASD como alternativa a las flechas. Por posición física de la tecla, así en un teclado
## AZERTY son ZQSD sin tocar nada.
func _wasd() -> Vector2:
	var x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var y := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	return Vector2(x, y).normalized()


## En Android, Godot ya entrega el sensor con los ejes girados según la orientación de la
## pantalla. En iOS los entrega con los ejes del móvil en vertical, así que en horizontal
## hay que girarlos 90° (en un sentido u otro según hacia qué lado esté girado el móvil).
func _to_screen_axes(v: Vector2) -> Vector2:
	if OS.get_name() != "iOS":
		return v
	if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_REVERSE_LANDSCAPE:
		return Vector2(-v.y, v.x)
	return Vector2(v.y, -v.x)


func _control_factor() -> float:
	if not _grounded:
		return air_control
	return ice_control if _on_ice else 1.0


func _check_grounded() -> bool:
	if _ground_query.exclude.is_empty():
		_ground_query.exclude = [get_rid()]
	_ground_query.from = global_position
	_ground_query.to = global_position + Vector3.DOWN * 0.7
	var hit := get_world_3d().direct_space_state.intersect_ray(_ground_query)
	var ground: Object = hit.get("collider")
	_on_ice = ground != null and ground.get_meta("surface", "") == "ice"
	_ground_velocity = ground.get_meta("velocity", Vector3.ZERO) if ground != null else Vector3.ZERO
	# Piezas que giran: la velocidad del suelo depende de dónde esté la canica.
	if ground != null and ground.has_meta("velocity_at"):
		_ground_velocity = (ground.get_meta("velocity_at") as Callable).call(global_position)
	_ground_push = ground.get_meta("push", Vector3.ZERO) if ground != null else Vector3.ZERO
	_ground_grip = ground.get_meta("grip", platform_grip) if ground != null else platform_grip
	return not hit.is_empty()

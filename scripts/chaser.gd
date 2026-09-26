class_name Chaser
extends RigidBody3D
## Canica de acero enemiga: persigue a la canica de jugador más cercana para tirarla de la pista.
## Si se cae, vuelve a su posición inicial.
##
## En carrera la simula solo el anfitrión; en los demás móviles es una "marioneta" que
## se mueve donde dice la red (set_puppet + push_state).

## Grupo de nodos a los que persigue: tu canica y las de los demás jugadores.
const TARGET_GROUP := "chase_targets"
const RADIUS := 0.5

var home := Vector3.ZERO
var chase_range := 6.0
var force := 12.0
## Velocidad actual: la física en el anfitrión, la recibida por red en las marionetas.
var velocity := Vector3.ZERO

var _pending_reset := false
var _puppet := false
var _net_pos := Vector3.ZERO
var _net_rot := Quaternion.IDENTITY
var _net_age := 0.0
var _has_net_state := false


func _ready() -> void:
	mass = 1.6
	can_sleep = false
	continuous_cd = true
	linear_damp = 0.2
	angular_damp = 0.3
	var physics := PhysicsMaterial.new()
	physics.friction = 0.8
	physics.bounce = 0.3
	physics_material_override = physics

	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.16, 0.2)
	steel.metallic = 0.9
	steel.roughness = 0.2
	var ball := SphereMesh.new()
	ball.radius = RADIUS
	ball.height = RADIUS * 2.0
	ball.material = steel
	var ball_instance := MeshInstance3D.new()
	ball_instance.mesh = ball
	add_child(ball_instance)

	# Franja roja luminosa: al rodar deja ver que gira y la distingue de un obstáculo fijo.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.15, 0.1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.15, 0.1)
	glow.emission_energy_multiplier = 2.5
	var stripe := TorusMesh.new()
	stripe.inner_radius = 0.46
	stripe.outer_radius = 0.54
	stripe.material = glow
	var stripe_instance := MeshInstance3D.new()
	stripe_instance.mesh = stripe
	add_child(stripe_instance)


## Deja de simularse aquí: la posición llegará por red. Sin colisiones físicas
## (los choques con tu canica se calculan como entre canicas de jugadores).
func set_puppet() -> void:
	_puppet = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0


func push_state(pos: Vector3, vel: Vector3, rot: Quaternion) -> void:
	_net_pos = pos
	velocity = vel
	_net_rot = rot
	_net_age = 0.0
	if not _has_net_state:
		_has_net_state = true
		global_position = pos


func _process(delta: float) -> void:
	if not _puppet or not _has_net_state:
		return
	_net_age += delta
	var predicted := _net_pos + velocity * minf(_net_age, RemoteMarble.MAX_PREDICTION)
	var k := 1.0 - exp(-RemoteMarble.SMOOTHING * delta)
	global_position = global_position.lerp(predicted, k)
	quaternion = quaternion.slerp(_net_rot, k)


func _physics_process(_delta: float) -> void:
	if _puppet:
		return
	velocity = linear_velocity
	if global_position.y < home.y - 12.0:
		_pending_reset = true
		return
	var target := _nearest_target()
	if target != Vector3.INF:
		apply_central_force(target.normalized() * force)


## Vector horizontal hacia la canica de jugador más cercana a su alcance, o INF si no hay ninguna.
func _nearest_target() -> Vector3:
	var best := Vector3.INF
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node is Marble and node.freeze:
			continue  # Aún en la salida, celebrando o fin de partida
		if node is RemoteMarble and not node.visible:
			continue
		var to_target: Vector3 = node.global_position - global_position
		if absf(to_target.y) > 1.5:
			continue
		to_target.y = 0.0
		if to_target.length() < chase_range and to_target.length() < best.length():
			best = to_target
	return best


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_reset:
		state.transform = Transform3D(Basis.IDENTITY, home)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_pending_reset = false

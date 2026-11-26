class_name Worm
extends Node3D
## Gusano que vive en un agujero de una plataforma: asoma cuando entra una canica en su zona,
## la persigue sin salir de ella y se la come si la alcanza. Luego vuelve a esconderse un rato.
##
## No tiene física: solo la cabeza es peligrosa. En carrera cada móvil lo mueve por su cuenta
## (persigue a la canica más cercana, sea la tuya o la de otro), así que puede no coincidir exacto.

## Ha alcanzado a `target` (la canica local o la de otro jugador) y se la lleva a su agujero.
signal ate(target: Node3D)
## Ya se ha metido en el agujero con `target`: ahora puede reaparecer.
signal swallowed(target: Node3D)

const SEGMENTS := 9
const HEAD_RADIUS := 0.55
const SPACING := 0.42
const C_SKIN := Color(0.45, 0.85, 0.25)
const C_STRIPE := Color(0.95, 0.8, 0.25)

## Centro del agujero, a ras de suelo.
var hole := Vector3.ZERO
## Zona (plano xz) en la que caza y de la que no sale: normalmente su plataforma.
var roam := Rect2()
var speed := 3.2
## Segundos que se queda escondido después de comer.
var rest_time := 3.0
## Canica que se ha comido y lleva dentro hasta meterse en el agujero.
var _carrying: Node3D = null

var _emerge := 0.0
var _rest := 0.0
var _time := 0.0
var _points: Array[Vector3] = []
var _parts: Array[MeshInstance3D] = []
var _mouth: MeshInstance3D
var _face := Vector3.BACK

## Materiales y mallas compartidos por todos los gusanos (hasta 3 por nivel, con 9 segmentos y
## cara cada uno): menos recursos en la GPU que crear unos nuevos para cada pieza.
static var _materials := {}
static var _segment_meshes: Array[SphereMesh] = []
static var _meshes := {}


func _ready() -> void:
	_build_hole()
	for i in SEGMENTS:
		var part := MeshInstance3D.new()
		part.mesh = _segment_mesh(i)
		add_child(part)
		_parts.append(part)
		_points.append(hole)
	_build_face(_parts[0])
	_place_parts()


func _segment_mesh(i: int) -> SphereMesh:
	if _segment_meshes.is_empty():
		for k in SEGMENTS:
			var sphere := SphereMesh.new()
			sphere.radius = _radius(k)
			sphere.height = sphere.radius * 2.0
			sphere.material = _material(C_SKIN if k % 2 == 0 else C_SKIN.lerp(C_STRIPE, 0.5))
			_segment_meshes.append(sphere)
	return _segment_meshes[i]


static func _radius(i: int) -> float:
	return lerpf(HEAD_RADIUS, 0.22, float(i) / (SEGMENTS - 1))


func _physics_process(delta: float) -> void:
	_time += delta
	_rest = maxf(_rest - delta, 0.0)
	var target := _find_target() if _rest == 0.0 and _carrying == null else null
	var head := _points[0]

	if target != null:
		_emerge = move_toward(_emerge, 1.0, delta * 1.5)
		if _emerge > 0.6:
			var to := to_local(target.global_position) - head
			to.y = 0.0
			if to.length() > 0.05:
				_face = to.normalized()
				head += _face * minf(speed * delta, to.length())
		head = _clamp_to_roam(head)
		var reach := HEAD_RADIUS + 0.5 + 0.05
		var target_pos := to_local(target.global_position)
		if _emerge > 0.8 and Vector2(target_pos.x - head.x, target_pos.z - head.z).length() < reach:
			_carrying = target
			ate.emit(target)
	else:
		var home := hole - head
		home.y = 0.0
		if home.length() > 0.05:
			_face = home.normalized()
			head += _face * minf(speed * 1.3 * delta, home.length())
		else:
			_emerge = move_toward(_emerge, 0.0, delta * 1.5)
			if _emerge == 0.0 and _carrying != null:
				# Ya dentro del agujero: suelta la canica y descansa un rato.
				var eaten := _carrying
				_carrying = null
				_rest = rest_time
				swallowed.emit(eaten)

	# El cuerpo sigue a la cabeza como una cadena.
	_points[0] = head
	for i in range(1, SEGMENTS):
		var link := _points[i] - _points[i - 1]
		if link.length() > SPACING:
			_points[i] = _points[i - 1] + link.normalized() * SPACING
	_place_parts()


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Chaser.TARGET_GROUP):
		var target := node as Node3D
		if target == null or not target.visible or (target is Marble and target.is_protected()):
			continue
		var pos := to_local(target.global_position)
		# Solo caza canicas que están sobre su plataforma (ni cayendo ni por encima).
		if not roam.grow(0.5).has_point(Vector2(pos.x, pos.z)) or absf(pos.y - hole.y - 0.5) > 1.0:
			continue
		var distance := pos.distance_to(_points[0])
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


func _clamp_to_roam(p: Vector3) -> Vector3:
	var margin := HEAD_RADIUS
	p.x = clampf(p.x, roam.position.x + margin, roam.end.x - margin)
	p.z = clampf(p.z, roam.position.y + margin, roam.end.y - margin)
	return p


func _place_parts() -> void:
	for i in SEGMENTS:
		var radius := _radius(i)
		# Asoma poco a poco: la cola sale la última.
		var out := clampf(_emerge * 1.6 - float(i) / SEGMENTS * 0.6, 0.0, 1.0)
		var bob := 0.1 * sin(_time * 9.0 - i * 0.9) * out
		_parts[i].position = _points[i] + Vector3(0, radius + bob - (1.0 - out) * (radius * 2.0 + 0.2), 0)
		_parts[i].visible = out > 0.0
	var head := _parts[0]
	# Con la canica dentro, la cabeza va hinchada.
	head.basis = Basis.looking_at(_face).scaled(Vector3.ONE * (1.3 if _carrying != null else 1.0))
	# La boca se abre y se cierra mientras caza.
	var chomp := 0.25 + 0.75 * absf(sin(_time * 8.0)) if _emerge > 0.6 else 0.2
	_mouth.scale = Vector3(1.0, chomp, 1.0)


func _build_hole() -> void:
	_piece(self, _cylinder(0.8, 0.8, 0.02, Color(0.03, 0.02, 0.05)), hole + Vector3(0, 0.012, 0))
	var rim: TorusMesh = _meshes.get("rim")
	if rim == null:
		rim = TorusMesh.new()
		rim.inner_radius = 0.78
		rim.outer_radius = 0.98
		rim.material = _material(Color(0.4, 0.28, 0.2))
		_meshes["rim"] = rim
	_piece(self, rim, hole + Vector3(0, 0.03, 0))


## Boca, ojos y antenas en la cabeza (el -z local es hacia donde mira).
func _build_face(head: MeshInstance3D) -> void:
	_mouth = _piece(head, _sphere(0.32, Color(0.5, 0.02, 0.1)), Vector3(0, -0.08, -HEAD_RADIUS * 0.72))
	for side in [-1.0, 1.0]:
		var eye := _piece(head, _sphere(0.16, Color.WHITE, 0.3), Vector3(side * 0.22, 0.32, -0.35))
		_piece(eye, _sphere(0.08, Color(0.05, 0.02, 0.08)), Vector3(0, 0, -0.11))
		var antenna := _piece(head, _cylinder(0.02, 0.04, 0.45, C_SKIN.darkened(0.3)),
			Vector3(side * 0.18, HEAD_RADIUS + 0.12, 0.05))
		antenna.rotation = Vector3(0.3, 0, side * -0.4)
		_piece(antenna, _sphere(0.07, C_STRIPE, 1.5), Vector3(0, 0.25, 0))


func _piece(parent: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
	return instance


## Mallas compartidas entre gusanos, por forma y color.
static func _sphere(radius: float, color: Color, emission := 0.0) -> SphereMesh:
	var key := "sphere|%s|%s|%s" % [radius, color, emission]
	if not _meshes.has(key):
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.material = _material(color, emission)
		_meshes[key] = sphere
	return _meshes[key]


static func _cylinder(top: float, bottom: float, height: float, color: Color) -> CylinderMesh:
	var key := "cylinder|%s|%s|%s|%s" % [top, bottom, height, color]
	if not _meshes.has(key):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = top
		cylinder.bottom_radius = bottom
		cylinder.height = height
		cylinder.material = _material(color)
		_meshes[key] = cylinder
	return _meshes[key]


static func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [color, emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	_materials[key] = material
	material.albedo_color = color
	material.roughness = 0.5
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

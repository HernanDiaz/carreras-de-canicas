class_name Level
extends Node3D
## Base de todos los niveles: piezas de pista, trampas y enemigos.
## Cada nivel es un script en res://levels/ que hereda de Level y rellena build().

signal checkpoint_reached(position: Vector3)
## La canica ha tocado algo mortal (ácido...). `reason` es la clave de traducción del aviso.
signal marble_killed(reason: String)
## Tu canica está atrapada (se la ha comido un gusano): queda fuera de juego hasta que
## llegue marble_killed y reaparezca.
signal marble_caught(reason: String)
## Tu canica ha pisado la baldosa `index` (en carrera se reenvía a los demás jugadores).
signal crumble_triggered(index: int)

const TRACK_SHADER := preload("res://shaders/track.gdshader")

## Estilos de pieza: patrón superior (0 damero, 1 flechas, 2 peligro), colores y borde.
const S_START := {pattern = 0, a = Color(0.3, 0.8, 0.7), b = Color(0.2, 0.62, 0.58), side = Color(0.12, 0.36, 0.4), edge = Color(0.6, 1.0, 0.95)}
const S_FLOOR := {pattern = 0, a = Color(0.8, 0.78, 0.94), b = Color(0.6, 0.56, 0.82), side = Color(0.3, 0.25, 0.52), edge = Color(0.85, 0.85, 1.0)}
const S_BRIDGE := {pattern = 0, a = Color(0.95, 0.9, 0.75), b = Color(0.78, 0.7, 0.55), side = Color(0.42, 0.3, 0.3), edge = Color(1.0, 0.85, 0.6)}
const S_RAMP := {pattern = 1, a = Color(0.98, 0.72, 0.3), b = Color(0.88, 0.5, 0.2), side = Color(0.5, 0.28, 0.2), edge = Color(1.0, 0.85, 0.5)}
const S_WALL := {pattern = 0, a = Color(0.45, 0.4, 0.7), b = Color(0.45, 0.4, 0.7), side = Color(0.3, 0.25, 0.52), edge = Color(0.7, 0.7, 1.0)}
const S_HAZARD := {pattern = 2, a = Color(0.95, 0.25, 0.25), b = Color(0.15, 0.1, 0.15), side = Color(0.5, 0.1, 0.1), edge = Color(1.0, 0.5, 0.4)}
const S_GOAL := {pattern = 0, a = Color(0.95, 0.95, 0.95), b = Color(0.08, 0.08, 0.1), side = Color(0.2, 0.2, 0.2), edge = Color(0.3, 1.0, 0.5)}
const S_ICE := {pattern = 0, a = Color(0.88, 0.97, 1.0), b = Color(0.68, 0.87, 0.98), side = Color(0.35, 0.55, 0.78), edge = Color(0.8, 1.0, 1.0)}
const S_ICE_RAMP := {pattern = 1, a = Color(0.88, 0.97, 1.0), b = Color(0.6, 0.82, 0.96), side = Color(0.35, 0.55, 0.78), edge = Color(0.8, 1.0, 1.0)}
const S_MOVER := {pattern = 0, a = Color(0.6, 0.92, 0.62), b = Color(0.42, 0.76, 0.5), side = Color(0.2, 0.4, 0.3), edge = Color(0.6, 1.0, 0.7)}
const S_CRUMBLE := {pattern = 0, a = Color(0.78, 0.62, 0.5), b = Color(0.64, 0.5, 0.4), side = Color(0.4, 0.28, 0.22), edge = Color(1.0, 0.7, 0.5), tile_size = 0.6}
const S_TRAPDOOR := {pattern = 2, a = Color(0.98, 0.82, 0.25), b = Color(0.2, 0.17, 0.14), side = Color(0.45, 0.35, 0.15), edge = Color(1.0, 0.9, 0.4)}
const S_METAL := {pattern = 0, a = Color(0.6, 0.62, 0.7), b = Color(0.52, 0.54, 0.62), side = Color(0.3, 0.32, 0.4), edge = Color(0.85, 0.9, 1.0)}
const S_CONVEYOR := {pattern = 1, a = Color(0.32, 0.34, 0.4), b = Color(0.98, 0.62, 0.15), side = Color(0.2, 0.2, 0.26), edge = Color(1.0, 0.75, 0.3), tile_size = 0.8}
const S_CRUSHER := {pattern = 2, a = Color(0.95, 0.75, 0.15), b = Color(0.16, 0.14, 0.16), side = Color(0.4, 0.3, 0.1), edge = Color(1.0, 0.85, 0.35), pattern_on_sides = true}
const S_TURNTABLE := {pattern = 0, a = Color(0.55, 0.85, 0.95), b = Color(0.35, 0.6, 0.8), side = Color(0.18, 0.3, 0.45), edge = Color(0.6, 0.95, 1.0), tile_size = 1.2}
const S_HILL := {pattern = 0, a = Color(0.62, 0.88, 0.66), b = Color(0.45, 0.74, 0.55), side = Color(0.22, 0.4, 0.32), edge = Color(0.7, 1.0, 0.75), tile_size = 1.2}
const S_CHUTE := {pattern = 0, a = Color(0.98, 0.78, 0.4), b = Color(0.95, 0.55, 0.35), side = Color(0.5, 0.3, 0.2), edge = Color(1.0, 0.85, 0.5), tile_size = 1.0}
const C_CHUTE_WALL := Color(0.5, 0.85, 1.0, 0.35)
const S_SEESAW := {pattern = 0, a = Color(0.95, 0.85, 0.55), b = Color(0.85, 0.65, 0.4), side = Color(0.45, 0.3, 0.2), edge = Color(1.0, 0.9, 0.6), tile_size = 0.75}
const S_TOWER := {pattern = 0, a = Color(0.42, 0.38, 0.62), b = Color(0.36, 0.32, 0.55), side = Color(0.3, 0.26, 0.5), edge = Color(0.62, 0.6, 0.95), tile_size = 1.5}
const C_BARREL := Color(0.72, 0.42, 0.2)
const S_BOOST := {pattern = 1, a = Color(0.35, 1.0, 1.0), b = Color(0.1, 0.35, 0.55), side = Color(0.1, 0.3, 0.4), edge = Color(0.4, 1.0, 1.0), tile_size = 0.45}

const C_BUMPER := Color(1.0, 0.35, 0.75)
const C_GOAL_LIGHT := Color(0.3, 1.0, 0.5)
const C_ACID := Color(0.45, 1.0, 0.2)
const C_JUMP := Color(1.0, 0.85, 0.2)
const C_ENEMY := Color(0.6, 0.25, 0.85)

## La asigna game.gd antes de build(); la usan los enemigos que persiguen.
var marble: Marble
var spawn_point := Vector3(0.0, 1.0, 0.0)
var lowest_y := 0.0
## true mientras la canica está sobre el damero de la meta.
var marble_on_goal := false
## Centro del damero de la meta (a ras de suelo).
var goal_center := Vector3.ZERO

## Canicas de acero del nivel, en orden de creación (el mismo en todos los móviles).
var chasers: Array[Chaser] = []

var _time := 0.0
## Funciones que inician la caída de cada baldosa, en orden de creación.
var _crumbles: Array[Callable] = []
## Funciones que mueven piezas cada paso de física; reciben el tiempo transcurrido.
var _animators: Array[Callable] = []
var _goal_light: OmniLight3D
var _goal_particles: CPUParticles3D


## Cada nivel la sobrescribe para colocar sus piezas.
func build() -> void:
	pass


func _physics_process(delta: float) -> void:
	_time += delta
	for animate in _animators:
		animate.call(_time)


# --- Pista ----------------------------------------------------------------

## Bloque sólido. `top` es el centro de su cara superior.
func add_block(top: Vector3, size: Vector3, style: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = top - Vector3(0, size.y / 2.0, 0)
	_add_box(body, size, style)
	add_child(body)
	lowest_y = minf(lowest_y, top.y)
	return body


## Bloque con punto de control: si te caes, reapareces en la última plataforma pisada, en su
## centro o desplazado `spawn_offset` (por ejemplo si en el centro hay una pared).
func add_platform(top: Vector3, size: Vector3, style: Dictionary = S_FLOOR, spawn_offset := Vector3.ZERO) -> StaticBody3D:
	var body := add_block(top, size, style)
	var area := _add_area(top + Vector3(0, 1, 0), Vector3(size.x, 2, size.z))
	area.body_entered.connect(func(body_in: Node3D) -> void:
		if body_in is Marble:
			checkpoint_reached.emit(top + spawn_offset + Vector3.UP)
	)
	return body


## Plataforma de salida con bordes por detrás y a los lados. Se sale por -z.
func add_start(top := Vector3.ZERO) -> void:
	add_platform(top, Vector3(6, 2, 6), S_START)
	add_block(top + Vector3(0, 0.8, 3.25), Vector3(6.5, 0.8, 0.5), S_WALL)
	add_block(top + Vector3(-3.25, 0.8, 0), Vector3(0.5, 0.8, 6), S_WALL)
	add_block(top + Vector3(3.25, 0.8, 0), Vector3(0.5, 0.8, 6), S_WALL)
	spawn_point = top + Vector3.UP


## Rampa cuya superficie va de `from` a `to` (ambos a nivel del suelo).
func add_ramp(from: Vector3, to: Vector3, width: float, style: Dictionary = S_RAMP, thickness := 1.0) -> StaticBody3D:
	var forward := (to - from).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var body := StaticBody3D.new()
	body.transform = Transform3D(Basis(right, up, -forward), (from + to) / 2.0 - up * thickness / 2.0)
	_add_box(body, Vector3(width, thickness, from.distance_to(to)), style)
	add_child(body)
	lowest_y = minf(lowest_y, minf(from.y, to.y))
	return body


## Convierte una pieza en hielo: casi sin agarre y la canica apenas responde.
func make_icy(body: StaticBody3D) -> void:
	var ice := PhysicsMaterial.new()
	ice.friction = 0.05
	body.physics_material_override = ice
	body.set_meta("surface", "ice")


func add_ice_platform(top: Vector3, size: Vector3) -> StaticBody3D:
	var body := add_platform(top, size, S_ICE)
	make_icy(body)
	return body


## Plataforma que va y viene entre dos posiciones (centros de su cara superior).
## Se para un rato en cada extremo para poder subir y bajar con calma.
func add_moving_platform(from_top: Vector3, to_top: Vector3, size: Vector3, period: float, phase := 0.0) -> void:
	var body := AnimatableBody3D.new()
	var half := Vector3(0, size.y / 2.0, 0)
	body.position = from_top - half
	_add_box(body, size, S_MOVER)
	add_child(body)
	lowest_y = minf(lowest_y, minf(from_top.y, to_top.y))
	var last := {pos = body.position, t = 0.0}
	_animators.append(func(t: float) -> void:
		# 20 % parada en el origen, 30 % ida, 20 % parada en el destino, 30 % vuelta
		var p := fposmod(t / period + phase, 1.0)
		var k := 0.0
		if p < 0.2:
			k = 0.0
		elif p < 0.5:
			k = smoothstep(0.2, 0.5, p)
		elif p < 0.7:
			k = 1.0
		else:
			k = 1.0 - smoothstep(0.7, 1.0, p)
		var pos := from_top.lerp(to_top, k) - half
		# La canica lee esta velocidad para no quedarse atrás al rodar (ver marble.gd).
		var dt: float = t - last.t
		body.set_meta("velocity", (pos - last.pos) / dt if dt > 0.0 else Vector3.ZERO)
		body.position = pos
		last.pos = pos
		last.t = t
	)


## Cinta transportadora de `from` a `to` (centros de su cara superior, a la misma altura).
## Empuja la canica en ese sentido con la aceleración `strength` (la canica acelera con 20).
func add_conveyor(from: Vector3, to: Vector3, width: float, strength: float) -> StaticBody3D:
	var dir := (to - from).normalized()
	var length := from.distance_to(to)
	var body := StaticBody3D.new()
	# looking_at deja el -z local mirando hacia `dir`: así las flechas apuntan hacia donde empuja.
	body.transform = Transform3D(Basis.looking_at(dir), (from + to) / 2.0 - Vector3(0, 0.5, 0))
	var style := S_CONVEYOR.duplicate()
	style.scroll = strength * 0.25
	_add_box(body, Vector3(width, 1.0, length), style)
	body.set_meta("push", dir * strength)
	add_child(body)
	lowest_y = minf(lowest_y, from.y)

	# Rodillos en los extremos (decorativos)
	var roller := CylinderMesh.new()
	roller.top_radius = 0.35
	roller.bottom_radius = 0.35
	roller.height = width + 0.2
	roller.material = _material(Color(0.5, 0.5, 0.58))
	for end in [-1.0, 1.0]:
		var instance := _add_mesh(body, roller, Vector3(0, 0.15, end * length / 2.0))
		instance.basis = Basis(Vector3.BACK, PI / 2.0)
	return body


## Prensa que cae desde arriba sobre la pista cada `period` segundos. Tiembla antes de caer;
## si te pilla debajo, reapareces. Mientras está abajo tapa el paso.
func add_crusher(floor_pos: Vector3, size: Vector2, period: float, phase := 0.0) -> void:
	var raised := 3.0
	var thickness := 1.2
	var box := Vector3(size.x, thickness, size.y)

	# Pórtico del que cuelga (solo decorado)
	var steel := _material(Color(0.42, 0.44, 0.52))
	steel.metallic = 0.5
	steel.roughness = 0.4
	var pillar := BoxMesh.new()
	pillar.size = Vector3(0.4, 8.0, 0.4)
	pillar.material = steel
	for side in [-1.0, 1.0]:
		_add_mesh(self, pillar, floor_pos + Vector3(side * (size.x / 2.0 + 0.45), 1.5, 0))
	var beam := BoxMesh.new()
	beam.size = Vector3(size.x + 1.3, 0.5, 0.6)
	beam.material = steel
	_add_mesh(self, beam, floor_pos + Vector3(0, 5.5, 0))

	# Marca en el suelo: franjas fijas y un brillo rojo que avisa antes de caer
	var mark := BoxMesh.new()
	mark.size = Vector3(size.x, 0.02, size.y)
	mark.material = _track_material(mark.size, S_HAZARD)
	_add_mesh(self, mark, floor_pos + Vector3(0, 0.01, 0))
	var glow_material := _material(Color(1.0, 0.2, 0.15), 3.0)
	var glow := BoxMesh.new()
	glow.size = Vector3(size.x, 0.03, size.y)
	glow.material = glow_material
	var glow_instance := _add_mesh(self, glow, floor_pos + Vector3(0, 0.025, 0))
	glow_instance.visible = false

	var body := AnimatableBody3D.new()
	var down := floor_pos + Vector3(0, thickness / 2.0 + 0.02, 0)
	body.position = down + Vector3(0, raised, 0)
	_add_box(body, box, S_CRUSHER)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.18
	rod.bottom_radius = 0.18
	rod.height = 4.0
	rod.material = steel
	_add_mesh(body, rod, Vector3(0, thickness / 2.0 + 2.0, 0))
	add_child(body)

	# Zona de aplastamiento: el hueco bajo la prensa
	var danger := _add_area(floor_pos + Vector3(0, 0.5, 0), Vector3(size.x - 0.4, 1.0, size.y - 0.4))

	_animators.append(func(t: float) -> void:
		# 50 % arriba, 12 % temblando, 6 % caída, 12 % abajo, 20 % subida
		var p := fposmod(t / period + phase, 1.0)
		var k := 1.0
		var jitter := Vector3.ZERO
		if p < 0.5:
			k = 1.0
		elif p < 0.62:
			jitter = Vector3(sin(t * 70.0), 0, cos(t * 83.0)) * 0.05
		elif p < 0.68:
			var f := (p - 0.62) / 0.06
			k = 1.0 - f * f
		elif p < 0.8:
			k = 0.0
		else:
			k = smoothstep(0.8, 1.0, p)
		body.position = down + Vector3(0, raised * k, 0) + jitter
		var warning := p >= 0.5 and p < 0.68
		glow_instance.visible = warning and fmod(t * 8.0, 1.0) < 0.5
		# Solo aplasta mientras cae o está abajo, no al subir.
		if p >= 0.62 and p < 0.8 and raised * k < 0.9 and marble != null 				and danger.overlaps_body(marble):
			marble_killed.emit("CRUSHED")
	)


## Disco giratorio (centro de su cara superior). La canica gira con él. Con `bars` > 0
## lleva barreras bajas hacia el borde que barren la superficie; el centro (hasta `bar_start`)
## queda libre.
func add_turntable(top: Vector3, radius: float, degrees_per_second: float, bars := 0, bar_start := 1.5) -> void:
	var height := 1.0
	var body := AnimatableBody3D.new()
	body.position = top - Vector3(0, height / 2.0, 0)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = height
	disc.radial_segments = 48
	disc.material = _track_material(Vector3(radius * 2.0, height, radius * 2.0), S_TURNTABLE)
	_add_mesh(body, disc)
	var rim := TorusMesh.new()
	rim.inner_radius = radius - 0.08
	rim.outer_radius = radius + 0.04
	rim.material = _material(S_TURNTABLE.edge, 2.5)
	_add_mesh(body, rim, Vector3(0, height / 2.0, 0))

	var style := S_HAZARD.duplicate()
	style.pattern_on_sides = true
	var bar_length := radius - bar_start - 0.4
	for i in bars:
		var angle := TAU * i / bars
		var out := Vector3(cos(angle), 0, sin(angle))
		var xform := Transform3D(Basis(Vector3.UP, -angle), out * (bar_start + bar_length / 2.0) + Vector3(0, height / 2.0 + 0.3, 0))
		_add_box(body, Vector3(bar_length, 0.6, 0.35), style, xform)
	add_child(body)
	lowest_y = minf(lowest_y, top.y)

	var speed := deg_to_rad(degrees_per_second)
	# Velocidad del suelo en un punto: la canica la usa para girar con el disco (ver marble.gd).
	# Con menos agarre que una plataforma móvil, para poder cruzarlo a buen ritmo.
	body.set_meta("grip", 4.0)
	body.set_meta("velocity_at", func(pos: Vector3) -> Vector3:
		var r := pos - top
		return Vector3(speed * r.z, 0, -speed * r.x)
	)
	_animators.append(func(t: float) -> void:
		body.rotation.y = speed * t
	)


## Cuesta con baches entre `from` y `to` (centros a nivel del suelo): `bumps` jorobas de
## `height` de alto. A buena velocidad, cada joroba te hace saltar.
func add_waves(from: Vector3, to: Vector3, width: float, bumps: int, height: float, style: Dictionary = S_HILL) -> void:
	var up := Vector3.UP * height
	var last := from
	for i in range(1, bumps * 2 + 1):
		var point := from.lerp(to, float(i) / (bumps * 2)) + (up if i % 2 == 1 else Vector3.ZERO)
		add_ramp(last, point, width, style, 0.8)
		last = point


## Valle en forma de V entre `from` y `to` (centros de los bordes superiores): las dos laderas
## bajan `depth` hasta el surco del centro, así que la canica tiende a rodar por el fondo.
## El fondo del valle queda `depth` por debajo de `from` y `to`.
func add_valley(from: Vector3, to: Vector3, width: float, depth: float, style: Dictionary = S_HILL) -> void:
	var forward := (to - from).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var length := from.distance_to(to)
	var bottom := (from + to) / 2.0 - up * depth
	var thickness := 0.8
	for side in [-1.0, 1.0]:
		var across: Vector3 = right * side * width / 2.0 + up * depth
		var x := across.normalized()
		var z := -forward
		var y := z.cross(x)
		if y.y < 0.0:
			x = -x
			y = z.cross(x)
		var body := StaticBody3D.new()
		body.transform = Transform3D(Basis(x, y, z), bottom + across / 2.0 - y * thickness / 2.0)
		_add_box(body, Vector3(across.length(), thickness, length), style)
		add_child(body)
	lowest_y = minf(lowest_y, minf(from.y, to.y) - depth)


## Zona de viento: caja con centro de su base en `floor_center` y tamaño `size`. Sopla hacia
## `dir` a rachas: cada `period` segundos está un rato en calma, sube, sopla y amaina.
## `strength` es la aceleración que da a la canica (la tuya acelera con 20).
func add_wind(floor_center: Vector3, size: Vector3, dir: Vector3, strength: float, period: float, phase := 0.0) -> void:
	dir = dir.normalized()
	var area := _add_area(floor_center + Vector3(0, size.y / 2.0, 0), size)

	var streak := BoxMesh.new()
	streak.size = Vector3(0.04, 0.9, 0.04)
	var air := StandardMaterial3D.new()
	air.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
	air.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	air.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.material = air
	# Las rayas nacen en el borde por donde entra el viento y mueren al llegar al otro.
	var length := absf(dir.x) * size.x + absf(dir.z) * size.z
	var across := Vector3(absf(dir.z), 0, absf(dir.x))
	var speed := 11.0
	var particles := CPUParticles3D.new()
	particles.mesh = streak
	particles.amount = clampi(int(size.x * size.z * 0.6), 10, 90)
	particles.lifetime = (length - 0.8) / speed
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = across * (size.x * across.x + size.z * across.z) / 2.0 + Vector3(0, 0.6, 0) + dir.abs() * 0.1
	particles.direction = dir
	particles.spread = 0.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = speed
	particles.initial_velocity_max = speed
	particles.particle_flag_align_y = true
	particles.position = floor_center + Vector3(0, 0.8, 0) - dir * (length / 2.0 - 0.4)
	particles.emitting = false
	add_child(particles)

	_animators.append(func(t: float) -> void:
		# 35 % calma, 10 % sube, 40 % sopla, 15 % amaina
		var p := fposmod(t / period + phase, 1.0)
		var gust := 0.0
		if p < 0.35:
			gust = 0.0
		elif p < 0.45:
			gust = (p - 0.35) / 0.1
		elif p < 0.85:
			gust = 1.0
		else:
			gust = 1.0 - (p - 0.85) / 0.15
		particles.emitting = gust > 0.2
		if gust > 0.0 and marble != null and area.overlaps_body(marble):
			marble.apply_central_force(dir * strength * gust * marble.mass)
	)


## Balancín: tablón (centro de su cara superior `top`, tamaño `size`) que se inclina hacia un
## lado y hacia el otro alrededor de `axis` (que pasa por su centro). Se queda un rato
## inclinado en cada lado.
func add_seesaw(top: Vector3, size: Vector3, axis: Vector3, degrees: float, period: float, phase := 0.0) -> void:
	axis = axis.normalized()
	var body := AnimatableBody3D.new()
	body.position = top - Vector3(0, size.y / 2.0, 0)
	_add_box(body, size, S_SEESAW)
	add_child(body)
	lowest_y = minf(lowest_y, top.y)

	# Apoyo triangular bajo el centro (decorado)
	var along_z := absf(axis.z) > 0.5
	var fulcrum := PrismMesh.new()
	fulcrum.size = Vector3(1.2, 1.4, (size.z if along_z else size.x) * 0.5)
	fulcrum.material = _material(Color(0.42, 0.44, 0.52))
	var fulcrum_instance := _add_mesh(self, fulcrum, top - Vector3(0, size.y + 0.7, 0))
	if not along_z:
		fulcrum_instance.rotation.y = PI / 2.0

	var amplitude := deg_to_rad(degrees)
	_animators.append(func(t: float) -> void:
		# 30 % inclinado a un lado, 20 % girando, 30 % al otro, 20 % volviendo
		var p := fposmod(t / period + phase, 1.0)
		var k := 1.0
		if p < 0.3:
			k = 1.0
		elif p < 0.5:
			k = 1.0 - 2.0 * smoothstep(0.3, 0.5, p)
		elif p < 0.8:
			k = -1.0
		else:
			k = -1.0 + 2.0 * smoothstep(0.8, 1.0, p)
		body.basis = Basis(axis, amplitude * k)
	)


## Torre: columna bajo una plataforma (centro superior `top`) hasta `bottom_y`. Solo decora.
func add_tower(top: Vector3, size: Vector2, bottom_y: float) -> void:
	var height := top.y - bottom_y
	var column := BoxMesh.new()
	column.size = Vector3(size.x, height, size.y)
	column.material = _track_material(column.size, S_TOWER)
	_add_mesh(self, column, top - Vector3(0, height / 2.0, 0))


## Barriles que bajan rodando por la rampa de `from` a `to` (a ras de suelo) y de ancho `width`:
## sale uno cada `period` segundos, alternando entre `lanes` carriles, y tarda `travel_time` en
## bajar; al final caen al vacío (o, con `smash`, se rompen al llegar abajo). Si te alcanzan,
## te empujan cuesta abajo.
func add_barrels(from: Vector3, to: Vector3, width: float, period: float, travel_time: float, phase := 0.0, smash := false, lanes := 1) -> void:
	var forward := (to - from).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	var radius := 0.55
	var lane_width := width / lanes
	var length := lane_width - 0.6
	var fall_time := 0.3 if smash else 1.5
	var count := int(ceil((travel_time + fall_time) / period))
	# Cada barril va siempre por el mismo carril: hace falta un número de barriles múltiplo de lanes.
	count = int(ceil(float(count) / lanes)) * lanes
	var cycle := period * count
	var speed := from.distance_to(to) / travel_time
	# El cilindro va tumbado: su eje (Y) apunta a lo ancho de la rampa.
	var lying := Basis(forward, right, forward.cross(right))

	var wood := _material(C_BARREL)
	var hoop := _material(Color(0.35, 0.35, 0.4))
	hoop.metallic = 0.6
	for i in count:
		var body := AnimatableBody3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = length
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = length
		mesh.material = wood
		var look := Node3D.new()
		body.add_child(look)
		_add_mesh(look, mesh)
		for y in [-length * 0.35, 0.0, length * 0.35]:
			var ring := TorusMesh.new()
			ring.inner_radius = radius - 0.02
			ring.outer_radius = radius + 0.06
			ring.material = hoop
			_add_mesh(look, ring, Vector3(0, y, 0))

		var area := Area3D.new()
		var area_shape := BoxShape3D.new()
		area_shape.size = Vector3(radius * 2.0 + 0.5, length, radius * 2.0 + 0.5)
		var area_collision := CollisionShape3D.new()
		area_collision.shape = area_shape
		area.add_child(area_collision)
		body.add_child(area)
		area.body_entered.connect(func(body_in: Node3D) -> void:
			var m := body_in as Marble
			if m != null:
				m.apply_central_impulse(forward * 9.0 + Vector3.UP * 2.0)
		)
		add_child(body)

		var offset := float(i) * period
		var lane := right * ((i % lanes) + 0.5 - lanes / 2.0) * lane_width
		_animators.append(func(t: float) -> void:
			var u := fposmod(t + phase * period - offset, cycle)
			var pos: Vector3
			var travelled: float
			var size := 1.0
			if u < travel_time:
				travelled = speed * u
				pos = from + forward * travelled + up * radius
			elif smash and u < travel_time + fall_time:
				travelled = speed * travel_time
				pos = to + up * radius
				size = 1.0 - (u - travel_time) / fall_time
			elif u < travel_time + fall_time:
				var air := u - travel_time
				travelled = speed * u
				pos = to + forward * speed * air + up * radius + Vector3.DOWN * 4.9 * air * air
			else:
				travelled = 0.0
				pos = from + up * radius
			var active := u < travel_time + fall_time and size > 0.05
			body.visible = active
			collision.disabled = not active or size < 1.0
			area.monitoring = active and size == 1.0
			look.scale = Vector3.ONE * size
			body.transform = Transform3D(Basis(right, -travelled / radius) * lying, pos + lane)
		)


## Tobogán: canal con paredes que sigue la línea `points` (centro del suelo).
func add_chute(points: PackedVector3Array, width: float, wall_height := 1.0) -> void:
	var lefts: Array[Vector3] = []
	var rights: Array[Vector3] = []
	for i in points.size():
		var tangent := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		tangent.y = 0.0
		var side := tangent.normalized().cross(Vector3.UP).normalized()
		lefts.append(points[i] - side * width / 2.0)
		rights.append(points[i] + side * width / 2.0)

	var floor_tool := SurfaceTool.new()
	floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_tool := SurfaceTool.new()
	wall_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var up := Vector3.UP * wall_height
	for i in points.size() - 1:
		var l0 := lefts[i]
		var l1 := lefts[i + 1]
		var r0 := rights[i]
		var r1 := rights[i + 1]
		# Suelo: en Godot las caras visibles van en sentido horario vistas desde fuera.
		var n := (r0 - l0).cross(l1 - l0).normalized()
		if n.y < 0.0:
			n = -n
		_add_quad(floor_tool, faces, [l0, l1, r1, r0], n)
		_add_quad(wall_tool, faces, [l0, l0 + up, l1 + up, l1], (r0 - l0).normalized())
		_add_quad(wall_tool, faces, [r0, r1, r1 + up, r0 + up], (l0 - r0).normalized())

	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	floor_tool.set_material(_track_material(Vector3.ONE * 1000.0, S_CHUTE))
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_tool.commit()
	body.add_child(floor_instance)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = C_CHUTE_WALL
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.emission_enabled = true
	glass.emission = Color(C_CHUTE_WALL, 1.0)
	glass.emission_energy_multiplier = 0.4
	glass.roughness = 0.2
	wall_tool.set_material(glass)
	var wall_instance := MeshInstance3D.new()
	wall_instance.mesh = wall_tool.commit()
	wall_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(wall_instance)
	add_child(body)
	for point in points:
		lowest_y = minf(lowest_y, point.y)


## Tobogán en espiral que empieza en `entry` (borde de una plataforma, a ras de suelo)
## saliendo hacia `dir`. Recorre `lead` en recto, da `turns` vueltas de radio `radius` girando
## a la derecha (o a la izquierda) mientras baja `drop`, y sale en recto `lead` otra vez.
## Devuelve {position, direction}: dónde acaba (a ras de suelo) y hacia dónde sale.
func add_spiral(entry: Vector3, dir: Vector3, radius: float, turns: float, drop: float, turn_right := true, lead := 3.0, width := 2.6) -> Dictionary:
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP).normalized() * (1.0 if turn_right else -1.0)
	var start := entry + dir * lead
	var axis := start + side * radius
	var total := turns * TAU
	var steps := maxi(int(turns * 40.0), 8)
	var points := PackedVector3Array([entry])
	for i in steps + 1:
		var angle := total * i / steps
		var offset := (-side * cos(angle) + dir * sin(angle)) * radius
		points.append(axis + offset + Vector3.DOWN * drop * i / steps)
	var out_dir := (side * sin(total) + dir * cos(total)).normalized()
	var finish := points[points.size() - 1] + out_dir * lead
	points.append(finish)
	add_chute(points, width)
	return {position = finish, direction = out_dir}


## Dos triángulos con la misma normal; también los añade a `faces` (colisión).
func _add_quad(tool: SurfaceTool, faces: PackedVector3Array, corners: Array, normal: Vector3) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(normal)
		tool.add_vertex(corners[index])
		faces.append(corners[index])


## Gusano que vive en un agujero (`hole`, a ras de suelo) y caza en la plataforma cuyo
## centro superior es `area_top` y su tamaño `area_size` (x, z).
func add_worm(hole: Vector3, area_top: Vector3, area_size: Vector2, speed := 3.2) -> void:
	var worm := Worm.new()
	worm.hole = hole
	worm.roam = Rect2(area_top.x - area_size.x / 2.0, area_top.z - area_size.y / 2.0, area_size.x, area_size.y)
	worm.speed = speed
	worm.ate.connect(func(target: Node3D) -> void:
		if target == marble:
			marble.swallow()
			marble_caught.emit("EATEN")
	)
	worm.swallowed.connect(func(target: Node3D) -> void:
		if target == marble:
			marble_killed.emit("EATEN")
	)
	add_child(worm)


## Baldosa que tiembla al pisarla, se cae y reaparece al rato.
func add_crumble(top: Vector3, size: Vector3, delay := 0.6, respawn_time := 3.0) -> void:
	var body := AnimatableBody3D.new()
	var rest := top - Vector3(0, size.y / 2.0, 0)
	body.position = rest
	var parts := _add_box(body, size, S_CRUMBLE)
	add_child(body)
	lowest_y = minf(lowest_y, top.y)

	var collision: CollisionShape3D = parts.collision
	var state := {busy = false}
	var start := func() -> void:
		if state.busy:
			return
		state.busy = true
		var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		var shakes := int(delay / 0.075)
		for i in shakes:
			var jitter := Vector3(randf_range(-0.06, 0.06), 0, randf_range(-0.06, 0.06))
			tween.tween_property(body, "position", rest + jitter, 0.075)
		tween.tween_property(body, "position", rest + Vector3.DOWN * 18.0, 1.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			body.visible = false
			collision.disabled = true
		)
		tween.tween_interval(respawn_time)
		tween.tween_callback(func() -> void:
			body.position = rest
			body.visible = true
			collision.disabled = false
			state.busy = false
		)

	var index := _crumbles.size()
	_crumbles.append(start)
	var trigger := _add_area(top + Vector3(0, 0.6, 0), Vector3(size.x, 1.2, size.z))
	trigger.body_entered.connect(func(body_in: Node3D) -> void:
		if body_in is Marble and not state.busy:
			crumble_triggered.emit(index)
			start.call()
	)


## Hace caer la baldosa `index` (cuando otro jugador la ha pisado).
func trigger_crumble(index: int) -> void:
	if index >= 0 and index < _crumbles.size():
		_crumbles[index].call()


## Trampilla que se abre cada `period` segundos durante `open_time`. Parpadea antes de abrirse.
func add_trapdoor(top: Vector3, size: Vector3, period: float, open_time: float, phase := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = top - Vector3(0, size.y / 2.0, 0)
	var parts := _add_box(body, size, S_TRAPDOOR)
	add_child(body)
	lowest_y = minf(lowest_y, top.y)

	var collision: CollisionShape3D = parts.collision
	var mesh: MeshInstance3D = parts.mesh
	var open_from := 1.0 - open_time / period
	var warn_from := open_from - 0.8 / period
	_animators.append(func(t: float) -> void:
		var p := fposmod(t / period + phase, 1.0)
		var is_open := p >= open_from
		collision.disabled = is_open
		var blinking := p >= warn_from and fmod(t * 8.0, 1.0) < 0.5
		mesh.visible = not is_open and not blinking
	)


# --- Elementos ------------------------------------------------------------

## Cilindro que rebota la canica.
func add_bumper(floor_pos: Vector3, radius := 0.6, height := 1.2) -> void:
	var body := StaticBody3D.new()
	body.position = floor_pos + Vector3(0, height / 2.0, 0)
	var bouncy := PhysicsMaterial.new()
	bouncy.bounce = 1.0
	body.physics_material_override = bouncy

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.1
	mesh.height = height
	var metal := _material(C_BUMPER)
	metal.metallic = 0.7
	metal.roughness = 0.25
	mesh.material = metal
	_add_mesh(body, mesh)

	# Anillos luminosos arriba y abajo
	for y in [height / 2.0, -height / 2.0 + 0.1]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.85
		ring.outer_radius = radius * 1.12
		ring.material = _material(C_BUMPER, 3.0)
		_add_mesh(body, ring, Vector3(0, y, 0))
	add_child(body)


## Barra (o cruz, con arms = 2) que gira sobre una plataforma y empuja la canica.
func add_spinner(floor_pos: Vector3, length: float, degrees_per_second: float, arms := 1) -> void:
	var body := AnimatableBody3D.new()
	body.position = floor_pos + Vector3(0, 0.35, 0)
	var style := S_HAZARD.duplicate()
	style.pattern_on_sides = true
	for i in arms:
		var xform := Transform3D(Basis(Vector3.UP, PI * i / arms), Vector3.ZERO)
		_add_box(body, Vector3(length, 0.6, 0.4), style, xform)
	add_child(body)
	var speed := deg_to_rad(degrees_per_second)
	_animators.append(func(t: float) -> void:
		body.rotation.y = speed * t
	)

	# Eje central (decorativo, no gira)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.35
	hub.bottom_radius = 0.45
	hub.height = 0.9
	var hub_material := _material(Color(0.75, 0.75, 0.82))
	hub_material.metallic = 0.3
	hub_material.roughness = 0.35
	hub.material = hub_material
	var hub_instance := MeshInstance3D.new()
	hub_instance.mesh = hub
	hub_instance.position = floor_pos + Vector3(0, 0.45, 0)
	add_child(hub_instance)


## Almohadilla que acelera la canica en la dirección `dir`.
func add_boost(floor_pos: Vector3, dir: Vector3, strength := 6.0, size := Vector2(2.2, 2.2)) -> void:
	dir = dir.normalized()
	var pad := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.05, size.y)
	mesh.material = _track_material(mesh.size, S_BOOST)
	pad.mesh = mesh
	# El patrón de flechas apunta hacia -z local.
	pad.transform = Transform3D(Basis.looking_at(dir), floor_pos + Vector3(0, 0.03, 0))
	add_child(pad)

	var area := _add_area(floor_pos + Vector3(0, 0.5, 0), Vector3(size.x, 1.0, size.y))
	area.body_entered.connect(func(body_in: Node3D) -> void:
		var m := body_in as Marble
		if m != null:
			m.apply_central_impulse(dir * strength)
	)


## Plataforma de salto: lanza la canica hacia `dir` con la velocidad indicada.
func add_jump_pad(floor_pos: Vector3, dir: Vector3, forward_speed: float, up_speed: float) -> void:
	dir = dir.normalized()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.9
	disc.height = 0.08
	disc.material = _material(C_JUMP, 1.5)
	_add_mesh(self, disc, floor_pos + Vector3(0, 0.04, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.95
	ring.outer_radius = 1.15
	ring.material = _material(C_JUMP, 3.0)
	var ring_instance := _add_mesh(self, ring, floor_pos + Vector3(0, 0.06, 0))
	_animators.append(func(t: float) -> void:
		var s := 1.0 + 0.08 * sin(t * 6.0)
		ring_instance.scale = Vector3(s, 1.0, s)
	)

	var area := _add_area(floor_pos + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.6))
	area.body_entered.connect(func(body_in: Node3D) -> void:
		var m := body_in as Marble
		if m != null:
			m.linear_velocity = dir * forward_speed + Vector3.UP * up_speed
	)


## Charco de ácido sobre el suelo: tocarlo hace reaparecer la canica.
func add_acid(floor_pos: Vector3, size: Vector2) -> void:
	var material := _material(C_ACID, 1.5)
	var slab := BoxMesh.new()
	slab.size = Vector3(size.x, 0.04, size.y)
	slab.material = material
	_add_mesh(self, slab, floor_pos + Vector3(0, 0.02, 0))
	_animators.append(func(t: float) -> void:
		material.emission_energy_multiplier = 1.4 + 0.6 * sin(t * 3.0)
	)

	var bubble := SphereMesh.new()
	bubble.radius = 0.07
	bubble.height = 0.14
	bubble.material = _material(C_ACID, 2.5)
	var particles := CPUParticles3D.new()
	particles.mesh = bubble
	particles.amount = int(size.x * size.y * 2.0)
	particles.lifetime = 1.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(size.x / 2.0, 0.01, size.y / 2.0)
	particles.direction = Vector3.UP
	particles.spread = 5.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.5
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.0
	particles.position = floor_pos + Vector3(0, 0.05, 0)
	add_child(particles)

	var area := _add_area(floor_pos + Vector3(0, 0.3, 0), Vector3(size.x - 0.3, 0.6, size.y - 0.3))
	area.body_entered.connect(func(body_in: Node3D) -> void:
		if body_in is Marble:
			marble_killed.emit("ACID")
	)


func add_goal(floor_pos: Vector3) -> void:
	goal_center = floor_pos

	# Plataforma a cuadros
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(3, 0.06, 3)
	var pad_style := S_GOAL.duplicate()
	pad_style.tile_size = 0.5
	pad_mesh.material = _track_material(pad_mesh.size, pad_style)
	_add_mesh(self, pad_mesh, floor_pos + Vector3(0, 0.03, 0))

	# Mástil y bandera a cuadros
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = 3.2
	pole_mesh.material = _material(Color(0.9, 0.9, 0.95))
	_add_mesh(self, pole_mesh, floor_pos + Vector3(1.3, 1.6, -1.3))

	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(1.2, 0.75, 0.04)
	var flag_style := S_GOAL.duplicate()
	flag_style.tile_size = 0.25
	flag_style.pattern_on_sides = true
	flag_style.edge_width = 0.0
	flag_mesh.material = _track_material(flag_mesh.size, flag_style)
	_add_mesh(self, flag_mesh, floor_pos + Vector3(1.94, 2.8, -1.3))

	# Luz y chispas que suben
	_goal_light = OmniLight3D.new()
	_goal_light.light_color = C_GOAL_LIGHT
	_goal_light.light_energy = 2.0
	_goal_light.omni_range = 5.0
	_goal_light.position = floor_pos + Vector3(0, 1.2, 0)
	add_child(_goal_light)

	var spark := SphereMesh.new()
	spark.radius = 0.05
	spark.height = 0.1
	spark.material = _material(C_GOAL_LIGHT, 4.0)
	_goal_particles = CPUParticles3D.new()
	_goal_particles.mesh = spark
	_goal_particles.amount = 40
	_goal_particles.lifetime = 1.6
	_goal_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_goal_particles.emission_box_extents = Vector3(1.4, 0.05, 1.4)
	_goal_particles.direction = Vector3.UP
	_goal_particles.spread = 10.0
	_goal_particles.gravity = Vector3.ZERO
	_goal_particles.initial_velocity_min = 0.8
	_goal_particles.initial_velocity_max = 1.8
	_goal_particles.scale_amount_min = 0.5
	_goal_particles.scale_amount_max = 1.2
	_goal_particles.position = floor_pos + Vector3(0, 0.1, 0)
	add_child(_goal_particles)

	# Zona baja: si la canica bota por encima del damero no cuenta.
	var area := _add_area(floor_pos + Vector3(0, 0.6, 0), Vector3(3, 1.2, 3))
	area.body_entered.connect(func(body_in: Node3D) -> void:
		if body_in is Marble:
			marble_on_goal = true
	)
	area.body_exited.connect(func(body_in: Node3D) -> void:
		if body_in is Marble:
			marble_on_goal = false
	)


## Hace que la meta brille más según avanza la espera (0 a 1).
func set_goal_progress(progress: float) -> void:
	if _goal_light == null:
		return
	_goal_light.light_energy = lerpf(2.0, 8.0, progress)
	_goal_particles.speed_scale = lerpf(1.0, 3.0, progress)


# --- Enemigos y trampas móviles --------------------------------------------

## Erizo que patrulla entre dos puntos del suelo y empuja la canica al tocarla.
func add_patroller(from: Vector3, to: Vector3, period: float, phase := 0.0) -> void:
	var radius := 0.55
	var body := AnimatableBody3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var visual := Node3D.new()
	body.add_child(visual)
	_build_critter(visual, radius)
	_add_knockback(body, radius + 0.2, 6.0)

	var lift := Vector3(0, radius + 0.05, 0)
	body.position = from + lift
	add_child(body)
	_animators.append(func(t: float) -> void:
		var k := 0.5 - 0.5 * cos(TAU * (t / period + phase))
		body.position = from.lerp(to, k) + lift
		visual.position.y = 0.08 * sin(t * 9.0)
		visual.rotation.y = 0.25 * sin(t * 4.0)
	)


## Canica de acero que persigue a la tuya cuando está cerca.
func add_chaser(floor_pos: Vector3, chase_range := 6.0) -> void:
	var chaser := Chaser.new()
	chaser.home = floor_pos + Vector3(0, 0.55, 0)
	chaser.position = chaser.home
	chaser.chase_range = chase_range
	add_child(chaser)
	chasers.append(chaser)


## Pistón que sale en la dirección `dir` (eje x o z) cada `period` segundos.
## `floor_pos` es donde está la cabeza recogida, justo fuera del borde de la pista.
func add_piston(floor_pos: Vector3, dir: Vector3, stroke: float, period: float, phase := 0.0) -> void:
	dir = dir.normalized()
	var along_x := absf(dir.x) > 0.5
	var head_size := Vector3(1.0, 0.8, 1.4) if along_x else Vector3(1.4, 0.8, 1.0)
	var housing_size := Vector3(1.4, 2.0, 1.8) if along_x else Vector3(1.8, 2.0, 1.4)
	add_block(floor_pos - dir * 1.2 + Vector3(0, 1.0, 0), housing_size, S_METAL)

	var body := AnimatableBody3D.new()
	var rest := floor_pos + Vector3(0, 0.45, 0)
	body.position = rest
	_add_box(body, head_size, S_HAZARD)
	_add_knockback(body, 0.9, 8.0)
	add_child(body)
	_animators.append(func(t: float) -> void:
		var p := fposmod(t / period + phase, 1.0)
		var k := 0.0
		if p < 0.5:
			k = 0.0
		elif p < 0.6:
			k = (p - 0.5) / 0.1
		elif p < 0.8:
			k = 1.0
		else:
			k = 1.0 - (p - 0.8) / 0.2
		body.position = rest + dir * stroke * k
	)


## Péndulo que se balancea sobre la pista. `axis` es el eje de giro (normalmente el de la pista).
func add_pendulum(floor_pos: Vector3, length: float, amplitude_degrees: float, period: float, axis := Vector3.BACK, phase := 0.0) -> void:
	axis = axis.normalized()
	var pivot := floor_pos + Vector3(0, length + 0.55, 0)
	var body := AnimatableBody3D.new()
	body.position = pivot

	var rod := CylinderMesh.new()
	rod.top_radius = 0.07
	rod.bottom_radius = 0.07
	rod.height = length
	rod.material = _material(Color(0.7, 0.72, 0.8))
	_add_mesh(body, rod, Vector3(0, -length / 2.0, 0))
	var cap := SphereMesh.new()
	cap.radius = 0.25
	cap.height = 0.5
	cap.material = _material(Color(0.5, 0.52, 0.6))
	_add_mesh(body, cap)

	var head_size := axis.abs() * 1.0 + (Vector3.ONE - axis.abs()) * 0.9
	var style := S_HAZARD.duplicate()
	style.pattern_on_sides = true
	_add_box(body, head_size, style, Transform3D(Basis.IDENTITY, Vector3(0, -length, 0)))
	_add_knockback(body, 0.75, 6.5, Vector3(0, -length, 0))
	add_child(body)

	var amplitude := deg_to_rad(amplitude_degrees)
	_animators.append(func(t: float) -> void:
		body.basis = Basis(axis, amplitude * sin(TAU * (t / period + phase)))
	)


# --- Utilidades -----------------------------------------------------------

## Añade forma de colisión + malla a `body`. Devuelve {collision, mesh}.
func _add_box(body: CollisionObject3D, size: Vector3, style: Dictionary, xform := Transform3D.IDENTITY) -> Dictionary:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = xform
	body.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _track_material(size, style)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = xform
	body.add_child(instance)
	return {collision = collision, mesh = instance}


func _add_mesh(parent: Node3D, mesh: Mesh, offset := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	parent.add_child(instance)
	return instance


func _add_area(center: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	return area


## Zona esférica que da un empujón a la canica al tocarla.
func _add_knockback(parent: Node3D, radius: float, strength: float, offset := Vector3.ZERO) -> void:
	var area := Area3D.new()
	area.position = offset
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	parent.add_child(area)
	area.body_entered.connect(func(body_in: Node3D) -> void:
		var m := body_in as Marble
		if m == null:
			return
		var push := m.global_position - area.global_position
		push.y = 0.0
		if push.length() < 0.01:
			push = Vector3.FORWARD
		m.apply_central_impulse(push.normalized() * strength + Vector3.UP * strength * 0.2)
	)


## Cuerpo del erizo: bola con pinchos y dos ojos mirando a la cámara.
func _build_critter(parent: Node3D, radius: float) -> void:
	var skin := _material(C_ENEMY)
	skin.roughness = 0.4
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.material = skin
	_add_mesh(parent, ball)

	var spike_material := _material(Color(1.0, 0.8, 0.95), 0.6)
	for i in 8:
		var out := Vector3(cos(TAU * i / 8.0), 0.15, sin(TAU * i / 8.0)).normalized()
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.12
		spike.height = 0.35
		spike.material = spike_material
		var instance := _add_mesh(parent, spike, out * (radius + 0.1))
		instance.basis = Basis(Quaternion(Vector3.UP, out))

	var facing := Vector3(1, 0.3, 1).normalized()
	var side := Vector3(1, 0, -1).normalized()
	var white := _material(Color.WHITE, 0.3)
	var black := _material(Color(0.05, 0.02, 0.08))
	for s in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.15
		eye.height = 0.3
		eye.material = white
		var eye_pos: Vector3 = facing * radius * 0.85 + side * 0.2 * s + Vector3(0, 0.12, 0)
		_add_mesh(parent, eye, eye_pos)
		var pupil := SphereMesh.new()
		pupil.radius = 0.075
		pupil.height = 0.15
		pupil.material = black
		_add_mesh(parent, pupil, eye_pos + facing * 0.11)


func _track_material(size: Vector3, style: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TRACK_SHADER
	material.set_shader_parameter("box_size", size)
	material.set_shader_parameter("pattern", style.pattern)
	material.set_shader_parameter("color_a", style.a)
	material.set_shader_parameter("color_b", style.b)
	material.set_shader_parameter("side_color", style.side)
	material.set_shader_parameter("edge_color", style.edge)
	material.set_shader_parameter("tile_size", style.get("tile_size", 1.0))
	material.set_shader_parameter("edge_width", style.get("edge_width", 0.06))
	material.set_shader_parameter("pattern_on_sides", style.get("pattern_on_sides", false))
	material.set_shader_parameter("scroll_speed", style.get("scroll", 0.0))
	return material


func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

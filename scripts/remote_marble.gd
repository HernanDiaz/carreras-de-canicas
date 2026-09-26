class_name RemoteMarble
extends Node3D
## Canica de otro jugador en una carrera. Se dibuja donde dice la red, con un poco de
## predicción para que se mueva suave aunque los datos lleguen 20 veces por segundo.

## Máximo tiempo que se predice hacia delante si dejan de llegar datos.
const MAX_PREDICTION := 0.25
const SMOOTHING := 18.0

var velocity := Vector3.ZERO

var _target_pos := Vector3.ZERO
var _target_rot := Quaternion.IDENTITY
var _age := 0.0
var _has_state := false
var _ball: MeshInstance3D


func setup(mesh: Mesh, color: Color, player_name: String) -> void:
	_ball = MeshInstance3D.new()
	_ball.mesh = mesh
	var material: StandardMaterial3D = (mesh as SphereMesh).material.duplicate()
	material.albedo_color = color
	_ball.material_override = material
	add_child(_ball)

	var label := Label3D.new()
	label.text = player_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = color
	label.position = Vector3(0, 0.95, 0)
	add_child(label)
	visible = false
	add_to_group(Chaser.TARGET_GROUP)


func push_state(pos: Vector3, vel: Vector3, rot: Quaternion) -> void:
	_target_pos = pos
	velocity = vel
	_target_rot = rot
	_age = 0.0
	if not _has_state:
		_has_state = true
		global_position = pos
		visible = true


func _process(delta: float) -> void:
	if not _has_state:
		return
	_age += delta
	var predicted := _target_pos + velocity * minf(_age, MAX_PREDICTION)
	var k := 1.0 - exp(-SMOOTHING * delta)
	global_position = global_position.lerp(predicted, k)
	_ball.quaternion = _ball.quaternion.slerp(_target_rot, k)

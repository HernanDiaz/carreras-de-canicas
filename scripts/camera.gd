class_name MarbleCamera
extends Camera3D
## Cámara isométrica que sigue a la canica.

@export var offset := Vector3(12.0, 14.0, 12.0)
@export var smoothing := 5.0
## La cámara se adelanta en la dirección de la marcha (segundos de velocidad), para ver antes
## lo que viene. Parada, la canica queda en el centro.
@export var lead_time := 0.25
@export var max_lead := 3.0

var target: Node3D


func _process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + offset + _lead()
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))


func _lead() -> Vector3:
	var body := target as RigidBody3D
	if body == null or body.freeze:
		return Vector3.ZERO
	var flat := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z) * lead_time
	return flat.limit_length(max_lead)

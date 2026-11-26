class_name MarbleCamera
extends Camera3D
## Cámara isométrica que sigue a la canica.

@export var offset := Vector3(12.0, 14.0, 12.0)
@export var smoothing := 5.0
## La cámara se adelanta en la dirección de la marcha (segundos de velocidad), para ver antes
## lo que viene. Parada, la canica queda en el centro.
@export var lead_time := 0.25
@export var max_lead := 3.0
## Temblor al chocar fuerte: desplazamiento máximo (en metros) y cuánto dura (segundos a fuerza 1).
@export var max_shake := 0.18
@export var shake_time := 0.35

var target: Node3D
var _shake := 0.0


## Temblor corto (0..1). Usa h_offset/v_offset, así no estorba al seguimiento ni al adelanto.
func shake(amount: float) -> void:
	if not GameState.camera_shake:
		return
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


func _process(delta: float) -> void:
	if _shake > 0.0 or h_offset != 0.0 or v_offset != 0.0:
		_shake = maxf(_shake - delta / shake_time, 0.0)
		var s := _shake * _shake * max_shake
		h_offset = randf_range(-s, s)
		v_offset = randf_range(-s, s)
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

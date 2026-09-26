class_name MarbleCamera
extends Camera3D
## Cámara isométrica que sigue a la canica.

@export var offset := Vector3(12.0, 14.0, 12.0)
@export var smoothing := 5.0

var target: Node3D


func _process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))

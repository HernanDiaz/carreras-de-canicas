class_name TiltSimulator
extends Control
## Simula el sensor de gravedad con el ratón para probar la inclinación en el PC.
## Mantén pulsado el botón izquierdo y arrastra: la distancia al punto de pulsación es la inclinación.
## Se desactiva solo si el dispositivo tiene sensor real.

## Píxeles de arrastre que equivalen a max_degrees de inclinación.
@export var radius := 150.0
@export var max_degrees := 30.0

## Gravedad simulada, con el mismo formato que Input.get_gravity().
var gravity := Vector3(0, 0, -9.81)

var _dragging := false
var _origin := Vector2.ZERO
var _offset := Vector2.ZERO


func has_real_sensor() -> bool:
	return Input.get_gravity() != Vector3.ZERO or Input.get_accelerometer() != Vector3.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ignorar el ratón aquí deja que los botones del HUD reciban sus clics; el resto llega a _unhandled_input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if has_real_sensor():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_origin = event.position
		_offset = Vector2.ZERO
		_update_gravity()
	elif event is InputEventMouseMotion and _dragging:
		_offset = (event.position - _origin).limit_length(radius)
		_update_gravity()


func _update_gravity() -> void:
	var tilt := _offset / radius * deg_to_rad(max_degrees)
	# Derecha en pantalla = inclinar a la derecha; arriba en pantalla = inclinar hacia delante.
	var right := sin(tilt.x)
	var forward := sin(-tilt.y)
	gravity = Vector3(right, forward, -sqrt(maxf(1.0 - right * right - forward * forward, 0.0))) * 9.81
	queue_redraw()


func _draw() -> void:
	if not _dragging:
		return
	draw_circle(_origin, radius, Color(1, 1, 1, 0.08))
	draw_arc(_origin, radius, 0, TAU, 64, Color(1, 1, 1, 0.4), 2.0)
	draw_line(_origin, _origin + _offset, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(_origin + _offset, 18, Color(0.4, 0.8, 1, 0.8))

class_name WaitSpinner
extends Control
## Reloj animado para las esperas: así se ve que el juego no se ha quedado colgado.

var color := UI.C_ACCENT
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(110, 110)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 4.0
	draw_circle(center, radius, Color(0.06, 0.04, 0.14, 0.9))
	draw_arc(center, radius, 0.0, TAU, 64, Color(color, 0.5), 5.0, true)
	for i in 12:
		var dir := Vector2.from_angle(TAU * i / 12.0)
		draw_line(center + dir * (radius - 12.0), center + dir * (radius - 5.0), Color(color, 0.6), 3.0, true)
	# Manecilla larga: una vuelta cada 2 s. Corta: una vuelta cada 24 s.
	draw_line(center, center + Vector2.from_angle(_t * PI - PI / 2.0) * (radius - 16.0), color, 6.0, true)
	draw_line(center, center + Vector2.from_angle(_t * PI / 12.0 - PI / 2.0) * (radius - 32.0), Color.WHITE, 6.0, true)
	draw_circle(center, 7.0, color)

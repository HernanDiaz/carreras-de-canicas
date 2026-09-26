extends Level
## Nivel 1 · Primeros pasos: rampas, parachoques, un puente estrecho y una barredora.


func build() -> void:
	add_start()
	add_ramp(Vector3(0, 0, -3), Vector3(0, -3, -11), 4.0)

	# Plataforma con parachoques
	add_platform(Vector3(0, -3, -15), Vector3(8, 2, 8))
	add_bumper(Vector3(-1.5, -3, -14))
	add_bumper(Vector3(1.8, -3, -16.5))

	# Puente estrecho hacia el este
	add_block(Vector3(9, -3, -15), Vector3(10, 1, 2), S_BRIDGE)

	# Plataforma con barredora giratoria
	add_platform(Vector3(18, -3, -15), Vector3(8, 2, 8))
	add_spinner(Vector3(18, -3, -15), 7.0, 70.0)

	add_ramp(Vector3(18, -3, -19), Vector3(18, -6, -27), 3.0)

	add_platform(Vector3(18, -6, -31), Vector3(8, 2, 8))
	add_goal(Vector3(18, -6, -32))

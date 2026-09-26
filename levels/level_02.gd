extends Level
## Nivel 2 · Hielo resbaladizo: hielo, una plataforma móvil y un acelerador.


func build() -> void:
	add_start()
	add_ramp(Vector3(0, 0, -3), Vector3(0, -2, -9), 4.0)

	# Pista de hielo con parachoques: cuesta frenar y girar
	add_ice_platform(Vector3(0, -2, -14), Vector3(8, 2, 10))
	add_bumper(Vector3(-1.5, -2, -12))
	add_bumper(Vector3(2.0, -2, -16))

	# Puente hacia el oeste
	add_block(Vector3(-8, -2, -17), Vector3(8, 1, 2), S_BRIDGE)
	add_platform(Vector3(-16, -2, -17), Vector3(8, 2, 8))

	# Plataforma móvil que cruza el hueco: súbete y espera
	add_moving_platform(Vector3(-16, -2, -23), Vector3(-16, -2, -27), Vector3(4, 1, 4), 7.0)
	add_platform(Vector3(-16, -2, -33), Vector3(8, 2, 8))

	# Acelerador antes de la rampa final
	add_boost(Vector3(-16, -2, -35), Vector3.FORWARD, 6.0)
	add_ramp(Vector3(-16, -2, -37), Vector3(-16, -5, -44), 3.0)

	add_platform(Vector3(-16, -5, -48), Vector3(8, 2, 8))
	add_block(Vector3(-16, -4.2, -52.25), Vector3(8, 0.8, 0.5), S_WALL)
	add_goal(Vector3(-16, -5, -49))

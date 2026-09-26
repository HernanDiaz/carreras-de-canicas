extends Level
## Nivel 3 · Patrulla: erizos que patrullan y pistones que empujan fuera del puente.


func build() -> void:
	add_start()
	add_ramp(Vector3(0, 0, -3), Vector3(0, -2, -9), 4.0)

	# Primer erizo, de lado a lado
	add_platform(Vector3(0, -2, -13), Vector3(8, 2, 8))
	add_patroller(Vector3(-3, -2, -13), Vector3(3, -2, -13), 3.0)

	# Puente con dos pistones alternos
	add_block(Vector3(0, -2, -23), Vector3(2.5, 1, 12), S_BRIDGE)
	add_piston(Vector3(-2.0, -2, -21), Vector3.RIGHT, 2.8, 2.6)
	add_piston(Vector3(2.0, -2, -25), Vector3.LEFT, 2.8, 2.6, 0.5)

	# Dos erizos cruzándose
	add_platform(Vector3(0, -2, -33), Vector3(8, 2, 8))
	add_patroller(Vector3(-3, -2, -31), Vector3(3, -2, -31), 2.4)
	add_patroller(Vector3(-2, -2, -30), Vector3(-2, -2, -36), 3.0, 0.5)

	# Puente al este vigilado por un erizo que lo cruza
	add_block(Vector3(8, -2, -33), Vector3(8, 1, 2.5), S_BRIDGE)
	add_patroller(Vector3(8, -2, -36), Vector3(8, -2, -30), 2.2)

	add_platform(Vector3(16, -2, -33), Vector3(8, 2, 8))
	add_ramp(Vector3(16, -2, -37), Vector3(16, -5, -45), 3.0)

	add_platform(Vector3(16, -5, -49), Vector3(8, 2, 8))
	add_block(Vector3(16, -4.2, -53.25), Vector3(8, 0.8, 0.5), S_WALL)
	add_goal(Vector3(16, -5, -50))

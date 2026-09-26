extends Level
## Nivel 4 · Canicas de acero: canicas enemigas que te persiguen, trampillas y una barredora doble.


func build() -> void:
	add_start()
	add_ramp(Vector3(0, 0, -3), Vector3(0, -2, -9), 4.0)

	# Dos canicas de acero te esperan
	add_platform(Vector3(0, -2, -15), Vector3(10, 2, 12))
	add_chaser(Vector3(-3, -2, -18))
	add_chaser(Vector3(3, -2, -18))

	# Pasillo con trampillas: espera a que se cierren
	add_block(Vector3(0, -2, -22.5), Vector3(3, 1, 3), S_BRIDGE)
	add_trapdoor(Vector3(0, -2, -25.5), Vector3(3, 1, 3), 3.0, 1.2)
	add_block(Vector3(0, -2, -28.5), Vector3(3, 1, 3), S_BRIDGE)
	add_trapdoor(Vector3(0, -2, -31.5), Vector3(3, 1, 3), 3.0, 1.2, 0.5)

	# Barredora doble
	add_platform(Vector3(0, -2, -37), Vector3(8, 2, 8))
	add_spinner(Vector3(0, -2, -37), 7.0, 80.0, 2)

	add_block(Vector3(8, -2, -37), Vector3(8, 1, 2), S_BRIDGE)

	add_platform(Vector3(16, -2, -37), Vector3(8, 2, 8))
	add_chaser(Vector3(17.5, -2, -39.5))
	add_ramp(Vector3(16, -2, -41), Vector3(16, -5, -48), 3.0)

	add_platform(Vector3(16, -5, -52), Vector3(8, 2, 8))
	add_block(Vector3(16, -4.2, -56.25), Vector3(8, 0.8, 0.5), S_WALL)
	add_goal(Vector3(16, -5, -53))

extends Level
## Nivel 5 · Caída libre: baldosas que se hunden, péndulos, un salto y una plataforma móvil.


func build() -> void:
	add_start()

	# Baldosas que se caen al pisarlas: no te pares
	for i in 5:
		add_crumble(Vector3(0, 0, -4.2 - 2.4 * i), Vector3(2.4, 0.6, 2.4))

	add_platform(Vector3(0, 0, -19), Vector3(8, 2, 8))

	# Puente con dos péndulos
	add_block(Vector3(0, 0, -29), Vector3(3, 1, 12), S_BRIDGE)
	add_pendulum(Vector3(0, 0, -26), 3.5, 70.0, 3.0)
	add_pendulum(Vector3(0, 0, -32), 3.5, 70.0, 3.0, Vector3.BACK, 0.5)

	# Salto al vacío hacia una plataforma más baja
	add_platform(Vector3(0, 0, -39), Vector3(8, 2, 8))
	add_jump_pad(Vector3(0, 0, -41.8), Vector3.FORWARD, 6.0, 6.0)

	add_platform(Vector3(0, -3, -51), Vector3(8, 2, 8))

	# Plataforma móvil hacia el este
	add_moving_platform(Vector3(6, -3, -51), Vector3(14, -3, -51), Vector3(4, 1, 4), 9.0)
	add_platform(Vector3(20, -3, -51), Vector3(8, 2, 8))
	add_ramp(Vector3(20, -3, -55), Vector3(20, -6, -62), 3.0)

	add_platform(Vector3(20, -6, -66), Vector3(8, 2, 8))
	add_block(Vector3(20, -5.2, -70.25), Vector3(8, 0.8, 0.5), S_WALL)
	add_goal(Vector3(20, -6, -67))

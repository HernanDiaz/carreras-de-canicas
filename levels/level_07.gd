extends Level
## Nivel 7 · La fábrica: cuesta con baches, gusanos, cintas transportadoras con pistones,
## prensas, un valle con péndulos y un disco giratorio. Siempre cuesta abajo.


func build() -> void:
	add_start()

	# Cuesta abajo con baches: a buena velocidad saltas en cada uno
	add_waves(Vector3(0, 0, -3), Vector3(0, -4, -19), 4.0, 4, 0.7)

	# El gusano sale de su agujero en cuanto pisas la plataforma
	add_platform(Vector3(0, -4, -23), Vector3(8, 2, 8))
	add_worm(Vector3(-2.7, -4, -20.5), Vector3(0, -4, -23), Vector2(8, 8))
	add_bumper(Vector3(2.4, -4, -24.8))

	# Cinta rápida a favor, con pistones: entra justo cuando se recoge el primero
	add_conveyor(Vector3(0, -4, -27), Vector3(0, -4, -39), 2.5, 10.0)
	add_piston(Vector3(-1.95, -4, -31), Vector3.RIGHT, 2.6, 3.0)
	add_piston(Vector3(1.95, -4, -35.5), Vector3.LEFT, 2.6, 3.0, 0.75)

	# Barredora doble
	add_platform(Vector3(0, -4, -43), Vector3(8, 2, 8))
	add_spinner(Vector3(0, -4, -43), 7.0, 90.0, 2)

	# Prensas desacompasadas: para entre una y otra y elige el momento
	add_block(Vector3(0, -4, -54), Vector3(2.5, 1, 14), S_BRIDGE)
	add_crusher(Vector3(0, -4, -50.5), Vector2(2.5, 2.2), 2.6)
	add_crusher(Vector3(0, -4, -54), Vector2(2.5, 2.2), 2.6, 0.4)
	add_crusher(Vector3(0, -4, -57.5), Vector2(2.5, 2.2), 2.6, 0.8)

	# Dos canicas de acero y un erizo antes de la cinta en contra
	add_platform(Vector3(0, -4, -65), Vector3(8, 2, 8))
	add_chaser(Vector3(-2.5, -4, -67.5))
	add_chaser(Vector3(2.5, -4, -67.5))
	add_patroller(Vector3(-3, -4, -62.8), Vector3(3, -4, -62.8), 2.6)

	# Cinta en contra muy fuerte, con pistones: si te paras, te devuelve atrás
	add_conveyor(Vector3(16, -4, -65), Vector3(4, -4, -65), 3.0, 13.0)
	add_piston(Vector3(8, -4, -67.2), Vector3.BACK, 2.8, 2.4)
	add_piston(Vector3(12.5, -4, -62.8), Vector3.FORWARD, 2.8, 2.4, 0.5)

	# Otro gusano vigila la entrada del valle
	add_platform(Vector3(20, -4, -65), Vector3(8, 2, 8))
	add_worm(Vector3(22.5, -4, -63), Vector3(20, -4, -65), Vector2(8, 8), 3.6)

	# Valle cuesta abajo con péndulos que lo cruzan
	add_valley(Vector3(20, -4, -69), Vector3(20, -8, -83), 5.0, 1.0)
	add_pendulum(Vector3(20, -6.43, -74), 3.5, 65.0, 2.6)
	add_pendulum(Vector3(20, -7.86, -79), 3.5, 65.0, 2.6, Vector3.BACK, 0.4)

	# Cintas de lado: la primera empuja hacia un borde y la segunda hacia el otro
	add_platform(Vector3(20, -9, -87), Vector3(8, 2, 8))
	add_acid(Vector3(17.5, -9, -88.5), Vector2(2.2, 2.5))
	add_acid(Vector3(22.8, -9, -85.5), Vector2(2, 2))
	add_conveyor(Vector3(18, -9, -93.5), Vector3(22, -9, -93.5), 5.0, 11.0)
	add_conveyor(Vector3(22, -9, -98.5), Vector3(18, -9, -98.5), 5.0, 11.0)

	# Un gusano y un parachoques antes del disco
	add_platform(Vector3(20, -9, -105), Vector3(8, 2, 8))
	add_worm(Vector3(17.2, -9, -106.8), Vector3(20, -9, -105), Vector2(8, 8), 3.6)
	add_bumper(Vector3(22.3, -9, -103.5))

	# Disco giratorio con tres barreras: espera en el centro y sal por el otro lado
	add_turntable(Vector3(20, -9, -114.4), 5.3, 35.0, 3)

	# Tras el disco, un erizo y una canica de acero guardan la entrada del tobogán
	add_platform(Vector3(20, -9, -124), Vector3(8, 2, 8))
	add_patroller(Vector3(16.5, -9, -121.6), Vector3(23.5, -9, -121.6), 3.0)
	add_chaser(Vector3(17.5, -9, -126.5), 5.0)

	# Tobogán en espiral hasta la plataforma de la meta
	var slide := add_spiral(Vector3(20, -9, -128), Vector3.FORWARD, 4.0, 1.25, 7.0)
	var goal_top: Vector3 = slide.position + slide.direction * 4.0
	add_platform(goal_top, Vector3(8, 2, 8))
	add_block(goal_top + Vector3(4.25, 0.8, 0), Vector3(0.5, 0.8, 8), S_WALL)
	add_goal(goal_top + Vector3(1, 0, 0))
	add_chaser(goal_top + Vector3(2.5, 0, -2.5), 5.0)

extends Level
## Nivel 9 · La gran torre: subida esquivando barriles, ascensor, salto entre torres, puente que
## se desmorona con viento, bajada por un medio tubo, tobogán de dos vueltas y la meta en el
## centro de un disco giratorio vigilado por canicas de acero.

const TOWER_BOTTOM := -6.0


func build() -> void:
	add_start()

	# Subida con barriles que bajan rodando desde la torre, alternando izquierda y derecha
	add_ramp(Vector3(0, 0, -3), Vector3(0, 4, -15), 4.8)
	add_barrels(Vector3(0, 4, -15), Vector3(0, 0, -3), 4.8, 2.2, 2.8, 0.0, true, 2)

	# Espera al ascensor con un gusano detrás
	add_platform(Vector3(0, 4, -19), Vector3(8, 2, 8))
	add_tower(Vector3(0, 2, -19), Vector2(7, 7), TOWER_BOTTOM)
	add_worm(Vector3(-2.7, 4, -16.5), Vector3(0, 4, -19), Vector2(8, 8))
	add_moving_platform(Vector3(0, 4, -25), Vector3(0, 10, -25), Vector3(4, 1, 4), 8.0)

	# Arriba te esperan dos canicas de acero; salta a la torre de enfrente
	add_platform(Vector3(0, 10, -31), Vector3(8, 2, 8))
	add_tower(Vector3(0, 8, -31), Vector2(7, 7), TOWER_BOTTOM)
	# (lejos del ascensor: si no, te tiran de él nada más llegar arriba)
	add_chaser(Vector3(-2.8, 10, -34), 4.5)
	add_chaser(Vector3(2.8, 10, -34), 4.5)
	add_jump_pad(Vector3(0, 10, -33.8), Vector3.FORWARD, 8.5, 6.0)

	add_platform(Vector3(0, 10, -45), Vector3(8, 2, 8))
	add_tower(Vector3(0, 8, -45), Vector2(7, 7), TOWER_BOTTOM)
	add_spinner(Vector3(0, 10, -45), 7.0, 70.0)

	# Puente que se desmorona, con rachas de viento
	for x in [5.5, 8.5, 11.5, 14.5]:
		add_crumble(Vector3(x, 10, -45), Vector3(3, 0.6, 3))
	add_wind(Vector3(10, 10, -45), Vector3(12, 4, 6), Vector3.BACK, 10.0, 3.0)

	# La cima: dos canicas de acero y un erizo
	add_platform(Vector3(20, 10, -45), Vector3(8, 2, 8))
	add_tower(Vector3(20, 8, -45), Vector2(7, 7), TOWER_BOTTOM)
	add_chaser(Vector3(17.5, 10, -47.5))
	add_chaser(Vector3(22.5, 10, -47.5))
	add_patroller(Vector3(16.5, 10, -42.5), Vector3(23.5, 10, -42.5), 2.6)

	# Gran bajada por un medio tubo con tres péndulos desacompasados (el fondo del surco
	# baja de 8 a 0: a 0,4 por unidad)
	add_valley(Vector3(20, 10, -49), Vector3(20, 2, -69), 6.0, 2.0)
	add_pendulum(Vector3(20, 5.6, -55), 4.0, 60.0, 2.4)
	add_pendulum(Vector3(20, 3.8, -59.5), 4.0, 60.0, 2.4, Vector3.BACK, 0.33)
	add_pendulum(Vector3(20, 2.0, -64), 4.0, 60.0, 2.4, Vector3.BACK, 0.66)

	add_platform(Vector3(20, 0, -73), Vector3(8, 2, 8))
	add_worm(Vector3(22.7, 0, -70.8), Vector3(20, 0, -73), Vector2(8, 8), 3.6)
	add_acid(Vector3(17.3, 0, -74.8), Vector2(2, 2))

	# Tobogán de dos vueltas y cuarto
	var slide := add_spiral(Vector3(20, 0, -77), Vector3.FORWARD, 4.0, 2.25, 10.0)
	var landing: Vector3 = slide.position + slide.direction * 4.0
	add_platform(landing, Vector3(8, 2, 8))
	add_chaser(landing + Vector3(1, 0, -2.5), 5.0)

	# Meta en el centro de un disco giratorio: las barreras no llegan al centro, pero
	# la canica de acero intentará echarte
	var center: Vector3 = landing + slide.direction * (4.0 + 0.3 + 5.5)
	add_turntable(center, 5.5, 40.0, 3, 2.4)
	add_goal(center)
	add_chaser(center + Vector3(0, 0, 3.5), 5.0)

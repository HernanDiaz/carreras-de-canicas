extends Level
## Nivel 10 · Montaña rusa: un tobogán de bajada con curvas, salto de trampolín sobre el vacío,
## una catapulta que te lanza a lo alto, un medio tubo de bajada, una espiral (o un atajo por
## un puente estrecho y otra catapulta), colinas para despegar y una curva peraltada hasta la meta.
## Todo va de velocidad: si llegas lento al trampolín, no pasas.


func build() -> void:
	add_start()

	# Arranque con acelerador hasta el borde
	add_platform(Vector3(0, 0, -8), Vector3(6, 2, 6))
	add_boost(Vector3(0, 0, -9), Vector3.FORWARD, 6.0)

	# Gran bajada en tobogán con curvas. Empieza curvándose poco a poco (como cae la canica
	# a toda velocidad) para que no salga volando por encima de las paredes.
	add_chute(PackedVector3Array([
		Vector3(0, 0, -11), Vector3(0, -0.15, -13), Vector3(0, -0.45, -15), Vector3(0.2, -1.0, -17),
		Vector3(0.5, -1.8, -19), Vector3(1.0, -2.7, -21), Vector3(1.5, -3.6, -23),
		Vector3(2.5, -5.8, -28), Vector3(1.5, -8.0, -33), Vector3(0.3, -9.8, -37),
		Vector3(0, -10.6, -39.5), Vector3(0, -11, -41.5),
	]), 3.2, 1.6)

	# Trampolín al final de la bajada y rampa de aterrizaje al otro lado del vacío
	add_ramp(Vector3(0, -11, -41.5), Vector3(0, -9.8, -45), 3.2)
	add_ramp(Vector3(0, -10.2, -49), Vector3(0, -15, -60), 10.0, S_CHUTE)

	# La catapulta te lanza a la plataforma de arriba
	add_platform(Vector3(0, -15, -65), Vector3(10, 2, 10))
	add_block(Vector3(-5.25, -14.2, -65), Vector3(0.5, 0.8, 10), S_WALL)
	add_block(Vector3(5.25, -14.2, -65), Vector3(0.5, 0.8, 10), S_WALL)
	add_block(Vector3(0, -14.2, -70.25), Vector3(11, 0.8, 0.5), S_WALL)
	add_catapult(Vector3(0, -15, -67.5), Vector3(0, -9, -86), 1.4, 9.6)

	add_platform(Vector3(0, -9, -88), Vector3(8, 2, 10))
	add_block(Vector3(-0.5, -8.2, -93.25), Vector3(9, 0.8, 0.5), S_WALL)
	add_block(Vector3(-4.25, -8.2, -88), Vector3(0.5, 0.8, 10), S_WALL)

	# Bajada por un medio tubo hacia el este (el fondo del surco baja de -11 a -17)
	add_valley(Vector3(4, -9, -88), Vector3(24, -15, -88), 6.0, 2.0)
	add_platform(Vector3(28, -17, -88), Vector3(8, 2, 8))

	# Atajo arriesgado: un puente estrecho y sin barandillas lleva a otra catapulta que se
	# salta la espiral y te deja directamente en las colinas.
	add_ramp(Vector3(28, -17, -92), Vector3(28, -17, -97.5), 1.1, S_BRIDGE)
	add_platform(Vector3(28, -17, -99.5), Vector3(3.4, 2, 4))
	add_catapult(Vector3(28, -17, -100), Vector3(45, -31, -90), 1.6, 2.4)

	# Espiral de dos vueltas: el camino seguro, más largo
	add_spiral(Vector3(32, -17, -88), Vector3.RIGHT, 4.0, 2.0, 14.0, true, 5.0, 3.0)

	# Colinas: el acelerador te lanza y en cada cresta la canica despega un poco
	add_platform(Vector3(46, -31, -89), Vector3(8, 2, 10))
	add_boost(Vector3(48.5, -31, -88), Vector3.RIGHT, 5.0)
	add_waves(Vector3(50, -31, -88), Vector3(68, -31, -88), 4.0, 3, 1.1)
	add_platform(Vector3(72, -31, -88), Vector3(8, 2, 8))

	# Curva peraltada de media vuelta, sin paredes y con el hueco en medio
	add_banked_curve(Vector3(76, -31, -96), 8.0, 0.0, PI, 3.6, 22.0, 1.5)

	# Meta al salir de la curva
	add_platform(Vector3(72, -32.5, -104), Vector3(8, 2, 8))
	add_block(Vector3(67.75, -31.7, -104), Vector3(0.5, 0.8, 8.5), S_WALL)
	add_goal(Vector3(71, -32.5, -104))

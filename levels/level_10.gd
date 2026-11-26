extends Level
## Nivel 10 · Montaña rusa: un tobogán de bajada con curvas, salto de trampolín sobre el vacío,
## una catapulta que te lanza a lo alto, un medio tubo de bajada y un último salto a la meta.
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
	add_jump_pad(Vector3(31.2, -17, -88), Vector3.RIGHT, 9.0, 5.0)

	# Isla de la meta al otro lado del último salto
	add_platform(Vector3(41, -17, -88), Vector3(8, 2, 8))
	add_block(Vector3(45.25, -16.2, -88), Vector3(0.5, 0.8, 8.5), S_WALL)
	add_goal(Vector3(41, -17, -88))

extends Level
## Nivel 10 · El estanque: un río que cruzar saltando de nenúfar en nenúfar (se hunden si te
## paras) con un remolino río abajo, un canal con corriente a favor y rocas, y un estanque con
## un gran remolino en medio y la meta en una isla al fondo.
## El agua no te hace reaparecer: se nada (peor que rodar) y se sale por las playas.

const WATER := -1.0


func build() -> void:
	add_start()
	add_ramp(Vector3(0, 0, -3), Vector3(0, WATER, -7), 4.0)
	add_platform(Vector3(2, WATER, -11), Vector3(24, 2, 8))

	# El río (de oeste a este) con nenúfares para cruzarlo y un remolino río abajo
	add_block(Vector3(2, -3, -20), Vector3(24, 1, 10), S_HILL)
	add_block(Vector3(-10.25, 0, -20), Vector3(0.5, 3, 10), S_WALL)
	add_block(Vector3(14.25, 0, -20), Vector3(0.5, 3, 10), S_WALL)
	add_water(Vector3(2, WATER, -20), Vector3(24, 2, 10), Vector3(2.5, 0, 0))
	add_lily_pad(Vector3(0, WATER, -16.2), 1.1, 1.8, true)
	add_lily_pad(Vector3(0.7, WATER, -18.6))
	add_lily_pad(Vector3(-0.5, WATER, -21.0), 1.1, 1.8, true)
	add_lily_pad(Vector3(0.3, WATER, -23.8))
	# Si te caes, la corriente te lleva hacia el remolino: antes hay una playa a cada orilla
	add_ramp(Vector3(5, -2.4, -18.5), Vector3(5, WATER, -15), 3.0, S_HILL)
	add_ramp(Vector3(5, -2.4, -21.5), Vector3(5, WATER, -25), 3.0, S_HILL)
	add_whirlpool(Vector3(11, WATER, -20), 3.5, 6.0, 4.0)

	add_platform(Vector3(2, WATER, -29), Vector3(24, 2, 8))

	# Canal con corriente a favor y rocas
	add_block(Vector3(0, -3, -44), Vector3(4, 1, 22), S_HILL)
	add_block(Vector3(-2.25, 0, -44), Vector3(0.5, 3, 22), S_WALL)
	add_block(Vector3(2.25, 0, -44), Vector3(0.5, 3, 22), S_WALL)
	add_water(Vector3(0, WATER, -44), Vector3(4, 2, 22), Vector3(0, 0, -3.5))
	add_bumper(Vector3(-0.9, WATER, -40))
	add_bumper(Vector3(0.9, WATER, -46))
	add_ramp(Vector3(0, -2.4, -51.5), Vector3(0, WATER, -55), 4.0, S_HILL)

	add_platform(Vector3(0, WATER, -59), Vector3(16, 2, 8))

	# El estanque: gran remolino en medio, nenúfares por el borde oeste hasta la isla
	add_block(Vector3(0, -3, -73), Vector3(16, 1, 20), S_HILL)
	add_block(Vector3(-8.25, 0, -73), Vector3(0.5, 3, 20), S_WALL)
	add_block(Vector3(8.25, 0, -73), Vector3(0.5, 3, 20), S_WALL)
	add_water(Vector3(0, WATER, -73), Vector3(16, 2, 20))
	add_whirlpool(Vector3(1.5, WATER, -73), 6.0, 9.0, 6.0)
	# Playa para volver a la orilla si te caes lejos del remolino
	add_ramp(Vector3(6, -2.4, -66.5), Vector3(6, WATER, -63), 3.0, S_HILL)
	for i in 9:
		add_lily_pad(Vector3(-5.5 if i % 2 == 0 else -5.0, WATER, -64.2 - 2.25 * i), 1.1, 1.8, i % 3 == 1)

	add_platform(Vector3(-2, WATER, -87), Vector3(12, 2, 8))
	add_block(Vector3(-2, -0.2, -91.25), Vector3(12.5, 0.8, 0.5), S_WALL)
	add_goal(Vector3(0, WATER, -88))

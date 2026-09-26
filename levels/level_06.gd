extends Level
## Nivel 6 · Desafío final: de todo un poco, con charcos de ácido y un erizo guardando la meta.


func build() -> void:
	add_start()
	make_icy(add_ramp(Vector3(0, 0, -3), Vector3(0, -3, -11), 3.0, S_ICE_RAMP))

	# Ácido y una canica de acero
	add_platform(Vector3(0, -3, -15), Vector3(10, 2, 8))
	add_acid(Vector3(-3, -3, -16), Vector2(2.5, 3))
	add_acid(Vector3(2.8, -3, -13.5), Vector2(2.2, 2.5))
	add_chaser(Vector3(3, -3, -17.5))

	# Pasillo mixto: espera a la trampilla, descansa en la baldosa firme y corre sobre las que se caen
	add_trapdoor(Vector3(0, -3, -20.5), Vector3(3, 1, 3), 3.2, 1.2)
	add_block(Vector3(0, -3, -23.5), Vector3(3, 1, 3), S_BRIDGE)
	add_crumble(Vector3(0, -3, -26.5), Vector3(3, 0.6, 3))
	add_crumble(Vector3(0, -3, -29.5), Vector3(3, 0.6, 3))

	add_platform(Vector3(0, -3, -35), Vector3(8, 2, 8))
	add_patroller(Vector3(-3, -3, -34), Vector3(3, -3, -34), 2.5)
	add_bumper(Vector3(-2, -3, -37))

	# Plataforma móvil al este
	add_moving_platform(Vector3(6, -3, -35), Vector3(12, -3, -35), Vector3(4, 1, 4), 8.0)
	add_platform(Vector3(18, -3, -35), Vector3(8, 2, 8))

	# Puente estrecho con péndulos
	add_block(Vector3(18, -3, -44), Vector3(2.5, 1, 10), S_BRIDGE)
	add_pendulum(Vector3(18, -3, -42), 3.5, 70.0, 3.0)
	add_pendulum(Vector3(18, -3, -46), 3.5, 70.0, 3.0, Vector3.BACK, 0.35)

	# Dos canicas de acero y un acelerador hacia la rampa
	add_platform(Vector3(18, -3, -53), Vector3(8, 2, 8))
	add_chaser(Vector3(15.5, -3, -55.5))
	add_chaser(Vector3(20.5, -3, -55.5))
	add_boost(Vector3(18, -3, -56), Vector3.FORWARD, 5.0)
	add_ramp(Vector3(18, -3, -57), Vector3(18, -7, -65), 3.0)

	# Meta vigilada: el erizo pasa por la parte delantera del damero
	add_platform(Vector3(18, -7, -69), Vector3(8, 2, 8))
	add_block(Vector3(18, -6.2, -73.25), Vector3(8, 0.8, 0.5), S_WALL)
	add_goal(Vector3(18, -7, -70))
	add_patroller(Vector3(14.5, -7, -69), Vector3(21.5, -7, -69), 4.0)

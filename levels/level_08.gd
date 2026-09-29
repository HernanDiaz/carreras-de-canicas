extends Level
## Nivel 8 · Vendaval: rachas de viento que te sacan de la pista, balancines, una cresta
## estrecha, un laberinto con erizos y un tobogán hasta una meta azotada por el viento.

const MAZE := Vector3(20, -7, -60.5)


func build() -> void:
	add_start()

	# Bajada por un valle hasta la primera plataforma, donde espera un gusano
	add_valley(Vector3(0, 0, -3), Vector3(0, -3, -13), 5.0, 1.0)
	add_platform(Vector3(0, -4, -17), Vector3(8, 2, 8))
	add_worm(Vector3(2.7, -4, -14.3), Vector3(0, -4, -17), Vector2(8, 8))
	add_bumper(Vector3(-2.3, -4, -18.8))
	add_chaser(Vector3(-2.5, -4, -20), 4.5)

	# Puente estrecho con rachas de viento de un lado y del otro
	add_block(Vector3(0, -4, -28), Vector3(1.8, 1, 14), S_BRIDGE)
	add_wind(Vector3(0, -4, -24.5), Vector3(7, 4, 6), Vector3.RIGHT, 18.0, 3.2)
	add_wind(Vector3(0, -4, -31.5), Vector3(7, 4, 6), Vector3.LEFT, 18.0, 3.2, 0.5)

	add_platform(Vector3(0, -4, -39), Vector3(8, 2, 8))
	add_chaser(Vector3(-2.5, -4, -41.5))
	add_chaser(Vector3(2.5, -4, -41.5))

	# Tres balancines: de lado, de frente y de lado
	add_seesaw(Vector3(0, -4, -45.25), Vector3(2.4, 0.5, 4), Vector3.BACK, 30.0, 2.4)
	add_seesaw(Vector3(0, -4, -49.75), Vector3(2.4, 0.5, 4), Vector3.RIGHT, 22.0, 2.4, 0.33)
	add_seesaw(Vector3(0, -4, -54.25), Vector3(2.4, 0.5, 4), Vector3.BACK, 30.0, 2.4, 0.66)

	add_platform(Vector3(0, -4, -60.5), Vector3(8, 2, 8))
	add_acid(Vector3(-2.3, -4, -62.8), Vector2(2.2, 2.2))
	add_patroller(Vector3(2.8, -4, -57.5), Vector3(2.8, -4, -63.5), 2.4)
	add_chaser(Vector3(-2.5, -4, -58.5), 5.0)

	# Cresta estrecha cuesta abajo con viento de costado
	add_ramp(Vector3(4, -4, -60.5), Vector3(14, -7, -60.5), 1.1)
	add_wind(Vector3(9, -6.2, -60.5), Vector3(10, 6, 6), Vector3.BACK, 16.0, 2.8, 0.2)

	# Laberinto con erizos y una canica de acero
	add_platform(MAZE, Vector3(12, 2, 12), S_FLOOR, Vector3(-4.5, 0, 0))
	_maze_wall(Vector2(-6, -6), Vector2(6, -6))
	_maze_wall(Vector2(-6, 6), Vector2(6, 6))
	_maze_wall(Vector2(-6, -6), Vector2(-6, -1.2))
	_maze_wall(Vector2(-6, 1.2), Vector2(-6, 6))
	_maze_wall(Vector2(6, -6), Vector2(6, -1.2))
	_maze_wall(Vector2(6, 1.2), Vector2(6, 6))
	_maze_wall(Vector2(-3, -6), Vector2(-3, 3.6))
	_maze_wall(Vector2(0, -3.6), Vector2(0, 6))
	_maze_wall(Vector2(3, -6), Vector2(3, 3.6))
	add_patroller(MAZE + Vector3(-1.5, 0, 4), MAZE + Vector3(-1.5, 0, -4), 3.5)
	add_patroller(MAZE + Vector3(1.5, 0, -4), MAZE + Vector3(1.5, 0, 4), 3.0, 0.5)
	add_chaser(MAZE + Vector3(4.5, 0, -4.5), 5.0)
	add_chaser(MAZE + Vector3(-4.5, 0, -4.5), 5.0)
	# Trampillas en las curvas del laberinto
	add_trapdoor(MAZE + Vector3(-4.5, 0, 4.8), Vector3(2.6, 1, 2.2), 2.6, 1.0)
	add_trapdoor(MAZE + Vector3(1.5, 0, -4.8), Vector3(2.6, 1, 2.2), 2.6, 1.0, 0.5)
	add_trapdoor(MAZE + Vector3(4.5, 0, 4.8), Vector3(2.6, 1, 2.2), 2.6, 1.0, 0.25)

	# Baches cuesta abajo con rachas que empujan hacia el borde
	add_waves(Vector3(26, -7, -60.5), Vector3(38, -10, -60.5), 3.0, 3, 0.8)
	add_wind(Vector3(32, -9.5, -60.5), Vector3(12, 6, 7), Vector3.FORWARD, 11.0, 3.0, 0.4)

	add_platform(Vector3(42, -10, -60.5), Vector3(8, 2, 8))
	add_worm(Vector3(44.7, -10, -58), Vector3(42, -10, -60.5), Vector2(8, 8), 3.6)
	add_bumper(Vector3(39.5, -10, -63))

	# Tobogán en espiral hacia la meta
	var slide := add_spiral(Vector3(42, -10, -64.5), Vector3.FORWARD, 3.5, 1.0, 6.0, false)
	var goal_top: Vector3 = slide.position + slide.direction * 4.0

	# Meta con viento que empuja hacia el borde sin pared
	add_platform(goal_top, Vector3(8, 2, 8))
	add_block(goal_top + Vector3(0, 0.8, -4.25), Vector3(8, 0.8, 0.5), S_WALL)
	add_goal(goal_top + Vector3(0, 0, -1))
	add_wind(goal_top, Vector3(8, 4, 8), Vector3.RIGHT, 16.0, 3.5)
	add_chaser(goal_top + Vector3(-2.5, 0, -2.5), 5.0)


## Pared del laberinto entre dos puntos (x, z) relativos a su centro, en horizontal o vertical.
func _maze_wall(a: Vector2, b: Vector2) -> void:
	var middle := (a + b) / 2.0
	var length := a.distance_to(b) + 0.3
	var size := Vector3(length, 0.8, 0.3) if absf(a.y - b.y) < 0.01 else Vector3(0.3, 0.8, length)
	add_block(MAZE + Vector3(middle.x, 0.8, middle.y), size, S_WALL)

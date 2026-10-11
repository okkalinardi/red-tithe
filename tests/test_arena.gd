extends Node
## Regression test for the arena: painted floor, obstacles that block the
## player, enemies and arrows, and spawns kept out of obstacles. Run this
## scene (F6) and read the Output panel. It takes about ten seconds.

const _ARENA_SCENE: PackedScene = preload("res://scenes/arena/arena.tscn")
const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const _RAT: EnemyData = preload("res://data/enemies/gutter_rat.tres")
const _BOW: ProjectileWeaponData = preload("res://data/weapons/bow.tres")

var _failures: int = 0
var _checks: int = 0
var _arena: Arena


func _ready() -> void:
	_arena = _ARENA_SCENE.instantiate() as Arena
	add_child(_arena)
	await _wait(2)
	_test_floor()
	_test_obstacles()
	_test_free_points()
	var obstacle: Vector2i = _find_lone_obstacle()
	_check("the layout has an obstacle with open ground on both sides", float(obstacle != Vector2i(-1, -1)), 1.0)
	await _test_player_is_blocked(obstacle)
	await _test_enemy_is_blocked(obstacle)
	await _test_arrow_is_blocked(obstacle)
	await _test_spawns_avoid_obstacles()
	_test_main_scene()
	print("Arena tests: %d checks, %d failed" % [_checks, _failures])


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


# An obstacle tile with at least five free cells to its left and right.
func _find_lone_obstacle() -> Vector2i:
	for cell: Vector2i in _arena.get_obstacle_cells():
		var is_alone: bool = true
		for offset: int in range(-5, 6):
			if offset != 0 and _arena.obstacle_layer.get_cell_source_id(cell + Vector2i(offset, 0)) != -1:
				is_alone = false
		for offset: int in [-1, 1]:
			for side: int in range(-5, 6):
				if _arena.obstacle_layer.get_cell_source_id(cell + Vector2i(side, offset)) != -1:
					is_alone = false
		if is_alone and cell.x > 6:
			return cell
	return Vector2i(-1, -1)


# The x of the left face of an obstacle tile's collision polygon, in world space.
func _left_face_x(cell: Vector2i) -> float:
	var data: TileData = _arena.obstacle_layer.get_cell_tile_data(cell)
	var points: PackedVector2Array = data.get_collision_polygon_points(0, 0)
	var smallest: float = INF
	for point: Vector2 in points:
		smallest = minf(smallest, point.x)
	return _arena.cell_to_world(cell).x + smallest


func _test_floor() -> void:
	var floor_layer: TileMapLayer = _arena.floor_layer
	_check("the floor covers the whole arena", float(floor_layer.get_used_rect() == Rect2i(Vector2i.ZERO, _arena.size_in_tiles)), 1.0)
	_check("every floor cell is painted", floor_layer.get_used_cells().size(), _arena.size_in_tiles.x * _arena.size_in_tiles.y)
	_check("the floor has no collision", float(floor_layer.collision_enabled), 0.0)
	_check("the arena is still 960 by 544", float(_arena.get_bounds() == Rect2i(0, 0, 960, 544)), 1.0)
	_check("floor tiles are 16 px", float(floor_layer.tile_set.tile_size == Vector2i(16, 16)), 1.0)


func _test_obstacles() -> void:
	var cells: Array[Vector2i] = _arena.get_obstacle_cells()
	_check("there are obstacles", float(cells.size() >= 8), 1.0)
	_check("obstacle tiles collide on the world layer", _arena.obstacle_layer.tile_set.get_physics_layer_collision_layer(0), PhysicsLayers.WORLD)
	var with_collision: int = 0
	var away_from_centre: int = 0
	var away_from_walls: int = 0
	var centre: Vector2i = _arena.size_in_tiles / 2
	for cell: Vector2i in cells:
		var data: TileData = _arena.obstacle_layer.get_cell_tile_data(cell)
		with_collision += int(data != null and data.get_collision_polygons_count(0) > 0)
		away_from_centre += int(maxi(absi(cell.x - centre.x), absi(cell.y - centre.y)) >= 5)
		away_from_walls += int(cell.x >= 2 and cell.y >= 2 and cell.x < _arena.size_in_tiles.x - 2 and cell.y < _arena.size_in_tiles.y - 2)
	_check("every obstacle tile has a collision shape", with_collision, cells.size())
	_check("the player's start area is clear", away_from_centre, cells.size())
	_check("no obstacle hugs a wall", away_from_walls, cells.size())


func _test_free_points() -> void:
	var centre: Vector2 = Vector2(_arena.get_bounds().get_center())
	var cell: Vector2i = _arena.get_obstacle_cells()[0]
	_check("the centre is free", float(_arena.is_point_free(centre, 40.0)), 1.0)
	_check("an obstacle is not free", float(_arena.is_point_free(_arena.cell_to_world(cell))), 0.0)
	_check("next to an obstacle is not free with clearance", float(_arena.is_point_free(_arena.cell_to_world(cell) + Vector2(12, 0), 10.0)), 0.0)
	_check("outside the arena is not free", float(_arena.is_point_free(Vector2(-20, 100))), 0.0)
	_check("against a wall is not free with clearance", float(_arena.is_point_free(Vector2(4, 100), 10.0)), 0.0)


func _test_player_is_blocked(obstacle: Vector2i) -> void:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	var centre: Vector2 = _arena.cell_to_world(obstacle)
	player.position = centre - Vector2(40, 0)
	add_child(player)
	player.weapons.firing_enabled = false
	await _wait(2)
	Input.action_press(&"move_right")
	await _wait(90)
	Input.action_release(&"move_right")
	await _wait(2)
	var face: float = _left_face_x(obstacle)
	_check("an obstacle stops the player", player.global_position.x, face - 5.0, 1.0)
	player.queue_free()
	await _wait(2)


func _test_enemy_is_blocked(obstacle: Vector2i) -> void:
	var centre: Vector2 = _arena.cell_to_world(obstacle)
	var target := Node2D.new()
	target.position = centre + Vector2(60, 0)
	add_child(target)
	var data: EnemyData = _RAT.duplicate() as EnemyData
	data.body_radius = 5.0
	var rat: Enemy = Enemy.spawn(data, centre - Vector2(50, 0), target)
	await _wait(120)
	_check("an obstacle stops an enemy", rat.global_position.x, _left_face_x(obstacle) - 5.0, 1.5)
	Enemy.despawn_all()
	target.queue_free()
	await _wait(2)


func _test_arrow_is_blocked(obstacle: Vector2i) -> void:
	var centre: Vector2 = _arena.cell_to_world(obstacle)
	var body := Node2D.new()
	body.position = centre + Vector2(30, 0)
	var health := HealthComponent.new()
	health.base_max_hp = 100
	body.add_child(health)
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = PhysicsLayers.ENEMY
	hurtbox.health = health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	hurtbox.add_child(shape)
	body.add_child(hurtbox)
	add_child(body)
	var stats := StatBlock.new()
	var bow: ProjectileWeapon = _BOW.weapon_scene.instantiate() as ProjectileWeapon
	bow.setup(_BOW, stats)
	bow.position = centre - Vector2(60, 0)
	add_child(bow)
	await _wait(3)
	var pool: ObjectPool = Pools.get_pool(_BOW.projectile_scene)
	bow.tick(100.0, Vector2.RIGHT, true)
	await _wait(45)
	_check("an obstacle stops an arrow", health.current_hp, 100)
	_check("the stopped arrow went back to the pool", pool.get_active_count(), 0)
	bow.position = centre + Vector2(-60, -40)
	bow.tick(100.0, Vector2(90, 40).normalized(), true)
	await _wait(45)
	_check("an arrow that misses the obstacle still hits", float(health.current_hp < 100), 1.0)
	bow.queue_free()
	body.queue_free()
	await _wait(2)


func _test_spawns_avoid_obstacles() -> void:
	var target := Node2D.new()
	target.position = Vector2(_arena.get_bounds().get_center())
	target.add_child(Camera2D.new())
	add_child(target)
	var wave := WaveData.new()
	wave.duration = 30.0
	wave.spawn_interval = 0.05
	wave.batch_size = 10
	var entry := WaveSpawnEntry.new()
	entry.enemy = _RAT
	wave.entries.append(entry)
	var spawner := WaveSpawner.new()
	spawner.waves = [wave]
	add_child(spawner)
	var points: Array[Vector2] = []
	spawner.enemy_spawned.connect(func(enemy: Enemy) -> void: points.append(enemy.global_position))

	spawner.setup(target, _arena.get_bounds(), _arena.is_point_free.bind(10.0))
	spawner.start_wave(1)
	await _wait(40)
	spawner.stop()
	var free_count: int = 0
	for point: Vector2 in points:
		free_count += int(_arena.is_point_free(point, 10.0))
	_check("enemies were spawned", float(points.size() >= 90), 1.0)
	_check("no enemy spawns in or against an obstacle", free_count, points.size())
	Enemy.despawn_all()
	await _wait(2)

	# The spawner really asks: forbid the left half and nothing appears there.
	points.clear()
	var centre_x: float = target.position.x
	spawner.setup(target, _arena.get_bounds(), func(point: Vector2) -> bool: return point.x >= centre_x)
	spawner.start_wave(1)
	await _wait(40)
	spawner.stop()
	var right_side: int = 0
	for point: Vector2 in points:
		right_side += int(point.x >= centre_x)
	_check("spawns follow the spawn filter", right_side, points.size())
	Enemy.despawn_all()
	spawner.queue_free()
	target.queue_free()
	await _wait(2)


func _test_main_scene() -> void:
	var main: Node = _MAIN_SCENE.instantiate()
	var arena: Arena = main.get_node("Arena") as Arena
	_check("the main scene uses the tile arena", float(arena.get_node_or_null("Obstacles") is TileMapLayer), 1.0)
	main.free()

extends Node
## Regression test for the Carrion Crow (shooter) and pooled enemy
## projectiles. Run this scene (F6) and read the Output panel. It takes
## about 15 seconds because the crow really flies and shoots.

const _CROW: ShooterEnemyData = preload("res://data/enemies/carrion_crow.tres")
const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _ORIGIN: Vector2 = Vector2(2000, 2000)

var _failures: int = 0
var _checks: int = 0
var _player: Player
var _shard: PackedScene


func _ready() -> void:
	Pools.set_host(self)
	_shard = _CROW.projectile_scene
	_test_data()
	await _setup_player()
	await _test_keeps_distance()
	await _test_aim_and_shoot()
	await _test_hit_and_damage()
	await _test_blocked_by_obstacle()
	await _test_fairness()
	await _test_shared_pool_and_cleanup()
	await _test_pooled_reuse()
	print("Carrion Crow tests: %d checks, %d failed" % [_checks, _failures])


func _test_data() -> void:
	_check("the crow's scene is a shooter", float(_CROW.scene.instantiate() is ShooterEnemy), 1.0)
	_check("it keeps a distance band", float(_CROW.min_distance < _CROW.max_distance), 1.0)
	_check("it fires from beyond its band", float(_CROW.fire_range > _CROW.max_distance), 1.0)
	_check("it has a wind-up", float(_CROW.aim_time > 0.2), 1.0)
	var shard: Projectile = _shard.instantiate() as Projectile
	_check("the shard is a Projectile", float(shard != null), 1.0)
	_check("the shard is an enemy attack", shard.collision_layer, PhysicsLayers.ENEMY_ATTACK)
	_check("the shard hits the player and walls only", shard.collision_mask, PhysicsLayers.PLAYER | PhysicsLayers.WORLD)
	_check("the shard can be seen by walls", float(shard.monitorable), 1.0)
	shard.free()
	for wave: int in range(1, 11):
		var data: WaveData = load("res://data/waves/wave_%02d.tres" % wave) as WaveData
		var has_crow: bool = data.entries.any(func(e: WaveSpawnEntry) -> bool: return e.enemy == _CROW)
		_check("wave %d %s the crow" % [wave, "has" if wave >= 4 else "lacks"], float(has_crow), float(wave >= 4))


func _setup_player() -> void:
	_player = _PLAYER_SCENE.instantiate() as Player
	_player.position = _ORIGIN
	add_child(_player)
	await get_tree().physics_frame
	_player.weapons.firing_enabled = false
	_player.skills.casting_enabled = false
	_player.collector.disable()
	_player.set_physics_process(false)
	# No regen and no i-frames, so every landed hit shows in HP exactly.
	_player.health.process_mode = Node.PROCESS_MODE_DISABLED
	_player.health.invincibility_time = 0.0


func _spawn(offset: Vector2, damage_multiplier: float = 1.0) -> ShooterEnemy:
	var crow: ShooterEnemy = Enemy.spawn(_CROW, _ORIGIN + offset, _player, 1.0, damage_multiplier) as ShooterEnemy
	crow.rng.seed = 7
	return crow


func _test_keeps_distance() -> void:
	var crow: ShooterEnemy = _spawn(Vector2(260, 0))
	crow.fire_cooldown_left = 999.0
	# 140 px to cover at 55 px/s.
	await _wait(210)
	var distance: float = crow.global_position.distance_to(_ORIGIN)
	_check("a far crow closes to its band", float(distance <= _CROW.max_distance + 6.0 and distance >= _CROW.min_distance - 6.0), 1.0)
	if distance > _CROW.max_distance + 6.0 or distance < _CROW.min_distance - 6.0:
		print("      distance was %.1f" % distance)
	var angle_before: float = (crow.global_position - _ORIGIN).angle()
	await _wait(60)
	var angle_after: float = (crow.global_position - _ORIGIN).angle()
	_check("inside its band it circles the player", float(absf(angle_difference(angle_before, angle_after)) > 0.2), 1.0)
	crow.global_position = _ORIGIN + Vector2(0, 25)
	await _wait(90)
	_check("a crow too close backs off", float(crow.global_position.distance_to(_ORIGIN) >= _CROW.min_distance - 6.0), 1.0)
	_check("it never shot while on cooldown", Projectile.active.size(), 0)
	crow.despawn()
	await _wait(2)


func _test_aim_and_shoot() -> void:
	var crow: ShooterEnemy = _spawn(Vector2(100, 0))
	crow.fire_cooldown_left = 0.0
	await _wait(2)
	_check_state("ready and in range, it winds up", crow, &"Aim")
	_check("the wind-up tints the crow", float((crow.get_node("Sprite") as AnimatedSprite2D).modulate != Color.WHITE), 1.0)
	_check("no shot during the wind-up", Projectile.active.size(), 0)
	await _wait(roundi(_CROW.aim_time * 60.0) + 2)
	_check_state("after the wind-up it shoots", crow, &"Shoot")
	_check("one shard in flight", Projectile.active.size(), 1)
	_check("the tint is gone", float((crow.get_node("Sprite") as AnimatedSprite2D).modulate == Color.WHITE), 1.0)
	var shard: Projectile = Projectile.active[0]
	var to_player: Vector2 = (shard.global_position).direction_to(_ORIGIN)
	_check("the shard flies at the player", Vector2.from_angle(shard.rotation).dot(to_player), 1.0, 0.05)
	var cooldown: float = crow.fire_cooldown_left
	_check("the next attack waits about fire_interval", float(cooldown >= _CROW.fire_interval * 0.8 and cooldown <= _CROW.fire_interval * 1.2), 1.0)
	await _wait(roundi(_CROW.recover_time * 60.0) + 2)
	_check_state("after the shot it moves again", crow, &"Reposition")
	crow.despawn()
	Projectile.despawn_all()
	await _wait(2)


func _test_hit_and_damage() -> void:
	_player.health.restore_full()
	var crow: ShooterEnemy = _spawn(Vector2(90, 0))
	crow.fire_cooldown_left = 0.0
	await _wait_until(func() -> bool: return Projectile.active.size() > 0, 120)
	crow.fire_cooldown_left = 999.0
	await _wait_until(func() -> bool: return Projectile.active.is_empty(), 180)
	_check("the shard hit for its damage", _player.health.current_hp, 100.0 - _CROW.projectile_damage)
	_check("the shard went back to its pool", Pools.get_pool(_shard).get_active_count(), 0)
	crow.despawn()
	await _wait(2)

	_player.health.restore_full()
	var tough: ShooterEnemy = _spawn(Vector2(90, 0), 1.5)
	tough.fire_cooldown_left = 0.0
	await _wait_until(func() -> bool: return Projectile.active.size() > 0, 120)
	tough.fire_cooldown_left = 999.0
	# Despawn the shooter while its shot is in flight: the shot keeps its damage.
	tough.despawn()
	await _wait_until(func() -> bool: return Projectile.active.is_empty(), 180)
	_check("the wave damage multiplier applies, even after the crow is gone", _player.health.current_hp, 100.0 - roundi(_CROW.projectile_damage * 1.5))
	_player.health.restore_full()
	await _wait(2)


func _test_blocked_by_obstacle() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 60)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = _ORIGIN + Vector2(45, -4)
	add_child(wall)
	var crow: ShooterEnemy = _spawn(Vector2(90, 0))
	crow.set_physics_process(false)
	await _wait(2)
	_check("fire_at launches one shard", crow.fire_at(_ORIGIN), 1)
	await _wait(90)
	_check("the wall stopped the shard", Projectile.active.size(), 0)
	_check("the player behind the wall was not hit", _player.health.current_hp, 100.0)
	crow.set_physics_process(true)
	crow.despawn()
	wall.queue_free()
	await _wait(2)


func _test_fairness() -> void:
	# Below the visible area but inside fire range: it must not fire.
	var crow: ShooterEnemy = _spawn(Vector2(0, 150))
	crow.fire_cooldown_left = 0.0
	await _wait(5)
	_check("off screen it does not wind up", float(crow.state_machine.get_state_name() == &"Reposition"), 1.0)
	crow.despawn()
	var far: ShooterEnemy = _spawn(Vector2(230, 0))
	far.fire_cooldown_left = 0.0
	await _wait(2)
	_check_state("out of fire range it does not wind up", far, &"Reposition")
	far.despawn()
	await _wait(2)


func _test_shared_pool_and_cleanup() -> void:
	var a: ShooterEnemy = _spawn(Vector2(100, 0))
	var b: ShooterEnemy = _spawn(Vector2(-100, 0))
	for crow: ShooterEnemy in [a, b]:
		crow.set_physics_process(false)
		crow.fire_at(_ORIGIN + Vector2(0, -200))
	await _wait(1)
	var pool: ObjectPool = Pools.get_pool(_shard)
	_check("two crows, two shards in flight", Projectile.active.size(), 2)
	_check("both come from one shared pool", float(Projectile.active.all(func(p: Projectile) -> bool: return p.get_parent() == pool)), 1.0)
	_check("the pool was prewarmed", float(pool.get_total_count() >= _CROW.projectile_pool_prewarm), 1.0)
	var created: int = pool.get_total_count()
	Projectile.despawn_all()
	await _wait(1)
	_check("despawn_all clears every shard", Projectile.active.size(), 0)
	_check("cleared shards are back in the pool", pool.get_active_count(), 0)
	for i: int in 10:
		a.fire_at(_ORIGIN + Vector2(0, -200))
	await _wait(1)
	_check("firing again reuses shards instead of creating them", pool.get_total_count(), created)
	Projectile.despawn_all()
	for crow: ShooterEnemy in [a, b]:
		crow.set_physics_process(true)
		crow.despawn()
	await _wait(2)


func _test_pooled_reuse() -> void:
	var crow: ShooterEnemy = _spawn(Vector2(100, 0))
	crow.fire_cooldown_left = 0.0
	await _wait(3)
	_check_state("winding up before despawn", crow, &"Aim")
	crow.despawn()
	await _wait(2)
	var again: ShooterEnemy = _spawn(Vector2(100, 0))
	_check("the pool hands back the same crow", float(again == crow), 1.0)
	_check_state("a reused crow starts fresh", again, &"Reposition")
	_check("a reused crow is not tinted", float((again.get_node("Sprite") as AnimatedSprite2D).modulate == Color.WHITE), 1.0)
	_check("a reused crow waits before its first shot", float(again.fire_cooldown_left >= _CROW.first_shot_delay.x), 1.0)
	again.despawn()
	await _wait(2)


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _check_state(what: String, crow: StateEnemy, expected: StringName) -> void:
	_checks += 1
	if crow.state_machine.get_state_name() != expected:
		_failures += 1
		print("FAIL  %s: state is %s, expected %s" % [what, crow.state_machine.get_state_name(), expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i: int in max_frames:
		if condition.call():
			return
		await get_tree().physics_frame

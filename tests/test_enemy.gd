extends Node
## Regression test for the shared enemy, EnemyData, the Gutter Rat, contact
## damage and swarm separation. Run this scene (F6) and read the Output
## panel. It takes about 25 seconds because enemies really walk.
##
## The enemy numbers used here are set by the test, so editing
## gutter_rat.tres does not break it.

const _RAT: EnemyData = preload("res://data/enemies/gutter_rat.tres")
const _SWORD: MeleeWeaponData = preload("res://data/weapons/sword.tres")
const _BOW: ProjectileWeaponData = preload("res://data/weapons/bow.tres")
const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _failures: int = 0
var _checks: int = 0
var _died_count: int = 0
var _died_data: EnemyData
var _died_position: Vector2


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	_test_data_file()
	await _test_spawn_chase_and_pool()
	await _test_stop_and_contact_damage()
	await _test_separation()
	await _test_weapons_hit_enemies()
	await _test_walls()
	await _test_swarm_of_100()
	await _test_player_is_hurt()
	print("Enemy tests: %d checks, %d failed" % [_checks, _failures])


func _on_enemy_died(data: EnemyData, at: Vector2) -> void:
	_died_count += 1
	_died_data = data
	_died_position = at


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _new_rat_data() -> EnemyData:
	var data: EnemyData = _RAT.duplicate() as EnemyData
	data.max_hp = 20
	data.move_speed = 60.0
	data.contact_damage = 8.0
	data.contact_interval = 0.5
	data.body_radius = 5.0
	data.hurtbox_radius = 7.0
	data.contact_radius = 6.0
	data.separation_radius = 14.0
	data.separation_strength = 1.0
	data.stop_distance = 4.0
	return data


## A stand-in player: 1000 HP, 0.5 s of i-frames, a hurtbox on the player layer.
func _new_target(at: Vector2) -> Node2D:
	var body := Node2D.new()
	body.position = at
	var health := HealthComponent.new()
	health.name = "Health"
	health.base_max_hp = 1000
	health.invincibility_time = 0.5
	body.add_child(health)
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = PhysicsLayers.PLAYER
	hurtbox.health = health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	hurtbox.add_child(shape)
	body.add_child(hurtbox)
	add_child(body)
	return body


func _damage_taken(target: Node2D) -> float:
	var health: HealthComponent = target.get_node("Health") as HealthComponent
	return health.max_hp - health.current_hp


func _no_crit_stats() -> StatBlock:
	var config := StatConfig.new()
	config.base_crit_chance = 0.0
	var stats := StatBlock.new()
	stats.config = config
	return stats


func _min_gap(enemies: Array[Enemy]) -> float:
	var smallest: float = INF
	for i: int in enemies.size():
		for j: int in range(i + 1, enemies.size()):
			smallest = minf(smallest, enemies[i].global_position.distance_to(enemies[j].global_position))
	return smallest


func _test_data_file() -> void:
	_check("gutter_rat.tres is enemy data", float(_RAT is EnemyData), 1.0)
	var instance: Node = _RAT.scene.instantiate()
	_check("its scene is an Enemy", float(instance is Enemy), 1.0)
	instance.free()
	for direction: String in ["down", "up", "left", "right"]:
		var animation: String = "walk_" + direction
		_check("rat has " + animation, float(_RAT.sprite_frames.has_animation(animation)), 1.0)
		_check(animation + " has 4 frames", _RAT.sprite_frames.get_frame_count(animation), 4)
	_check("rat gives xp", float(_RAT.xp_reward > 0), 1.0)
	_check("rat gives gold", float(_RAT.gold_reward > 0), 1.0)


func _test_spawn_chase_and_pool() -> void:
	var data: EnemyData = _new_rat_data()
	var pool: ObjectPool = Pools.get_pool(data.scene)
	var target: Node2D = _new_target(Vector2(5000, 0))
	var start: Vector2 = Vector2(4000, 0)
	var rat: Enemy = Enemy.spawn(data, start, target)
	_check("spawn returns an enemy", float(rat != null), 1.0)
	_check("it is listed as active", Enemy.active.size(), 1)
	_check("it came from the pool", pool.get_active_count(), 1)
	_check("hp comes from the data", rat.health.current_hp, 20)
	_check("it starts at the spawn point", rat.global_position.distance_to(start), 0.0)
	var body_shape: CircleShape2D = (rat.get_node("CollisionShape") as CollisionShape2D).shape as CircleShape2D
	_check("body radius comes from the data", body_shape.radius, 5.0)
	var hitbox: HitboxComponent = rat.get_node("Hitbox") as HitboxComponent
	_check("contact damage comes from the data", hitbox.damage, 8.0)
	_check("its hurtbox is on the enemy layer", rat.hurtbox.collision_layer, PhysicsLayers.ENEMY)

	await _wait(60)
	var moved: Vector2 = rat.global_position - start
	_check("walks at its speed towards the target", moved.x, 60.0, 4.0)
	_check("walks in a straight line", moved.y, 0.0, 0.5)
	var sprite: AnimatedSprite2D = rat.get_node("Sprite") as AnimatedSprite2D
	_check("plays the walk animation for its direction", float(sprite.animation == &"walk_right"), 1.0)
	_check("sprite scale comes from the data", sprite.scale.x, data.visual_scale)

	_check("a hit lands", rat.hurtbox.take_hit(5.0), 5)
	_check("hp after the hit", rat.health.current_hp, 15)
	_check("it flashes when hit", float(sprite.material != null), 1.0)

	var kills_before: int = RunState.kills
	var death_position: Vector2 = rat.global_position
	rat.hurtbox.take_hit(100.0)
	_check("enemy_died is emitted once", _died_count, 1)
	_check("enemy_died carries the data", float(_died_data == data), 1.0)
	_check("enemy_died carries the position", _died_position.distance_to(death_position), 0.0)
	_check("RunState counts the kill", RunState.kills - kills_before, 1)
	_check("a dead enemy is no longer active", Enemy.active.size(), 0)
	await get_tree().process_frame
	_check("a dead enemy goes back to the pool", pool.get_active_count(), 0)
	_check("a pooled enemy is hidden", float(rat.visible), 0.0)

	var again: Enemy = Enemy.spawn(data, start, target)
	_check("the pooled enemy is reused", float(again == rat), 1.0)
	_check("a reused enemy has full hp", again.health.current_hp, 20)
	_check("a reused enemy is alive", float(again.health.is_alive()), 1.0)
	_check("a reused enemy is not still flashing", float(sprite.material == null), 1.0)
	again.despawn()
	_check("despawn removes the enemy", Enemy.active.size(), 0)
	_check("despawn gives no kill", _died_count, 1)
	await get_tree().process_frame

	var big_data: EnemyData = _new_rat_data()
	big_data.max_hp = 200
	big_data.body_radius = 12.0
	var big: Enemy = Enemy.spawn(big_data, start, target)
	var small: Enemy = Enemy.spawn(data, start + Vector2(0, 100), target)
	var big_shape: CircleShape2D = (big.get_node("CollisionShape") as CollisionShape2D).shape as CircleShape2D
	var small_shape: CircleShape2D = (small.get_node("CollisionShape") as CollisionShape2D).shape as CircleShape2D
	_check("a different data gives a different hp", big.health.max_hp, 200)
	_check("a different data gives a different size", big_shape.radius, 12.0)
	_check("sizes are not shared between enemies", small_shape.radius, 5.0)
	Enemy.despawn_all()
	_check("despawn_all clears the arena", Enemy.active.size(), 0)
	target.queue_free()
	await _wait(2)


func _test_stop_and_contact_damage() -> void:
	var data: EnemyData = _new_rat_data()
	var target: Node2D = _new_target(Vector2(8000, 0))
	var rat: Enemy = Enemy.spawn(data, target.position + Vector2(40, 0), target)
	await _wait(125)
	var distance: float = rat.global_position.distance_to(target.global_position)
	_check("stops next to the target", float(distance <= data.stop_distance + 1.5), 1.0)
	var damage: float = _damage_taken(target)
	# It arrives after about 0.6 s, then touches every 0.5 s: 3 or 4 hits.
	_check("touching hurts the target", float(damage >= 16.0 and damage <= 32.0), 1.0)
	_check("each touch deals the contact damage", fmod(damage, 8.0), 0.0)
	var before: float = _damage_taken(target)
	rat.despawn()
	await _wait(60)
	_check("a despawned enemy stops hurting", _damage_taken(target), before)
	target.queue_free()
	await _wait(2)


func _test_separation() -> void:
	var data: EnemyData = _new_rat_data()
	var far_target: Node2D = _new_target(Vector2(14000, 0))
	var pack: Array[Enemy] = []
	for i: int in 12:
		pack.append(Enemy.spawn(data, Vector2(12000, 0), far_target))
	_check("12 enemies start stacked on one point", _min_gap(pack), 0.0)
	await _wait(90)
	var gap: float = _min_gap(pack)
	print("INFO  smallest gap in a marching pack of 12: %.1f px" % gap)
	_check("a stacked pack spreads out while marching", float(gap >= 4.0), 1.0)
	Enemy.despawn_all()
	far_target.queue_free()
	await _wait(2)

	var target: Node2D = _new_target(Vector2(16000, 0))
	pack.clear()
	for i: int in 12:
		var at: Vector2 = target.position + Vector2.from_angle(TAU * i / 12.0) * 50.0
		pack.append(Enemy.spawn(data, at, target))
	await _wait(240)
	gap = _min_gap(pack)
	print("INFO  smallest gap in 12 enemies crowding one target: %.1f px" % gap)
	_check("a crowd on one target does not stack", float(gap >= 3.0), 1.0)

	data.separation_strength = 0.0
	await _wait(120)
	_check("with separation off they do stack", float(_min_gap(pack) < 3.0), 1.0)
	Enemy.despawn_all()
	target.queue_free()
	await _wait(2)


func _test_weapons_hit_enemies() -> void:
	var data: EnemyData = _new_rat_data()
	data.max_hp = 500
	data.move_speed = 0.0
	var origin: Vector2 = Vector2(20000, 0)
	var stats: StatBlock = _no_crit_stats()

	var sword: MeleeWeapon = _SWORD.weapon_scene.instantiate() as MeleeWeapon
	sword.setup(_SWORD, stats)
	sword.position = origin
	add_child(sword)
	var near: Enemy = Enemy.spawn(data, origin + Vector2(15, 0), null)
	await _wait(3)
	sword.tick(100.0, Vector2.RIGHT, true)
	_check("the sword hurts an enemy", near.health.max_hp - near.health.current_hp, roundf(sword.get_damage()))
	near.despawn()

	var bow: ProjectileWeapon = _BOW.weapon_scene.instantiate() as ProjectileWeapon
	bow.setup(_BOW, stats)
	bow.position = origin + Vector2(0, 500)
	add_child(bow)
	var first: Enemy = Enemy.spawn(data, bow.position + Vector2(60, 0), null)
	var second: Enemy = Enemy.spawn(data, bow.position + Vector2(100, 0), null)
	await _wait(3)
	bow.tick(100.0, Vector2.RIGHT, true)
	await _wait(40)
	_check("an arrow hurts an enemy", first.health.max_hp - first.health.current_hp, roundf(bow.get_damage()))
	_check("the arrow stops at the first enemy", second.health.current_hp, second.health.max_hp)
	sword.queue_free()
	bow.queue_free()
	Enemy.despawn_all()
	await _wait(2)


func _test_walls() -> void:
	var data: EnemyData = _new_rat_data()
	var origin: Vector2 = Vector2(24000, 0)
	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	wall.position = origin + Vector2(60, 0)
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 400)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	add_child(wall)
	var target: Node2D = _new_target(origin + Vector2(200, 0))
	var rat: Enemy = Enemy.spawn(data, origin, target)
	await _wait(180)
	_check("a wall stops an enemy", float(rat.global_position.x < wall.position.x), 1.0)
	_check("the enemy walked up to the wall", rat.global_position.x, wall.position.x - 4.0 - data.body_radius, 1.0)
	Enemy.despawn_all()
	wall.queue_free()
	target.queue_free()
	await _wait(2)


func _test_swarm_of_100() -> void:
	var data: EnemyData = _new_rat_data()
	var target: Node2D = _new_target(Vector2(30000, 0))
	for i: int in 100:
		var at: Vector2 = target.position + Vector2.from_angle(i * 2.399963) * (60.0 + i * 1.5)
		Enemy.spawn(data, at, target)
	_check("100 enemies can be alive at once", Enemy.active.size(), 100)
	await _wait(30)
	var total_ms: float = 0.0
	var worst_ms: float = 0.0
	for i: int in 180:
		await get_tree().physics_frame
		var ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		total_ms += ms
		worst_ms = maxf(worst_ms, ms)
	var average_ms: float = total_ms / 180.0
	# Timing depends on the machine and on what else it is doing, so the
	# number is printed for a human to read; only a blown budget fails.
	print("INFO  100 enemies: physics frame average %.2f ms, worst %.2f ms (whole-frame budget is 16.7 ms)" % [average_ms, worst_ms])
	_check("100 enemies do not use the whole frame budget", float(average_ms < 16.7), 1.0)
	_check("all 100 survived the run", Enemy.active.size(), 100)
	var crowd: Array[Enemy] = Enemy.active.duplicate()
	print("INFO  smallest gap in the swarm of 100: %.1f px" % _min_gap(crowd))
	Enemy.despawn_all()
	target.queue_free()
	await _wait(2)


func _test_player_is_hurt() -> void:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(40000, 0)
	add_child(player)
	await _wait(2)
	# Disarm the player so the enemy survives.
	player.weapons.firing_enabled = false
	var player_hurtbox: HurtboxComponent = player.get_node("Hurtbox") as HurtboxComponent
	_check("player has a hurtbox on the player layer", player_hurtbox.collision_layer, PhysicsLayers.PLAYER)
	var data: EnemyData = _new_rat_data()
	var rat: Enemy = Enemy.spawn(data, player.global_position + Vector2(30, 0), player)
	await _wait(60)
	_check("an enemy reaches and hurts the player", float(player.health.current_hp < player.health.max_hp), 1.0)
	_check("player has i-frames after the touch", float(player.health.current_hp >= player.health.max_hp - 16.0), 1.0)
	rat.despawn()
	player.queue_free()
	await _wait(2)

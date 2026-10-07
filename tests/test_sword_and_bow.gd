extends Node
## Regression test for the Sword (melee arc), the Bow (pooled projectiles),
## the object pool and hurtboxes. Run this scene (F6) and read the Output
## panel. It takes about eight seconds because arrows really fly.
##
## The weapon numbers used here are set by the test, so editing sword.tres or
## bow.tres does not break it.

const _SWORD: MeleeWeaponData = preload("res://data/weapons/sword.tres")
const _BOW: ProjectileWeaponData = preload("res://data/weapons/bow.tres")
const _ARROW_SCENE: PackedScene = preload("res://scenes/projectiles/arrow.tscn")
const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _FOREVER: float = 100.0
const _SWORD_ORIGIN: Vector2 = Vector2(1000, 1000)
const _BOW_ORIGIN: Vector2 = Vector2(3000, 1000)

var _failures: int = 0
var _checks: int = 0
var _hit_count: int = 0
var _last_hit_was_crit: bool = false


func _ready() -> void:
	_test_data_files()
	await _test_object_pool()
	await _test_hurtbox()
	await _test_sword()
	await _test_bow()
	await _test_player_wiring()
	print("Sword and Bow tests: %d checks, %d failed" % [_checks, _failures])


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


## Stats that never crit, so damage is exact.
func _new_stats() -> StatBlock:
	var config := StatConfig.new()
	config.base_crit_chance = 0.0
	var stats := StatBlock.new()
	stats.config = config
	return stats


## A stand-in enemy: 1000 HP, a 6 px hurtbox on the enemy layer.
func _new_target(at: Vector2) -> HealthComponent:
	var body := Node2D.new()
	body.position = at
	var health := HealthComponent.new()
	health.base_max_hp = 1000
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
	return health


func _damage(target: HealthComponent) -> float:
	return target.max_hp - target.current_hp


func _swing(weapon: Weapon, direction: Vector2) -> void:
	# A huge time step forces exactly one attack, whatever the cooldown.
	weapon.tick(_FOREVER, direction, true)


func _test_data_files() -> void:
	_check("sword.tres is melee data", float(_SWORD is MeleeWeaponData), 1.0)
	_check("sword scene is a MeleeWeapon", float(_SWORD.weapon_scene.instantiate() is MeleeWeapon), 1.0)
	_check("sword scales with STR only", _SWORD.strength_weight - _SWORD.dexterity_weight, 1.0)
	_check("bow.tres is projectile data", float(_BOW is ProjectileWeaponData), 1.0)
	_check("bow scene is a ProjectileWeapon", float(_BOW.weapon_scene.instantiate() is ProjectileWeapon), 1.0)
	_check("bow scales with DEX only", _BOW.dexterity_weight - _BOW.strength_weight, 1.0)
	_check("bow projectile is a Projectile", float(_BOW.projectile_scene.instantiate() is Projectile), 1.0)
	_check("weapons hit the enemy layer", _SWORD.hit_mask, PhysicsLayers.ENEMY)


func _test_object_pool() -> void:
	var pool := ObjectPool.new()
	pool.scene = _ARROW_SCENE
	pool.initial_size = 1
	pool.max_size = 2
	add_child(pool)
	_check("prewarm creates instances", pool.get_total_count(), 1)
	_check("prewarmed instances are not in use", pool.get_active_count(), 0)
	var first: Node2D = pool.acquire() as Node2D
	_check("acquire hands out an instance", float(first != null), 1.0)
	_check("acquired instance is visible", float(first.visible), 1.0)
	_check("acquired instance is enabled", float(first.process_mode == Node.PROCESS_MODE_INHERIT), 1.0)
	var second: Node = pool.acquire()
	_check("pool grows when it has to", pool.get_total_count(), 2)
	_check("pool refuses past max_size", float(pool.acquire() == null), 1.0)
	pool.release(first)
	pool.release(first)
	await get_tree().process_frame
	_check("release frees a place", pool.get_active_count(), 1)
	_check("released instance is hidden", float(first.visible), 0.0)
	_check("released instance is disabled", float(first.process_mode == Node.PROCESS_MODE_DISABLED), 1.0)
	_check("released instance is reused", float(pool.acquire() == first), 1.0)
	_check("double release did not duplicate it", float(pool.acquire() == null), 1.0)
	_check("pool never exceeded max_size", pool.get_total_count(), 2)
	pool.release(second)
	var stray := Node.new()
	add_child(stray)
	Pools.release(stray)
	_check("Pools.release frees a node that has no pool", float(stray.is_queued_for_deletion()), 1.0)
	pool.queue_free()
	await get_tree().process_frame


func _test_hurtbox() -> void:
	var target: HealthComponent = _new_target(Vector2(-2000, -2000))
	var hurtbox: HurtboxComponent = target.get_parent().get_child(1) as HurtboxComponent
	hurtbox.hit_taken.connect(func(_amount: int, is_crit: bool) -> void:
		_hit_count += 1
		_last_hit_was_crit = is_crit
	)
	_check("hurtbox detects nothing itself", float(hurtbox.monitoring), 0.0)
	_check("take_hit returns damage dealt", hurtbox.take_hit(25.0, true), 25)
	_check("take_hit reaches the health component", _damage(target), 25)
	_check("hit_taken emitted", _hit_count, 1)
	_check("hit_taken carries the crit flag", float(_last_hit_was_crit), 1.0)
	target.invincibility_time = 1.0
	hurtbox.take_hit(10.0)
	_check("an ignored hit returns 0", hurtbox.take_hit(10.0), 0)
	_check("an ignored hit emits nothing", _hit_count, 2)
	target.get_parent().queue_free()
	await _wait(1)


func _test_sword() -> void:
	var data: MeleeWeaponData = _SWORD.duplicate() as MeleeWeaponData
	data.base_damage = 10.0
	data.base_range = 30.0
	data.arc_degrees = 120.0
	data.always_hit_radius = 6.0
	data.max_targets = 0
	var stats: StatBlock = _new_stats()
	var sword: MeleeWeapon = data.weapon_scene.instantiate() as MeleeWeapon
	sword.setup(data, stats)
	sword.position = _SWORD_ORIGIN
	add_child(sword)

	var front: HealthComponent = _new_target(_SWORD_ORIGIN + Vector2(20, 0))
	var behind: HealthComponent = _new_target(_SWORD_ORIGIN + Vector2(-20, 0))
	var far: HealthComponent = _new_target(_SWORD_ORIGIN + Vector2(60, 0))
	var inside_arc: HealthComponent = _new_target(_SWORD_ORIGIN + Vector2.from_angle(deg_to_rad(50.0)) * 20.0)
	var outside_arc: HealthComponent = _new_target(_SWORD_ORIGIN + Vector2.from_angle(deg_to_rad(-75.0)) * 20.0)
	var on_top: HealthComponent = _new_target(_SWORD_ORIGIN + Vector2(-4, 0))
	await _wait(3)

	_swing(sword, Vector2.RIGHT)
	_check("sword hits in front", _damage(front), 10)
	_check("sword hits inside the arc (50 deg)", _damage(inside_arc), 10)
	_check("sword misses outside the arc (75 deg)", _damage(outside_arc), 0)
	_check("sword misses behind", _damage(behind), 0)
	_check("sword misses out of range", _damage(far), 0)
	_check("sword hits an enemy standing on the player", _damage(on_top), 10)

	_swing(sword, Vector2.LEFT)
	_check("sword follows the aim", _damage(behind), 10)
	_check("the other side is now missed", _damage(front), 10)

	data.base_range = 60.0
	_swing(sword, Vector2.RIGHT)
	_check("range comes from the data", _damage(far), 10)
	data.base_range = 30.0
	stats.dexterity = 50
	_check("DEX widens the swing", sword.get_range(), 45.0)
	stats.dexterity = 0

	stats.strength = 50
	var before: float = _damage(front)
	_swing(sword, Vector2.RIGHT)
	_check("STR 50 doubles sword damage", _damage(front) - before, 20)
	stats.strength = 0

	data.arc_degrees = 360.0
	before = _damage(behind) + _damage(outside_arc)
	_swing(sword, Vector2.RIGHT)
	_check("a 360 degree arc hits all around", _damage(behind) + _damage(outside_arc) - before, 20)

	data.max_targets = 1
	var all: Array[HealthComponent] = [front, behind, far, inside_arc, outside_arc, on_top]
	before = 0.0
	for target: HealthComponent in all:
		before += _damage(target)
	_swing(sword, Vector2.RIGHT)
	var after: float = 0.0
	for target: HealthComponent in all:
		after += _damage(target)
	_check("max_targets limits one swing", after - before, 10)

	sword.queue_free()
	for target: HealthComponent in all:
		target.get_parent().queue_free()
	await _wait(1)


func _test_bow() -> void:
	var data: ProjectileWeaponData = _BOW.duplicate() as ProjectileWeaponData
	data.base_damage = 10.0
	data.base_range = 160.0
	data.projectile_speed = 300.0
	data.pierce = 0
	data.projectiles_per_shot = 1
	data.spread_degrees = 0.0
	data.pool_prewarm = 8
	var stats: StatBlock = _new_stats()
	var bow: ProjectileWeapon = data.weapon_scene.instantiate() as ProjectileWeapon
	bow.setup(data, stats)
	bow.position = _BOW_ORIGIN
	add_child(bow)
	await _wait(2)
	var pool: ObjectPool = Pools.get_pool(data.projectile_scene)
	_check("arrows are created before combat", pool.get_total_count(), 8)
	_check("no arrow in flight yet", pool.get_active_count(), 0)

	var near: HealthComponent = _new_target(_BOW_ORIGIN + Vector2(80, 0))
	var second: HealthComponent = _new_target(_BOW_ORIGIN + Vector2(120, 0))
	var out_of_range: HealthComponent = _new_target(_BOW_ORIGIN + Vector2(300, 0))
	await _wait(3)

	_swing(bow, Vector2.RIGHT)
	_check("one shot is one arrow", pool.get_active_count(), 1)
	await _wait(45)
	_check("arrow hits the first enemy", _damage(near), 10)
	_check("arrow stops at the first enemy", _damage(second), 0)
	_check("arrow went back to the pool", pool.get_active_count(), 0)

	data.pierce = 1
	_swing(bow, Vector2.RIGHT)
	await _wait(45)
	_check("pierce 1: first enemy hit once", _damage(near), 20)
	_check("pierce 1: second enemy hit too", _damage(second), 10)
	_check("pierced arrow went back to the pool", pool.get_active_count(), 0)
	data.pierce = 0

	stats.dexterity = 50
	_check("DEX 50 doubles bow damage", bow.get_damage(), 20.0)
	_check("DEX 50 extends arrow range", bow.get_range(), 240.0)
	stats.dexterity = 0

	_swing(bow, Vector2.UP)
	await _wait(20)
	_check("arrow still flying inside its range", pool.get_active_count(), 1)
	await _wait(25)
	_check("arrow expires at its range", pool.get_active_count(), 0)
	_check("nothing beyond range was hit", _damage(out_of_range), 0)

	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	wall.position = _BOW_ORIGIN + Vector2(0, 50)
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 8)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	add_child(wall)
	var behind_wall: HealthComponent = _new_target(_BOW_ORIGIN + Vector2(0, 90))
	await _wait(3)
	_swing(bow, Vector2.DOWN)
	await _wait(30)
	_check("a wall stops the arrow", _damage(behind_wall), 0)
	_check("the stopped arrow went back to the pool", pool.get_active_count(), 0)

	data.projectiles_per_shot = 3
	data.spread_degrees = 30.0
	_swing(bow, Vector2.LEFT)
	_check("multi-shot fires three arrows", pool.get_active_count(), 3)
	await _wait(45)
	data.projectiles_per_shot = 1

	# Three seconds of sustained fire, five shots a second.
	data.base_cooldown = 0.2
	for i: int in 180:
		bow.tick(1.0 / 60.0, Vector2.LEFT, true)
		await get_tree().physics_frame
	_check("sustained fire never grew the pool", pool.get_total_count(), 8)
	await _wait(45)
	_check("all arrows returned after firing stopped", pool.get_active_count(), 0)

	bow.queue_free()
	wall.queue_free()
	for target: HealthComponent in [near, second, out_of_range, behind_wall]:
		target.get_parent().queue_free()
	await _wait(1)


func _test_player_wiring() -> void:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await _wait(2)
	_check("player starts with a melee weapon in slot 0", float(player.weapons.get_weapon(0) is MeleeWeapon), 1.0)
	_check("player starts with a projectile weapon in slot 1", float(player.weapons.get_weapon(1) is ProjectileWeapon), 1.0)
	# Take the mouse out of the test: aim by hand.
	player.set_process(false)
	var target: HealthComponent = _new_target(player.global_position + Vector2(18, 0))
	player.aim_at(player.global_position + Vector2(18, 0))
	await _wait(60)
	var sword_damage: float = player.weapons.get_weapon(0).get_damage()
	var bow_damage: float = player.weapons.get_weapon(1).get_damage()
	_check("player's weapons hurt an enemy by themselves", float(_damage(target) >= sword_damage + bow_damage), 1.0)
	player.queue_free()
	target.get_parent().queue_free()

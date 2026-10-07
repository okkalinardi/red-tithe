extends Node
## Regression test for drops: the XP curve, levels and points, pickups, the
## collector, the drop spawner and the player wiring. Run this scene (F6) and
## read the Output panel. It takes about ten seconds because pickups really fly.
##
## The curve and pickup numbers used here are set by the test, so editing the
## data files does not break it.

const _XP_GEM: PickupData = preload("res://data/pickups/xp_gem.tres")
const _GOLD: PickupData = preload("res://data/pickups/gold.tres")
const _RAT: EnemyData = preload("res://data/enemies/gutter_rat.tres")
const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")

var _failures: int = 0
var _checks: int = 0
var _collected: Array[String] = []
var _level_ups: Array[int] = []
var _bus_level_ups: int = 0
var _xp_changes: int = 0
var _point_changes: int = 0


func _ready() -> void:
	Events.player_leveled_up.connect(func(_level: int) -> void: _bus_level_ups += 1)
	_test_data_files()
	_test_xp_curve()
	_test_progression()
	await _test_pickup_and_collector()
	await _test_drop_spawner()
	await _test_player_wiring()
	print("Drops tests: %d checks, %d failed" % [_checks, _failures])


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _new_config() -> ProgressionConfig:
	var config := ProgressionConfig.new()
	config.first_level_xp = 10
	config.xp_increase_per_level = 9
	config.xp_growth = 1.0
	config.max_level = 0
	config.stat_points_per_level = 5
	config.skill_points_per_level = 1
	return config


func _new_progression(config: ProgressionConfig, stats: StatBlock) -> ProgressionComponent:
	var progression := ProgressionComponent.new()
	progression.config = config
	add_child(progression)
	progression.setup(stats)
	_level_ups.clear()
	_xp_changes = 0
	_point_changes = 0
	progression.leveled_up.connect(func(level: int) -> void: _level_ups.append(level))
	progression.xp_changed.connect(func(_xp: int, _required: int) -> void: _xp_changes += 1)
	progression.points_changed.connect(func(_stat: int, _skill: int) -> void: _point_changes += 1)
	return progression


func _new_collector(at: Vector2, pickup_range: float = 40.0) -> PickupCollector:
	var collector := PickupCollector.new()
	collector.pickup_range = pickup_range
	collector.position = at
	add_child(collector)
	_collected.clear()
	collector.collected.connect(func(data: PickupData, amount: int) -> void: _collected.append("%s:%d" % [data.id, amount]))
	return collector


func _test_data_files() -> void:
	_check("xp_gem.tres gives XP", _XP_GEM.kind, PickupData.Kind.XP)
	_check("gold.tres gives gold", _GOLD.kind, PickupData.Kind.GOLD)
	var instance: Node = _XP_GEM.scene.instantiate()
	_check("the pickup scene is a Pickup", float(instance is Pickup), 1.0)
	_check("a pickup is on the pickup layer", (instance as Area2D).collision_layer, PhysicsLayers.PICKUP)
	_check("a pickup can be detected", float((instance as Area2D).monitorable), 1.0)
	instance.free()
	_check("a pickup flies faster than the player can run", float(_XP_GEM.fly_max_speed > 117.0), 1.0)
	var config: ProgressionConfig = load("res://data/progression.tres") as ProgressionConfig
	_check("progression.tres is a progression config", float(config != null), 1.0)
	_check("a level gives 5 stat points", config.stat_points_per_level, 5)
	_check("a level gives 1 skill point", config.skill_points_per_level, 1)
	var main: Node = _MAIN_SCENE.instantiate()
	var spawner: DropSpawner = main.get_node_or_null("DropSpawner") as DropSpawner
	_check("the main scene has a drop spawner", float(spawner != null), 1.0)
	_check("it drops XP gems", float(spawner.xp_pickup == _XP_GEM), 1.0)
	_check("it drops gold", float(spawner.gold_pickup == _GOLD), 1.0)
	main.free()


func _test_xp_curve() -> void:
	var config: ProgressionConfig = _new_config()
	_check("level 1 to 2 costs first_level_xp", config.xp_required(1), 10)
	_check("each level costs more", config.xp_required(2), 19)
	_check("level 11 to 12", config.xp_required(11), 100)
	_check("total XP for level 12", config.total_xp_for_level(12), 605)
	_check("total XP for level 1 is nothing", config.total_xp_for_level(1), 0)
	config.xp_growth = 1.1
	_check("growth multiplies the line", config.xp_required(3), roundi(28 * 1.21))
	config.first_level_xp = 0
	config.xp_increase_per_level = 0
	_check("a level never costs less than 1 XP", config.xp_required(4), 1)


func _test_progression() -> void:
	var stats := StatBlock.new()
	stats.config = StatConfig.new()
	var p: ProgressionComponent = _new_progression(_new_config(), stats)
	_check("starts at level 1", p.level, 1)
	_check("starts with no XP", p.xp, 0)
	_check("starts with no points", p.stat_points + p.skill_points, 0)
	_check("needs 10 XP for level 2", p.get_xp_required(), 10)

	p.add_xp(4)
	_check("XP adds up", p.xp, 4)
	_check("no level yet", p.level, 1)
	_check("xp_changed emitted", _xp_changes, 1)
	var bus_before: int = _bus_level_ups
	p.add_xp(8)
	_check("levels up at the requirement", p.level, 2)
	_check("extra XP carries over", p.xp, 2)
	_check("level 2 gives 5 stat points", p.stat_points, 5)
	_check("level 2 gives 1 skill point", p.skill_points, 1)
	_check("leveled_up carries the level", float(str(_level_ups) == "[2]"), 1.0)
	_check("Events.player_leveled_up emitted", _bus_level_ups - bus_before, 1)
	_check("now needs 19 XP", p.get_xp_required(), 19)

	# 17 to finish level 2, 28 for level 3, 37 for level 4, and 3 left over.
	p.add_xp(17 + 28 + 37 + 3)
	_check("one big gain can give several levels", p.level, 5)
	_check("the remainder carries over", p.xp, 3)
	_check("points add up over levels", p.stat_points, 20)
	_check("skill points add up over levels", p.skill_points, 4)
	_check("leveled_up emitted once per level", float(str(_level_ups) == "[2, 3, 4, 5]"), 1.0)
	p.add_xp(0)
	p.add_xp(-5)
	_check("zero and negative XP do nothing", p.xp, 3)

	_check("a stat point can be spent", float(p.spend_stat_point(StatBlock.Stat.VIT)), 1.0)
	_check("it raises the stat", stats.vitality, 1)
	_check("it raises the derived stat", stats.max_hp, 106)
	_check("it is used up", p.stat_points, 19)
	for i: int in 19:
		p.spend_stat_point(StatBlock.Stat.STR)
	_check("all stat points can be spent", p.stat_points, 0)
	_check("they all landed", stats.strength, 19)
	_check("no point, no spend", float(p.spend_stat_point(StatBlock.Stat.STR)), 0.0)
	_check("a refused spend changes nothing", stats.strength, 19)
	_check("a skill point can be spent", float(p.spend_skill_point()), 1.0)
	_check("it is used up", p.skill_points, 3)
	for i: int in 3:
		p.spend_skill_point()
	_check("no skill point, no spend", float(p.spend_skill_point()), 0.0)

	p.reset()
	_check("reset goes back to level 1", p.level, 1)
	_check("reset clears XP", p.xp, 0)
	_check("reset does not undo spent stats", stats.strength, 19)

	var capped_config: ProgressionConfig = _new_config()
	capped_config.max_level = 3
	capped_config.starting_stat_points = 2
	capped_config.starting_skill_points = 1
	var capped: ProgressionComponent = _new_progression(capped_config, stats)
	_check("starting stat points come from the config", capped.stat_points, 2)
	_check("starting skill points come from the config", capped.skill_points, 1)
	capped.add_xp(10000)
	_check("levels stop at max_level", capped.level, 3)
	_check("no XP is kept at max level", capped.xp, 0)
	_check("points stop with the levels", capped.stat_points, 12)
	p.queue_free()
	capped.queue_free()


func _test_pickup_and_collector() -> void:
	var data: PickupData = _XP_GEM.duplicate() as PickupData
	data.fly_start_speed = 60.0
	data.fly_acceleration = 700.0
	data.fly_max_speed = 320.0
	data.collect_distance = 6.0
	var pool: ObjectPool = Pools.get_pool(data.scene)
	var origin: Vector2 = Vector2(3000, 0)
	var collector: PickupCollector = _new_collector(origin, 40.0)
	await _wait(2)

	var far: Pickup = Pickup.spawn(data, origin + Vector2(100, 0), 7)
	_check("spawn returns a pickup", float(far != null), 1.0)
	_check("it is listed as active", Pickup.active.size(), 1)
	_check("it carries its amount", far.amount, 7)
	await _wait(30)
	_check("out of range, it stays where it is", far.global_position.distance_to(origin + Vector2(100, 0)), 0.0)
	_check("out of range, it is not flying", float(far.is_flying()), 0.0)
	_check("a pickup on the ground does no per-frame work", float(far.is_physics_processing()), 0.0)

	collector.position = origin + Vector2(65, 0)
	await _wait(4)
	_check("in range, it starts flying", float(far.is_flying()), 1.0)
	var frames: int = 4
	while _collected.is_empty() and frames < 200:
		await get_tree().physics_frame
		frames += 1
	_check("it reaches the collector quickly", float(frames < 40), 1.0)
	_check("collected reports the kind and amount", float(_collected.size() == 1 and _collected[0] == "xp_gem:7"), 1.0)
	_check("a collected pickup is no longer active", Pickup.active.size(), 0)
	await get_tree().process_frame
	_check("it went back to the pool", pool.get_active_count(), 0)

	# A pickup chases a collector that runs away at the player's top speed.
	var chaser: Pickup = Pickup.spawn(data, collector.position + Vector2(30, 0), 1)
	_collected.clear()
	frames = 0
	while _collected.is_empty() and frames < 300:
		collector.position.x -= 117.0 / 60.0
		await get_tree().physics_frame
		frames += 1
	_check("it catches a collector running at full speed", float(frames < 60), 1.0)
	_check("the pooled pickup was reused", float(chaser == far), 1.0)

	# attract_all pulls in everything, whatever the distance.
	_collected.clear()
	for i: int in 5:
		Pickup.spawn(data, collector.position + Vector2(200 + i * 40, 60), 2)
	await _wait(10)
	_check("far pickups wait on the ground", Pickup.active.size(), 5)
	collector.attract_all()
	await _wait(120)
	_check("attract_all collects every pickup", _collected.size(), 5)
	_check("nothing is left on the ground", Pickup.active.size(), 0)

	# A disabled collector collects nothing and drops what was on its way.
	var dropped: Pickup = Pickup.spawn(data, collector.position + Vector2(300, 0), 1)
	collector.attract_all()
	await _wait(3)
	_collected.clear()
	collector.disable()
	await _wait(60)
	_check("a disabled collector collects nothing", _collected.size(), 0)
	_check("a pickup on its way drops back to the ground", float(dropped.is_flying()), 0.0)
	Pickup.spawn(data, collector.position + Vector2(10, 0), 1)
	await _wait(30)
	_check("a disabled collector ignores pickups in range", _collected.size(), 0)
	Pickup.despawn_all()
	_check("despawn_all clears the ground", Pickup.active.size(), 0)
	collector.queue_free()
	await _wait(2)


func _test_drop_spawner() -> void:
	var origin: Vector2 = Vector2(8000, 0)
	var collector: PickupCollector = _new_collector(origin + Vector2(500, 0), 40.0)
	var spawner := DropSpawner.new()
	spawner.xp_pickup = _XP_GEM
	spawner.gold_pickup = _GOLD
	spawner.scatter_radius = 8.0
	spawner.rng.seed = 5
	add_child(spawner)
	spawner.setup(collector)
	await _wait(2)
	_check("pickups are created before combat", float(Pools.get_pool(_XP_GEM.scene).get_total_count() >= spawner.pool_prewarm), 1.0)

	var enemy: EnemyData = _RAT.duplicate() as EnemyData
	enemy.xp_reward = 3
	enemy.gold_reward = 2
	Events.enemy_died.emit(enemy, origin)
	_check("a kill drops two pickups", Pickup.active.size(), 2)
	var xp_amount: int = 0
	var gold_amount: int = 0
	var furthest: float = 0.0
	for pickup: Pickup in Pickup.active:
		furthest = maxf(furthest, pickup.global_position.distance_to(origin))
		if pickup.data == _XP_GEM:
			xp_amount += pickup.amount
		elif pickup.data == _GOLD:
			gold_amount += pickup.amount
	_check("the XP gem is worth the enemy's XP", xp_amount, 3)
	_check("the gold is worth the enemy's gold", gold_amount, 2)
	_check("drops land next to where the enemy died", float(furthest <= 8.001), 1.0)

	enemy.xp_reward = 0
	Events.enemy_died.emit(enemy, origin)
	_check("an enemy worth no XP drops no gem", Pickup.active.size(), 3)

	await _wait(10)
	_check("drops out of range wait on the ground", _collected.size(), 0)
	Events.wave_completed.emit(1)
	await _wait(150)
	_check("when the wave ends, leftovers fly to the collector", _collected.size(), 3)
	_check("the ground is clear afterwards", Pickup.active.size(), 0)

	spawner.max_on_ground = 4
	enemy.xp_reward = 3
	for i: int in 6:
		Events.enemy_died.emit(enemy, origin)
	_check("the ground limit is kept", Pickup.active.size(), 4)
	xp_amount = 0
	gold_amount = 0
	for pickup: Pickup in Pickup.active:
		if pickup.data == _XP_GEM:
			xp_amount += pickup.amount
		else:
			gold_amount += pickup.amount
	_check("no XP is lost at the limit", xp_amount, 18)
	_check("no gold is lost at the limit", gold_amount, 12)

	spawner.collect_all_on_wave_end = false
	Events.wave_completed.emit(2)
	await _wait(30)
	_check("auto-collect can be turned off", Pickup.active.size(), 4)
	Pickup.despawn_all()
	spawner.queue_free()
	collector.queue_free()
	await _wait(2)


func _test_player_wiring() -> void:
	var spawner := DropSpawner.new()
	spawner.xp_pickup = _XP_GEM
	spawner.gold_pickup = _GOLD
	add_child(spawner)
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(12000, 0)
	add_child(player)
	spawner.setup(player.collector)
	await _wait(2)
	player.weapons.firing_enabled = false
	_check("player starts at level 1", player.progression.level, 1)
	_check("player collector looks for pickups", player.collector.collision_mask, PhysicsLayers.PICKUP)

	var gold_before: int = RunState.gold
	var rat: Enemy = Enemy.spawn(_RAT, player.position + Vector2(25, 0), null)
	await _wait(2)
	rat.hurtbox.take_hit(9999.0)
	await _wait(60)
	_check("killing an enemy near the player gives its XP", player.progression.xp, _RAT.xp_reward)
	_check("and its gold", RunState.gold - gold_before, _RAT.gold_reward)
	_check("the drops were picked up", Pickup.active.size(), 0)

	Pickup.spawn(_XP_GEM, player.position + Vector2(20, 0), player.progression.get_xp_required())
	await _wait(60)
	_check("enough XP levels the player up", player.progression.level, 2)
	_check("the level gives stat points", player.progression.stat_points, 5)
	_check("the level gives a skill point", player.progression.skill_points, 1)
	player.progression.spend_stat_point(StatBlock.Stat.VIT)
	_check("a spent point reaches the player's stats", player.stats.vitality, 1)
	_check("and the player's health", player.health.max_hp, 106)

	player.health.take_damage(99999.0)
	await _wait(3)
	Pickup.spawn(_XP_GEM, player.position + Vector2(10, 0), 50)
	await _wait(45)
	_check("a dead player picks nothing up", Pickup.active.size(), 1)
	Pickup.despawn_all()
	Enemy.despawn_all()
	player.queue_free()
	spawner.queue_free()
	await _wait(2)

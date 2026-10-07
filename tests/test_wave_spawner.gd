extends Node
## Regression test for WaveData, the wave spawner and the ten wave files.
## Run this scene (F6) and read the Output panel. It takes about 20 seconds
## because waves really run on their timers.
##
## The waves used here are built by the test, so editing the wave files does
## not break it (the files themselves are only checked for sanity).

const _RAT: EnemyData = preload("res://data/enemies/gutter_rat.tres")
const _STRAY: EnemyData = preload("res://data/enemies/stray.tres")
const _MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const _ARENA: Rect2i = Rect2i(0, 0, 960, 544)
const _SCREEN: Vector2 = Vector2(480, 270)

var _failures: int = 0
var _checks: int = 0
var _target: Node2D
var _started: Array[int] = []
var _ended: Array[int] = []
var _all_done_count: int = 0
var _spawn_points: Array[Vector2] = []
var _spawned: Array[Enemy] = []
var _bus_started: int = 0
var _bus_completed: int = 0
var _bus_boss_defeated: int = 0


func _ready() -> void:
	Events.wave_started.connect(func(_number: int) -> void: _bus_started += 1)
	Events.wave_completed.connect(func(_number: int) -> void: _bus_completed += 1)
	Events.boss_defeated.connect(func() -> void: _bus_boss_defeated += 1)
	_target = Node2D.new()
	_target.position = Vector2(_ARENA.get_center())
	var camera := Camera2D.new()
	_target.add_child(camera)
	add_child(_target)
	await _wait(2)

	_test_wave_files()
	_test_pick_enemy()
	await _test_prewarm()
	await _test_timer_and_signals()
	await _test_spawn_positions()
	await _test_alive_cap()
	await _test_scaling()
	await _test_wave_sequence()
	await _test_boss_wave()
	await _test_stop_and_player_death()
	await _test_main_scene()
	print("Wave spawner tests: %d checks, %d failed" % [_checks, _failures])


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _new_wave(duration: float, interval: float, batch: int, enemies: Array[EnemyData] = []) -> WaveData:
	if enemies.is_empty():
		enemies = [_RAT]
	var wave := WaveData.new()
	wave.duration = duration
	wave.spawn_interval = interval
	wave.batch_size = batch
	for enemy: EnemyData in enemies:
		var entry := WaveSpawnEntry.new()
		entry.enemy = enemy
		wave.entries.append(entry)
	return wave


func _new_spawner(waves: Array[WaveData], cap: int = 100) -> WaveSpawner:
	var spawner := WaveSpawner.new()
	spawner.waves = waves
	spawner.max_alive = cap
	spawner.rng.seed = 2026
	add_child(spawner)
	spawner.setup(_target, _ARENA)
	_started.clear()
	_ended.clear()
	_spawn_points.clear()
	_spawned.clear()
	_all_done_count = 0
	spawner.wave_started.connect(func(number: int) -> void: _started.append(number))
	spawner.wave_ended.connect(func(number: int) -> void: _ended.append(number))
	spawner.all_waves_completed.connect(func() -> void: _all_done_count += 1)
	spawner.enemy_spawned.connect(func(enemy: Enemy) -> void:
		_spawned.append(enemy)
		_spawn_points.append(enemy.global_position)
	)
	return spawner


func _remove(spawner: WaveSpawner) -> void:
	spawner.stop()
	spawner.queue_free()
	Enemy.despawn_all()
	await _wait(2)


func _view_rect() -> Rect2:
	return Rect2(_target.global_position - _SCREEN * 0.5, _SCREEN)


func _test_wave_files() -> void:
	var previous_hp: float = 0.0
	var previous_interval: float = INF
	for number: int in range(1, 11):
		var wave: WaveData = load("res://data/waves/wave_%02d.tres" % number) as WaveData
		_check("wave %d file is wave data" % number, float(wave != null), 1.0)
		if wave == null:
			continue
		_check("wave %d has enemies" % number, float(wave.entries.size() >= 1), 1.0)
		_check("wave %d can pick an enemy" % number, float(wave.pick_enemy(RandomNumberGenerator.new()) != null), 1.0)
		_check("wave %d is no easier than the one before" % number, float(wave.hp_multiplier >= previous_hp), 1.0)
		_check("wave %d spawns no slower than the one before" % number, float(wave.spawn_interval <= previous_interval), 1.0)
		previous_hp = wave.hp_multiplier
		previous_interval = wave.spawn_interval
		if number == 1:
			_check("wave 1 is rats only", float(wave.entries.size() == 1 and wave.entries[0].enemy == _RAT), 1.0)
		if number == 2:
			var has_stray: bool = false
			for entry: WaveSpawnEntry in wave.entries:
				has_stray = has_stray or entry.enemy == _STRAY
			_check("the Stray first appears in wave 2", float(has_stray), 1.0)
	var main: Node = _MAIN_SCENE.instantiate()
	var spawner: WaveSpawner = main.get_node_or_null("WaveSpawner") as WaveSpawner
	_check("the main scene has a wave spawner", float(spawner != null), 1.0)
	_check("it is given ten waves", spawner.waves.size(), 10)
	_check("the temporary spawner is gone", float(main.get_node_or_null("DebugEnemySpawner") == null), 1.0)
	main.free()


func _test_pick_enemy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var wave: WaveData = _new_wave(30.0, 1.0, 1, [_RAT, _STRAY])
	wave.entries[0].weight = 3.0
	wave.entries[1].weight = 1.0
	var rats: int = 0
	for i: int in 4000:
		if wave.pick_enemy(rng) == _RAT:
			rats += 1
	_check("weight 3 against 1 is picked 75% of the time", rats / 4000.0, 0.75, 0.03)
	wave.entries[0].weight = 0.0
	var strays: int = 0
	for i: int in 200:
		if wave.pick_enemy(rng) == _STRAY:
			strays += 1
	_check("weight 0 is never picked", strays, 200)
	var empty := WaveData.new()
	_check("an empty wave picks nothing", float(empty.pick_enemy(rng) == null), 1.0)
	_check("a wave with a duration is timed", float(wave.is_timed()), 1.0)
	empty.duration = 0.0
	_check("a wave with duration 0 is not timed", float(empty.is_timed()), 0.0)


func _test_prewarm() -> void:
	var pool: ObjectPool = Pools.get_pool(_RAT.scene)
	_check("no enemy exists before setup", pool.get_total_count(), 0)
	var spawner: WaveSpawner = _new_spawner([_new_wave(30.0, 1.0, 2)], 40)
	await _wait(2)
	_check("setup creates the enemies ahead of time", pool.get_total_count(), 40)
	_check("prewarmed enemies are not in the arena", Enemy.active.size(), 0)
	await _remove(spawner)


func _test_timer_and_signals() -> void:
	var spawner: WaveSpawner = _new_spawner([_new_wave(2.0, 0.25, 2)])
	_check("no wave before start", float(spawner.is_wave_active()), 0.0)
	_check("wave number is 0 before start", spawner.current_wave_number, 0)
	var bus_started_before: int = _bus_started
	var bus_completed_before: int = _bus_completed
	_check("start_next_wave starts wave 1", float(spawner.start_next_wave()), 1.0)
	_check("wave_started carries the number", float(str(_started) == "[1]"), 1.0)
	_check("Events.wave_started is emitted", _bus_started - bus_started_before, 1)
	_check("RunState knows the wave", RunState.wave, 1)
	_check("the wave is running", float(spawner.is_wave_active()), 1.0)
	_check("the timer starts at the duration", spawner.get_time_left(), 2.0, 0.02)
	await _wait(60)
	_check("the timer counts down", spawner.get_time_left(), 1.0, 0.05)
	_check("enemies are spawning", float(_spawned.size() >= 6), 1.0)
	_check("spawned enemies chase the target", float(_spawned[0].target == _target), 1.0)
	var frames: int = 60
	while spawner.is_wave_active() and frames < 400:
		await get_tree().physics_frame
		frames += 1
	_check("the wave ends when the timer runs out", frames, 120, 2.0)
	_check("wave_ended carries the number", float(str(_ended) == "[1]"), 1.0)
	_check("Events.wave_completed is emitted", _bus_completed - bus_completed_before, 1)
	_check("the arena is cleared when the wave ends", Enemy.active.size(), 0)
	_check("the timer reads 0 after the wave", spawner.get_time_left(), 0.0)
	var spawned_so_far: int = _spawned.size()
	await _wait(40)
	_check("nothing spawns between waves", _spawned.size(), spawned_so_far)
	await _remove(spawner)


func _test_spawn_positions() -> void:
	var spawner: WaveSpawner = _new_spawner([_new_wave(30.0, 0.05, 8)])
	var inside: Rect2 = Rect2(_ARENA).grow(-spawner.wall_margin + 0.01)
	spawner.start_wave(1)
	await _wait(45)
	spawner.stop()
	var view: Rect2 = _view_rect()
	var in_arena: int = 0
	var off_screen: int = 0
	var in_band: int = 0
	var band: Rect2 = view.grow(spawner.view_margin + spawner.spawn_band + 0.01)
	for point: Vector2 in _spawn_points:
		in_arena += int(inside.has_point(point))
		off_screen += int(not view.grow(spawner.view_margin - 0.01).has_point(point))
		in_band += int(band.has_point(point))
	var total: int = _spawn_points.size()
	_check("many enemies were spawned", float(total >= 90), 1.0)
	_check("every spawn is inside the arena", in_arena, total)
	_check("every spawn is outside the camera view", off_screen, total)
	_check("with room to spare, every spawn is just beyond the screen edge", in_band, total)
	Enemy.despawn_all()

	# Player in the top-left corner: most of the band is outside the arena.
	_target.position = Vector2(30, 30)
	await _wait(3)
	_spawn_points.clear()
	spawner.start_wave(1)
	await _wait(45)
	spawner.stop()
	view = _view_rect()
	in_arena = 0
	off_screen = 0
	for point: Vector2 in _spawn_points:
		in_arena += int(inside.has_point(point))
		off_screen += int(not view.grow(spawner.view_margin - 0.01).has_point(point))
	total = _spawn_points.size()
	_check("in a corner, enemies still spawn", float(total >= 90), 1.0)
	_check("in a corner, every spawn is inside the arena", in_arena, total)
	_check("in a corner, every spawn is outside the camera view", off_screen, total)
	_target.position = Vector2(_ARENA.get_center())
	await _remove(spawner)


func _test_alive_cap() -> void:
	var wave: WaveData = _new_wave(30.0, 0.05, 4)
	var spawner: WaveSpawner = _new_spawner([wave], 20)
	spawner.start_wave(1)
	var most: int = 0
	for i: int in 60:
		await get_tree().physics_frame
		most = maxi(most, Enemy.active.size())
	_check("the spawner's cap is reached and never passed", most, 20)
	spawner.stop()
	Enemy.despawn_all()

	wave.max_alive = 10
	spawner.start_wave(1)
	most = 0
	for i: int in 60:
		await get_tree().physics_frame
		most = maxi(most, Enemy.active.size())
	_check("a wave can lower the cap", most, 10)
	spawner.stop()
	Enemy.despawn_all()

	wave.max_alive = 100
	spawner.max_alive = 500
	spawner.start_wave(1)
	most = 0
	for i: int in 150:
		await get_tree().physics_frame
		most = maxi(most, Enemy.active.size())
	_check("nothing can raise the cap above 100", most, WaveSpawner.HARD_CAP)
	await _remove(spawner)


func _test_scaling() -> void:
	var wave: WaveData = _new_wave(30.0, 0.1, 1)
	wave.hp_multiplier = 2.0
	wave.damage_multiplier = 1.5
	var spawner: WaveSpawner = _new_spawner([wave])
	spawner.start_wave(1)
	await _wait(3)
	var rat: Enemy = _spawned[0]
	var hitbox: HitboxComponent = rat.get_node("Hitbox") as HitboxComponent
	_check("the wave multiplies enemy hp", rat.health.max_hp, _RAT.max_hp * 2)
	_check("the enemy starts at its scaled hp", rat.health.current_hp, _RAT.max_hp * 2)
	_check("the wave multiplies contact damage", hitbox.damage, _RAT.contact_damage * 1.5)
	await _remove(spawner)

	var charger: ChargerEnemyData = _STRAY as ChargerEnemyData
	var stray: Enemy = Enemy.spawn(_STRAY, Vector2(100, 100), null, 1.0, 2.0)
	stray.set_contact_damage(charger.charge_damage)
	_check("the multiplier also applies to charge damage", (stray.get_node("Hitbox") as HitboxComponent).damage, charger.charge_damage * 2.0)
	var plain: Enemy = Enemy.spawn(_RAT, Vector2(200, 100), null)
	_check("without a wave, hp is the data's", plain.health.max_hp, _RAT.max_hp)
	Enemy.despawn_all()
	await _wait(2)


func _test_wave_sequence() -> void:
	var spawner: WaveSpawner = _new_spawner([_new_wave(0.5, 0.2, 1), _new_wave(0.5, 0.2, 1)])
	_check("wave count", spawner.get_wave_count(), 2)
	_check("a wave that does not exist is refused", float(spawner.start_wave(5)), 0.0)
	_check("wave 0 is refused", float(spawner.start_wave(0)), 0.0)
	_check("a refused wave starts nothing", float(spawner.is_wave_active()), 0.0)
	spawner.start_next_wave()
	await _wait(34)
	_check("wave 1 ended", float(str(_ended) == "[1]"), 1.0)
	_check("the spawner waits to be told to continue", float(spawner.is_wave_active()), 0.0)
	_check("the last wave has not ended yet", _all_done_count, 0)
	_check("start_next_wave starts wave 2", float(spawner.start_next_wave()), 1.0)
	_check("wave number is 2", spawner.current_wave_number, 2)
	_check("RunState follows", RunState.wave, 2)
	await _wait(34)
	_check("wave 2 ended", float(str(_ended) == "[1, 2]"), 1.0)
	_check("all_waves_completed after the last wave", _all_done_count, 1)
	_check("there is no wave 3", float(spawner.start_next_wave()), 0.0)
	await _remove(spawner)


func _test_boss_wave() -> void:
	var boss: EnemyData = _RAT.duplicate() as EnemyData
	boss.id = &"test_boss"
	boss.max_hp = 50
	var wave: WaveData = _new_wave(0.0, 0.5, 1)
	wave.boss = boss
	var spawner: WaveSpawner = _new_spawner([wave])
	var defeated_before: int = _bus_boss_defeated
	spawner.start_wave(1)
	var boss_enemy: Enemy = null
	for enemy: Enemy in Enemy.active:
		if enemy.data == boss:
			boss_enemy = enemy
	_check("the boss is spawned when the wave starts", float(boss_enemy != null), 1.0)
	_check("a boss wave has no timer", float(spawner.is_wave_timed()), 0.0)
	await _wait(90)
	_check("a boss wave does not end by itself", float(spawner.is_wave_active()), 1.0)
	_check("its other enemies still spawn", float(Enemy.active.size() > 1), 1.0)
	_spawned[1].hurtbox.take_hit(9999.0)
	_check("killing another enemy does not end it", float(spawner.is_wave_active()), 1.0)
	boss_enemy.hurtbox.take_hit(9999.0)
	_check("killing the boss ends the wave", float(str(_ended) == "[1]"), 1.0)
	_check("Events.boss_defeated is emitted", _bus_boss_defeated - defeated_before, 1)
	_check("the last wave ending completes the run of waves", _all_done_count, 1)
	await _remove(spawner)


func _test_stop_and_player_death() -> void:
	var spawner: WaveSpawner = _new_spawner([_new_wave(30.0, 0.1, 1)])
	spawner.start_wave(1)
	await _wait(20)
	spawner.stop()
	var alive: int = Enemy.active.size()
	var spawned_so_far: int = _spawned.size()
	await _wait(30)
	_check("stop halts the wave", float(spawner.is_wave_active()), 0.0)
	_check("stop does not end the wave", _ended.size(), 0)
	_check("stop leaves the enemies", Enemy.active.size(), alive)
	_check("nothing spawns after stop", _spawned.size(), spawned_so_far)

	spawner.start_wave(1)
	_check("a wave can be started again", float(spawner.is_wave_active()), 1.0)
	Events.player_died.emit()
	_check("the player's death stops the spawner", float(spawner.is_wave_active()), 0.0)
	await _remove(spawner)


# The real main scene, with two one-second waves in place of its own.
func _test_main_scene() -> void:
	var main: Node = _MAIN_SCENE.instantiate()
	var spawner: WaveSpawner = main.get_node("WaveSpawner") as WaveSpawner
	spawner.waves = [_new_wave(1.0, 0.2, 2), _new_wave(1.0, 0.2, 2, [_RAT, _STRAY])]
	add_child(main)
	# Nobody is playing, so make sure the player survives.
	main.get_node("Player/Hurtbox").process_mode = Node.PROCESS_MODE_DISABLED
	_check("the main scene starts wave 1 by itself", spawner.current_wave_number, 1)
	_check("the main scene starts the run", float(RunState.is_running), 1.0)
	await _wait(30)
	_check("enemies come for the player", float(Enemy.active.size() > 0 and Enemy.active[0].target == main.get_node("Player")), 1.0)
	await _wait(45)
	_check("wave 1 ends in the main scene", float(spawner.is_wave_active()), 0.0)
	_check("still on wave 1 during the pause between waves", spawner.current_wave_number, 1)
	await _wait(200)
	_check("wave 2 starts after the pause", spawner.current_wave_number, 2)
	# In this test the enemy pools belong to the test scene, not to main, so
	# they are cleared by hand. In the game they are freed with the scene.
	main.queue_free()
	Enemy.despawn_all()
	await _wait(2)

extends Node
## Regression test for skills 1 and 2: Consume and Blood Splatter. Run this
## scene (F6) and read the Output panel. Casts are synchronous, so it
## finishes in about a second.

const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _RAT: EnemyData = preload("res://data/enemies/gutter_rat.tres")
const _ORIGIN: Vector2 = Vector2(3000, 3000)
const CONSUME: int = 0
const SPLATTER: int = 1

var _failures: int = 0
var _checks: int = 0
var _player: Player
var _kills: int = 0


func _ready() -> void:
	Pools.set_host(self)
	Events.enemy_died.connect(func(_data: EnemyData, _at: Vector2) -> void: _kills += 1)
	await _setup()
	_test_consume_needs_a_target()
	await _test_consume_kills_nearest_and_heals()
	await _test_consume_reach()
	await _test_consume_skips_bosses()
	await _test_consume_scaling()
	await _test_splatter_area()
	await _test_splatter_scaling()
	await _test_splatter_no_crit()
	await _test_effects()
	print("Consume and Blood Splatter tests: %d checks, %d failed" % [_checks, _failures])


func _setup() -> void:
	_player = _PLAYER_SCENE.instantiate() as Player
	_player.position = _ORIGIN
	# Whatever the scene is saved with, this test starts with every skill locked.
	(_player.get_node("Skills") as SkillHolder).unlock_all_on_start = false
	add_child(_player)
	await get_tree().physics_frame
	_player.weapons.firing_enabled = false
	_player.collector.disable()
	_player.set_physics_process(false)
	_player.get_node("Hurtbox").process_mode = Node.PROCESS_MODE_DISABLED
	# No regen, so HP changes are exactly cost and heal.
	_player.health.process_mode = Node.PROCESS_MODE_DISABLED
	_player.skills.learn(CONSUME)
	_player.skills.learn(SPLATTER)


func _reset(hp: float = 50.0) -> void:
	_player.health.current_hp = hp
	for slot: int in _player.skills.get_slot_count():
		_player.skills.reset_cooldown(slot)
	_kills = 0


func _clear() -> void:
	Enemy.despawn_all()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _rat(offset: Vector2, hp_multiplier: float = 1.0, data: EnemyData = _RAT) -> Enemy:
	var rat: Enemy = Enemy.spawn(data, _ORIGIN + offset, _player, hp_multiplier)
	rat.set_physics_process(false)
	return rat


func _test_consume_needs_a_target() -> void:
	_reset()
	_check("with nothing in reach Consume is refused", _player.skills.try_cast(CONSUME), SkillHolder.CastResult.NO_TARGET)
	_check("a refused Consume costs nothing", _player.health.current_hp, 50.0)
	_check("a refused Consume has no cooldown", _player.skills.get_cooldown_left(CONSUME), 0.0)


func _test_consume_kills_nearest_and_heals() -> void:
	_reset()
	var near: Enemy = _rat(Vector2(15, 0))
	var far: Enemy = _rat(Vector2(-28, 0))
	var tough: Enemy = _rat(Vector2(0, 200), 50.0)
	_check("Consume casts with a rat in reach", _player.skills.try_cast(CONSUME), SkillHolder.CastResult.OK)
	_check("the nearest rat is consumed", float(Enemy.active.has(near)), 0.0)
	_check("the farther rat survives", float(Enemy.active.has(far) and far.health.current_hp == far.health.max_hp), 1.0)
	_check("the kill counts as a kill (XP, gold)", _kills, 1)
	_check("HP: -5 cost, +10 heal at 0 STR/VIT", _player.health.current_hp, 55.0)
	_check("cooldown 8 s", _player.skills.get_cooldown_left(CONSUME), 8.0)
	# A kill ignores HP entirely.
	tough.global_position = _ORIGIN + Vector2(10, 0)
	far.global_position = _ORIGIN + Vector2(-31, 0)
	_player.skills.reset_cooldown(CONSUME)
	_player.skills.try_cast(CONSUME)
	_check("a rat with 50x HP still dies outright", float(Enemy.active.has(tough)), 0.0)
	await _clear()


func _test_consume_reach() -> void:
	_reset()
	var edge: float = 32.0 + _RAT.hurtbox_radius
	var rat: Enemy = _rat(Vector2(edge + 2.0, 0))
	_check("just beyond reach (edge to edge) is refused", _player.skills.try_cast(CONSUME), SkillHolder.CastResult.NO_TARGET)
	rat.global_position = _ORIGIN + Vector2(edge - 1.0, 0)
	_check("just inside reach is consumed", _player.skills.try_cast(CONSUME), SkillHolder.CastResult.OK)
	await _clear()


func _test_consume_skips_bosses() -> void:
	_reset()
	var boss_data: EnemyData = _RAT.duplicate() as EnemyData
	boss_data.is_boss = true
	var boss: Enemy = _rat(Vector2(8, 0), 1.0, boss_data)
	_check("a boss alone in reach is refused", _player.skills.try_cast(CONSUME), SkillHolder.CastResult.NO_TARGET)
	_check("the boss is untouched", float(boss.health.current_hp == boss.health.max_hp), 1.0)
	var rat: Enemy = _rat(Vector2(-25, 0))
	_check("with a rat behind the boss, Consume casts", _player.skills.try_cast(CONSUME), SkillHolder.CastResult.OK)
	_check("the rat is consumed, not the nearer boss", float(Enemy.active.has(rat) or not Enemy.active.has(boss)), 0.0)
	await _clear()


func _test_consume_scaling() -> void:
	var skill: ConsumeSkill = _player.skills.get_skill(CONSUME) as ConsumeSkill
	_check("heal at 0 STR / 0 VIT is 10", skill.get_heal(), 10.0)
	_player.stats.strength = 5
	_player.stats.vitality = 10
	_check("heal = 10 + STR + VIT", skill.get_heal(), 25.0)
	_player.skills.learn(CONSUME)
	_player.skills.learn(CONSUME)
	_check("level 3 adds 40% to the whole heal", skill.get_heal(), 35.0)
	_reset(50.0)
	_rat(Vector2(10, 0))
	_player.skills.try_cast(CONSUME)
	_check("the cast heals that much", _player.health.current_hp, 50.0 - 5.0 + 35.0)
	_reset(_player.health.max_hp - 2.0)
	_rat(Vector2(10, 0))
	_player.skills.try_cast(CONSUME)
	_check("healing stops at Max HP", _player.health.current_hp, float(_player.health.max_hp))
	_player.stats.strength = 0
	_player.stats.vitality = 0
	await _clear()


func _test_splatter_area() -> void:
	_reset(80.0)
	var inside: Enemy = _rat(Vector2(10, 0), 5.0)
	var at_edge: Enemy = _rat(Vector2(0, 32.0 + _RAT.hurtbox_radius - 1.0), 5.0)
	var outside: Enemy = _rat(Vector2(-(32.0 + _RAT.hurtbox_radius + 2.0), 0), 5.0)
	_check("Blood Splatter casts", _player.skills.try_cast(SPLATTER), SkillHolder.CastResult.OK)
	_check("it cost 20 HP", _player.health.current_hp, 60.0)
	_check("an enemy inside takes 30", inside.health.max_hp - inside.health.current_hp, 30.0)
	_check("an enemy at the edge takes 30", at_edge.health.max_hp - at_edge.health.current_hp, 30.0)
	_check("an enemy outside is untouched", outside.health.max_hp - outside.health.current_hp, 0.0)
	await _clear()
	_reset(80.0)
	for i: int in 3:
		_rat(Vector2.from_angle(i * 2.0) * 15.0)
	_player.skills.try_cast(SPLATTER)
	_check("it can kill several at once, each a kill", _kills, 3)
	_check("they are gone", Enemy.active.size(), 0)
	await _clear()
	_reset(80.0)
	_check("with nothing in reach it still casts", _player.skills.try_cast(SPLATTER), SkillHolder.CastResult.OK)
	_check("and still costs 20", _player.health.current_hp, 60.0)


func _test_splatter_scaling() -> void:
	var skill: BloodSplatterSkill = _player.skills.get_skill(SPLATTER) as BloodSplatterSkill
	_check("damage at 0 INT is 30", skill.get_damage(), 30.0)
	_player.stats.intelligence = 10
	_check("INT 10 gives x1.3", skill.get_damage(), 39.0)
	_player.skills.learn(SPLATTER)
	_check("level 2 adds 20%", skill.get_damage(), 46.8)
	_player.stats.strength = 50
	_check("STR does not change it", skill.get_damage(), 46.8)
	_player.stats.strength = 0
	_reset(80.0)
	var rat: Enemy = _rat(Vector2(10, 0), 5.0)
	_player.skills.try_cast(SPLATTER)
	_check("the hit uses the scaled damage (rounded)", rat.health.max_hp - rat.health.current_hp, 47.0)
	_player.stats.intelligence = 0
	await _clear()


func _test_splatter_no_crit() -> void:
	var skill: BloodSplatterSkill = _player.skills.get_skill(SPLATTER) as BloodSplatterSkill
	_player.stats.luck = 999
	_check("the player always crits weapons now", _player.stats.crit_chance, 1.0)
	_reset(80.0)
	var rat: Enemy = _rat(Vector2(10, 0), 5.0)
	var crits: Array[bool] = []
	rat.hurtbox.hit_taken.connect(func(_amount: int, is_crit: bool) -> void: crits.append(is_crit))
	_player.skills.try_cast(SPLATTER)
	_check("Blood Splatter never crits in v1.0", float(crits == [false]), 1.0)
	_check("so it deals plain damage", rat.health.max_hp - rat.health.current_hp, roundf(skill.get_damage()))
	_player.stats.luck = 0
	await _clear()


func _test_effects() -> void:
	var splatter: BloodSplatterSkill = _player.skills.get_skill(SPLATTER) as BloodSplatterSkill
	var consume: ConsumeSkill = _player.skills.get_skill(CONSUME) as ConsumeSkill
	await _wait(30)
	_check("idle skills do no per-frame work", float(splatter.is_processing() or consume.is_processing()), 0.0)
	_reset(80.0)
	_rat(Vector2(10, 0))
	_player.skills.try_cast(CONSUME)
	_player.skills.try_cast(SPLATTER)
	_check("a cast starts the effect", float(splatter.is_processing() and consume.is_processing()), 1.0)
	await _wait(30)
	_check("the effects end on their own", float(splatter.is_processing() or consume.is_processing()), 0.0)
	await _clear()


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame

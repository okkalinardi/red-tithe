extends Node
## Regression test for skills 3 and 4: Dash and Berserk. Run this scene (F6)
## and read the Output panel. It takes a few seconds because dashes really
## move the player.

const _PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const _ORIGIN: Vector2 = Vector2(4000, 4000)
const SPLATTER: int = 1
const DASH: int = 2
const BERSERK: int = 3
const _DASH_FRAMES: int = 10

var _failures: int = 0
var _checks: int = 0
var _player: Player


func _ready() -> void:
	await _test_without_berserk()
	_player = await _new_player()
	_player.skills.learn(SPLATTER)
	_player.skills.learn(DASH)
	_player.skills.learn(BERSERK)
	await _test_dash_towards_aim()
	await _test_dash_follows_movement()
	await _test_dash_scaling()
	await _test_dash_wall()
	await _test_dash_not_invincible()
	_test_berserk_saves_and_buffs()
	_test_berserk_duration()
	_test_berserk_wave_change()
	await _test_berserk_once_per_cooldown()
	print("Dash and Berserk tests: %d checks, %d failed" % [_checks, _failures])


func _new_player() -> Player:
	var player: Player = _PLAYER_SCENE.instantiate() as Player
	player.position = _ORIGIN
	(player.get_node("Skills") as SkillHolder).unlock_all_on_start = false
	add_child(player)
	await get_tree().physics_frame
	player.weapons.firing_enabled = false
	player.collector.disable()
	# Aim is set by the test, not the mouse.
	player.set_process(false)
	player.get_node("Hurtbox").process_mode = Node.PROCESS_MODE_DISABLED
	# No regen and no i-frames, so every hit shows in HP exactly.
	player.health.process_mode = Node.PROCESS_MODE_DISABLED
	player.health.invincibility_time = 0.0
	return player


func _test_without_berserk() -> void:
	var player: Player = await _new_player()
	_check("without Berserk there is no second chance", float(player.health.lethal_hit_handler.is_valid()), 0.0)
	player.health.take_damage(9999.0)
	_check("without Berserk a lethal hit kills", float(player.health.is_alive()), 0.0)
	player.queue_free()
	await get_tree().physics_frame


func _cast_dash() -> Vector2:
	_player.health.current_hp = 100.0
	_player.skills.reset_cooldown(DASH)
	var start: Vector2 = _player.global_position
	_check("Dash casts", _player.skills.try_cast(DASH), SkillHolder.CastResult.OK)
	await _wait(_DASH_FRAMES)
	return _player.global_position - start


func _test_dash_towards_aim() -> void:
	_player.aim_at(_player.global_position + Vector2(100, 0))
	var moved: Vector2 = await _cast_dash()
	_check("standing still, Dash goes towards the aim", moved.normalized().dot(Vector2.RIGHT), 1.0, 0.01)
	_check("Dash covers 48 px at AGI 0", moved.length(), 48.0, 1.0)
	_check("Dash cost 8 HP", _player.health.current_hp, 92.0)
	_check("Dash cooldown is 2 s", float(_player.skills.get_cooldown_left(DASH) > 1.5), 1.0)
	_check("the dash is over", float(_player.is_dashing()), 0.0)


func _test_dash_follows_movement() -> void:
	_player.aim_at(_player.global_position + Vector2(100, 0))
	Input.action_press(&"move_up")
	await _wait(1)
	var moved: Vector2 = await _cast_dash()
	# The frames after the dash are walking up as well; take them off.
	var walked: float = _player.stats.move_speed / 60.0 * (_DASH_FRAMES - roundi(0.12 * 60.0))
	_check("moving, Dash follows the keys, not the aim", moved.normalized().dot(Vector2.UP), 1.0, 0.01)
	_check("and covers 48 px", moved.length() - walked, 48.0, 2.0)
	_check("after the dash the keys move the player again", _player.velocity.length(), _player.stats.move_speed, 0.5)
	Input.action_release(&"move_up")
	await _wait(1)


func _test_dash_scaling() -> void:
	var skill: DashSkill = _player.skills.get_skill(DASH) as DashSkill
	_check("distance 48 at AGI 0", skill.get_distance(), 48.0)
	_player.stats.agility = 20
	_check("distance = 48 + AGI", skill.get_distance(), 68.0)
	_player.skills.learn(DASH)
	_check("level 2 adds 20%", skill.get_distance(), 81.6)
	_player.aim_at(_player.global_position + Vector2(0, 100))
	var moved: Vector2 = await _cast_dash()
	_check("the dash really covers it", moved.length(), 81.6, 1.5)
	_player.stats.agility = 0


func _test_dash_wall() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 80)
	shape.shape = rect
	wall.add_child(shape)
	wall.global_position = _player.global_position + Vector2(25, 0)
	add_child(wall)
	await _wait(2)
	_player.aim_at(_player.global_position + Vector2(100, 0))
	var moved: Vector2 = await _cast_dash()
	_check("a wall stops the dash", float(moved.x < 25.0), 1.0)
	wall.queue_free()
	await _wait(1)


func _test_dash_not_invincible() -> void:
	_player.aim_at(_player.global_position + Vector2(-100, 0))
	_player.health.current_hp = 100.0
	_player.skills.reset_cooldown(DASH)
	_player.skills.try_cast(DASH)
	await _wait(2)
	_check("mid-dash", float(_player.is_dashing()), 1.0)
	_check("a hit lands mid-dash", _player.health.take_damage(10.0), 10.0)
	await _wait(_DASH_FRAMES)


func _test_berserk_saves_and_buffs() -> void:
	var skills: SkillHolder = _player.skills
	var berserk: BerserkSkill = skills.get_skill(BERSERK) as BerserkSkill
	var splatter: BloodSplatterSkill = skills.get_skill(SPLATTER) as BloodSplatterSkill
	var weapon: Weapon = _player.weapons.get_weapon(0)
	var weapon_damage: float = weapon.get_damage()
	var splatter_damage: float = splatter.get_damage()
	_check("learning Berserk hooks the lethal hit", float(_player.health.lethal_hit_handler.is_valid()), 1.0)
	_player.health.current_hp = 50.0
	_player.health.take_damage(20.0)
	_check("a hit that does not kill leaves Berserk unused", skills.get_cooldown_left(BERSERK), 0.0)
	_check("no buff yet", _player.stats.damage_buff_multiplier, 1.0)
	_player.health.take_damage(9999.0)
	_check("a lethal hit is survived", float(_player.health.is_alive()), 1.0)
	_check("at exactly 1 HP", _player.health.current_hp, 1.0)
	_check("Berserk goes on its 30 s cooldown", skills.get_cooldown_left(BERSERK), 30.0)
	_check("the buff is on", float(berserk.is_buff_active()), 1.0)
	_check("weapons deal x2", weapon.get_damage(), weapon_damage * 2.0)
	_check("skills deal x2", splatter.get_damage(), splatter_damage * 2.0)
	_check("the level-up screen's numbers are untouched", _player.stats.weapon_damage_multiplier(1.0, 0.0), 1.0)
	_check("the player is tinted", float((_player.get_node("Sprite") as CanvasItem).modulate != Color.WHITE), 1.0)
	_check("the buff lasts 10 s", berserk.get_buff_left(), 10.0)


func _test_berserk_duration() -> void:
	var berserk: BerserkSkill = _player.skills.get_skill(BERSERK) as BerserkSkill
	berserk._process(9.9)
	_check("still on at 9.9 s", float(berserk.is_buff_active()), 1.0)
	berserk._process(0.2)
	_check("off after 10 s", float(berserk.is_buff_active()), 0.0)
	_check("damage back to normal", _player.stats.damage_buff_multiplier, 1.0)
	_check("tint removed", float((_player.get_node("Sprite") as CanvasItem).modulate == Color.WHITE), 1.0)
	_check("cooldown keeps running after the buff", float(_player.skills.get_cooldown_left(BERSERK) > 0.0), 1.0)
	_player.skills.learn(BERSERK)
	_check("level 2 lasts 12 s", berserk.get_duration(), 12.0)


func _test_berserk_wave_change() -> void:
	var skills: SkillHolder = _player.skills
	var berserk: BerserkSkill = skills.get_skill(BERSERK) as BerserkSkill
	skills.reset_cooldown(BERSERK)
	_player.health.current_hp = 30.0
	_player.health.take_damage(9999.0)
	_check("saved again", float(berserk.is_buff_active() and _player.health.is_alive()), 1.0)
	Events.wave_completed.emit(4)
	_check("the buff ends when the wave ends", float(berserk.is_buff_active()), 0.0)
	_check("damage back to normal", _player.stats.damage_buff_multiplier, 1.0)
	_check("the cooldown waits for the next wave", float(skills.get_cooldown_left(BERSERK) > 0.0), 1.0)
	Events.wave_started.emit(5)
	_check("a new wave makes it ready again", skills.get_cooldown_left(BERSERK), 0.0)


func _test_berserk_once_per_cooldown() -> void:
	_player.health.current_hp = 30.0
	_player.health.take_damage(9999.0)
	_check("first lethal hit of the wave: saved", float(_player.health.is_alive()), 1.0)
	_player.health.take_damage(9999.0)
	_check("second lethal hit in the same wave: dead", float(_player.health.is_alive()), 0.0)
	await _wait(1)


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame

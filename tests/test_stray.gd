extends Node
## Regression test for the state machine and the Stray (charger): approach,
## wind-up, charge, rest. Run this scene (F6) and read the Output panel. It
## takes about 15 seconds because the Stray really walks and charges.
##
## The numbers used here are set by the test, so editing stray.tres does not
## break it.

const _STRAY: ChargerEnemyData = preload("res://data/enemies/stray.tres")
const _STEP_LIMIT: int = 900

var _failures: int = 0
var _checks: int = 0
var _changes: Array[String] = []


## A state that only records what happens to it.
class ProbeState:
	extends State
	var entered: int = 0
	var exited: int = 0
	var updated: int = 0
	var came_from: State

	func enter(previous: State) -> void:
		entered += 1
		came_from = previous

	func exit() -> void:
		exited += 1

	func physics_update(_delta: float) -> void:
		updated += 1


func _ready() -> void:
	_test_state_machine()
	_test_data_file()
	await _test_charge_cycle()
	await _test_wall_ends_charge()
	await _test_pooled_reuse()
	print("Stray tests: %d checks, %d failed" % [_checks, _failures])


func _check(what: String, actual: float, expected: float, tolerance: float = 0.001) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _check_state(what: String, stray: StateEnemy, expected: StringName) -> void:
	_checks += 1
	if stray.state_machine.get_state_name() != expected:
		_failures += 1
		print("FAIL  %s: state is %s, expected %s" % [what, stray.state_machine.get_state_name(), expected])


func _wait(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


## Waits until the Stray is in a state. Returns the number of frames waited.
func _wait_for_state(stray: StateEnemy, state_name: StringName) -> int:
	var frames: int = 0
	while stray.state_machine.get_state_name() != state_name and frames < _STEP_LIMIT:
		await get_tree().physics_frame
		frames += 1
	return frames


func _new_stray_data() -> ChargerEnemyData:
	var data: ChargerEnemyData = _STRAY.duplicate() as ChargerEnemyData
	data.max_hp = 100
	data.move_speed = 50.0
	data.contact_damage = 5.0
	data.contact_interval = 0.5
	data.body_radius = 6.0
	data.contact_radius = 7.0
	data.separation_strength = 0.0
	data.charge_range = 80.0
	data.telegraph_time = 0.5
	data.telegraph_tint = Color(1.0, 0.4, 0.4)
	data.charge_speed = 200.0
	data.charge_distance = 120.0
	data.charge_damage = 20.0
	data.recover_time = 0.5
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


func _test_state_machine() -> void:
	var machine := StateMachine.new()
	var first := ProbeState.new()
	first.name = "First"
	var second := ProbeState.new()
	second.name = "Second"
	machine.add_child(first)
	machine.add_child(second)
	machine.initial_state = first
	add_child(machine)
	machine.setup(self)
	machine.state_changed.connect(func(previous: State, current: State) -> void:
		_changes.append("%s>%s" % [previous.name if previous != null else &"none", current.name])
	)
	_check("no state before start", float(machine.current == null), 1.0)
	_check("states know their machine", float(first.machine == machine), 1.0)
	_check("machine knows its actor", float(machine.actor == self), 1.0)
	machine.physics_update(0.1)
	_check("nothing updates before start", first.updated, 0)

	machine.start()
	_check("start enters the initial state", float(machine.current == first), 1.0)
	_check("enter is called once", first.entered, 1)
	_check("the first enter has no previous state", float(first.came_from == null), 1.0)
	_check("state name is the node name", float(machine.get_state_name() == &"First"), 1.0)
	machine.physics_update(0.25)
	machine.physics_update(0.25)
	_check("only the current state updates", first.updated * 10 + second.updated, 20)
	_check("time in state adds up", machine.time_in_state, 0.5)
	_check("a state can read its time", first.get_time_in_state(), 0.5)

	first.transition_to(second)
	_check("transition leaves the old state", first.exited, 1)
	_check("transition enters the new state", second.entered, 1)
	_check("the new state is told where it came from", float(second.came_from == first), 1.0)
	_check("time in state restarts", machine.time_in_state, 0.0)
	machine.physics_update(0.1)
	_check("the new state updates", second.updated, 1)
	_check("the old state no longer updates", first.updated, 2)

	machine.start()
	_check("start again leaves the current state", second.exited, 1)
	_check("start again re-enters the initial state", first.entered, 2)
	_check("state_changed was emitted each time", float("|".join(_changes) == "none>First|First>Second|Second>First"), 1.0)
	machine.queue_free()


func _test_data_file() -> void:
	_check("stray.tres is charger data", float(_STRAY is ChargerEnemyData), 1.0)
	_check("stray sheet faces left", float(_STRAY.sprite_faces_left), 1.0)
	for animation: String in ["idle", "approach", "telegraph", "charge"]:
		_check("stray has " + animation, float(_STRAY.sprite_frames.has_animation(animation)), 1.0)
		_check(animation + " has 8 frames", _STRAY.sprite_frames.get_frame_count(animation), 8)
	var first_charge_frame: AtlasTexture = _STRAY.sprite_frames.get_frame_texture(&"charge", 0) as AtlasTexture
	_check("charge frames come from the third row", first_charge_frame.region.position.y, 96)
	_check("frames are 64 px wide", first_charge_frame.region.size.x, 64)
	var instance: Node = _STRAY.scene.instantiate()
	_check("stray scene is a StateEnemy", float(instance is StateEnemy), 1.0)
	var machine: StateMachine = instance.get_node("StateMachine") as StateMachine
	_check("it has a state machine", float(machine != null), 1.0)
	for state_name: String in ["Approach", "Telegraph", "Charge", "Recover"]:
		_check("it has the %s state" % state_name, float(machine.get_node_or_null(state_name) is EnemyState), 1.0)
	_check("it still has the shared enemy parts", float(instance.get_node_or_null("Hurtbox") is HurtboxComponent), 1.0)
	instance.free()


func _test_charge_cycle() -> void:
	var data: ChargerEnemyData = _new_stray_data()
	var target: Node2D = _new_target(Vector2(4000, 0))
	var stray: StateEnemy = Enemy.spawn(data, target.position + Vector2(-200, 0), target) as StateEnemy
	var sprite: AnimatedSprite2D = stray.get_node("Sprite") as AnimatedSprite2D
	var hitbox: HitboxComponent = stray.get_node("Hitbox") as HitboxComponent
	_check("spawn gives a StateEnemy", float(stray != null), 1.0)
	_check_state("starts by approaching", stray, &"Approach")
	_check("approach animation plays", float(sprite.animation == &"approach"), 1.0)

	# Approach: 200 px away, wind-up starts at 80 px, walking 50 px/s.
	var frames: int = await _wait_for_state(stray, &"Telegraph")
	_check("walks until in charge range", frames, 144, 4.0)
	_check("wind-up starts at charge range", stray.global_position.distance_to(target.global_position), 80.0, 1.5)
	_check("a left-facing sheet is mirrored to face right", float(sprite.flip_h), 1.0)
	var telegraph_position: Vector2 = stray.global_position
	await _wait(5)
	_check("stands still during the wind-up", stray.global_position.distance_to(telegraph_position), 0.0)
	_check("wind-up animation plays", float(sprite.animation == &"telegraph"), 1.0)
	_check("sprite is tinted during the wind-up", sprite.modulate.g, 0.4, 0.01)
	_check("a touch is still normal damage during the wind-up", hitbox.damage, 5.0)

	frames = await _wait_for_state(stray, &"Charge")
	_check("wind-up lasts telegraph_time", frames + 5, 30, 2.0)
	_check("tint is removed when the charge starts", sprite.modulate.g, 1.0)
	_check("charge animation plays", float(sprite.animation == &"charge"), 1.0)
	_check("a touch is charge damage during the charge", hitbox.damage, 20.0)
	var charge_start: Vector2 = stray.global_position
	await _wait(6)
	_check("charges at charge_speed", stray.velocity.length(), 200.0, 0.5)

	frames = await _wait_for_state(stray, &"Recover")
	var charged: Vector2 = stray.global_position - charge_start
	_check("charge covers charge_distance", charged.x, 120.0, 8.0)
	_check("charge is a straight line", charged.y, 0.0, 0.5)
	_check("charge runs through the target", float(stray.global_position.x > target.global_position.x), 1.0)
	_check("the target is hit once, for charge damage", _damage_taken(target), 20)
	_check("a touch is normal damage again after the charge", hitbox.damage, 5.0)
	_check("rest animation plays", float(sprite.animation == &"idle"), 1.0)
	var rest_position: Vector2 = stray.global_position
	await _wait(5)
	_check("stands still while resting", stray.global_position.distance_to(rest_position), 0.0)

	frames = await _wait_for_state(stray, &"Approach")
	_check("rest lasts recover_time", frames + 5, 30, 2.0)

	# Second cycle: the target is already in range, so the wind-up starts at once.
	frames = await _wait_for_state(stray, &"Telegraph")
	_check("winds up again at once when in range", float(frames <= 2), 1.0)
	# The target moves during the wind-up: the charge must follow it there.
	target.global_position = stray.global_position + Vector2(0, -60)
	await _wait_for_state(stray, &"Charge")
	charge_start = stray.global_position
	# The target sidesteps after the charge has started: the charge must not turn.
	target.global_position = stray.global_position + Vector2(300, 0)
	await _wait_for_state(stray, &"Recover")
	charged = stray.global_position - charge_start
	_check("the charge aims where the target was when the wind-up ended", charged.y, -120.0, 8.0)
	_check("the charge does not turn after it starts", charged.x, 0.0, 0.5)
	_check("a dodged charge deals nothing", _damage_taken(target), 20, 0.6)

	Enemy.despawn_all()
	target.queue_free()
	await _wait(2)


func _test_wall_ends_charge() -> void:
	var data: ChargerEnemyData = _new_stray_data()
	var target: Node2D = _new_target(Vector2(8000, 0))
	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	wall.position = target.position + Vector2(30, 0)
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 400)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	add_child(wall)
	var stray: StateEnemy = Enemy.spawn(data, target.position + Vector2(-60, 0), target) as StateEnemy
	await _wait_for_state(stray, &"Charge")
	var charge_start: Vector2 = stray.global_position
	var frames: int = await _wait_for_state(stray, &"Recover")
	var charged: float = stray.global_position.x - charge_start.x
	_check("a wall stops the Stray", float(stray.global_position.x < wall.position.x), 1.0)
	# 80 px to the wall; the first step of the charge is taken before the
	# test can read the start position, hence the tolerance.
	_check("the charge ended at the wall, before its full distance", charged, 78.0, 4.0)
	_check("the charge ended as soon as it hit", float(frames <= 28), 1.0)
	Enemy.despawn_all()
	wall.queue_free()
	target.queue_free()
	await _wait(2)


func _test_pooled_reuse() -> void:
	var data: ChargerEnemyData = _new_stray_data()
	var target: Node2D = _new_target(Vector2(12000, 0))
	var stray: StateEnemy = Enemy.spawn(data, target.position + Vector2(-60, 0), target) as StateEnemy
	var sprite: AnimatedSprite2D = stray.get_node("Sprite") as AnimatedSprite2D
	var hitbox: HitboxComponent = stray.get_node("Hitbox") as HitboxComponent
	await _wait_for_state(stray, &"Telegraph")
	await _wait(3)
	stray.hurtbox.take_hit(9999.0)
	await get_tree().process_frame
	var again: StateEnemy = Enemy.spawn(data, target.position + Vector2(-300, 0), target) as StateEnemy
	_check("the pooled Stray is reused", float(again == stray), 1.0)
	_check_state("a reused Stray starts by approaching", again, &"Approach")
	_check("a reused Stray is not tinted", sprite.modulate.g, 1.0)

	again.global_position = target.position + Vector2(-60, 0)
	await _wait_for_state(again, &"Charge")
	await _wait(2)
	again.hurtbox.take_hit(9999.0)
	await get_tree().process_frame
	var third: StateEnemy = Enemy.spawn(data, target.position + Vector2(-300, 0), target) as StateEnemy
	_check_state("killed mid-charge, it still restarts cleanly", third, &"Approach")
	_check("its touch is back to normal damage", hitbox.damage, 5.0)
	await _wait(30)
	_check("a reused Stray walks at walking speed", third.velocity.length(), 50.0, 0.5)
	Enemy.despawn_all()
	target.queue_free()
	await _wait(2)

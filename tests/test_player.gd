extends Node
## Regression test for player movement, aim and camera limits. Run this scene
## (F6), keep your hands off the keyboard for three seconds, and read the
## Output panel. It drives the real main scene with simulated key presses.

const _MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const _HALF_SECOND_FRAMES: int = 30

var _failures: int = 0
var _checks: int = 0
var _player: Player
var _camera: Camera2D
var _bounds: Rect2i


func _ready() -> void:
	var main: Node = _MAIN_SCENE.instantiate()
	add_child(main)
	# Enemies would get in the way of a movement test.
	var spawner: Node = main.get_node_or_null("DebugEnemySpawner")
	if spawner != null:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_camera = _player.get_node("Camera") as Camera2D
	_bounds = (main.get_node("Arena") as Arena).get_bounds()
	await _wait_frames(2)

	_test_setup()
	await _test_straight_movement()
	await _test_diagonal_movement()
	await _test_speed_follows_stats()
	await _test_walls_and_camera()
	_test_aim()
	await _test_animation()

	var summary: String = "Player tests: %d checks, %d failed" % [_checks, _failures]
	print(summary)


func _wait_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _hold(actions: Array[StringName], frames: int) -> Vector2:
	var start: Vector2 = _player.global_position
	for action: StringName in actions:
		Input.action_press(action)
	await _wait_frames(frames)
	for action: StringName in actions:
		Input.action_release(action)
	await _wait_frames(1)
	return _player.global_position - start


func _check(what: String, actual: float, expected: float, tolerance: float = 0.01) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL  %s: got %s, expected %s" % [what, actual, expected])


func _test_setup() -> void:
	var center: Vector2 = Vector2(_bounds.get_center())
	_check("arena width", _bounds.size.x, 960)
	_check("arena height", _bounds.size.y, 544)
	_check("player starts at arena centre x", _player.global_position.x, center.x)
	_check("player starts at arena centre y", _player.global_position.y, center.y)
	_check("player has its own stats", float(_player.stats != null), 1.0)
	_check("camera limit left", _camera.limit_left, _bounds.position.x)
	_check("camera limit top", _camera.limit_top, _bounds.position.y)
	_check("camera limit right", _camera.limit_right, _bounds.end.x)
	_check("camera limit bottom", _camera.limit_bottom, _bounds.end.y)


func _test_straight_movement() -> void:
	var moved: Vector2 = await _hold([&"move_right"], _HALF_SECOND_FRAMES)
	# 90 px/s for half a second, give or take one frame.
	_check("right: distance", moved.x, 45.0, 3.5)
	_check("right: no vertical drift", moved.y, 0.0)
	moved = await _hold([&"move_up"], _HALF_SECOND_FRAMES)
	_check("up: distance", moved.y, -45.0, 3.5)
	_check("up: no horizontal drift", moved.x, 0.0)
	_check("stops when keys are released", _player.velocity.length(), 0.0)


func _test_diagonal_movement() -> void:
	var moved: Vector2 = await _hold([&"move_left", &"move_down"], _HALF_SECOND_FRAMES)
	_check("diagonal is not faster", moved.length(), 45.0, 3.5)
	_check("diagonal is 45 degrees", absf(moved.x), absf(moved.y))
	moved = await _hold([&"move_left", &"move_right"], _HALF_SECOND_FRAMES)
	_check("opposite keys cancel", moved.length(), 0.0)


func _test_speed_follows_stats() -> void:
	_player.stats.agility = 50
	var moved: Vector2 = await _hold([&"move_right"], _HALF_SECOND_FRAMES)
	# 117 px/s for half a second.
	_check("AGI 50 speed", moved.x, 58.5, 4.5)
	_player.stats.agility = 0


func _test_walls_and_camera() -> void:
	var half_screen: Vector2 = get_viewport().get_visible_rect().size / 2.0
	_player.global_position = Vector2(_bounds.end) - Vector2(20, 20)
	await _hold([&"move_right", &"move_down"], 60)
	await _wait_frames(2)
	_check("right wall stops the player", _player.global_position.x, _bounds.end.x - 5.0, 0.5)
	_check("bottom wall stops the player", _player.global_position.y, _bounds.end.y - 5.0, 0.5)
	var view_center: Vector2 = _camera.get_screen_center_position()
	_check("camera clamps at right edge", view_center.x, _bounds.end.x - half_screen.x, 0.5)
	_check("camera clamps at bottom edge", view_center.y, _bounds.end.y - half_screen.y, 0.5)

	_player.global_position = Vector2(_bounds.position) + Vector2(20, 20)
	await _hold([&"move_left", &"move_up"], 60)
	await _wait_frames(2)
	_check("left wall stops the player", _player.global_position.x, _bounds.position.x + 5.0, 0.5)
	_check("top wall stops the player", _player.global_position.y, _bounds.position.y + 5.0, 0.5)
	view_center = _camera.get_screen_center_position()
	_check("camera clamps at left edge", view_center.x, _bounds.position.x + half_screen.x, 0.5)
	_check("camera clamps at top edge", view_center.y, _bounds.position.y + half_screen.y, 0.5)

	_player.global_position = Vector2(_bounds.get_center())
	await _wait_frames(2)
	view_center = _camera.get_screen_center_position()
	_check("camera follows in open space x", view_center.x, _player.global_position.x, 0.5)
	_check("camera follows in open space y", view_center.y, _player.global_position.y, 0.5)


func _test_aim() -> void:
	var pivot: Node2D = _player.get_node("AimPivot") as Node2D
	var sprite: AnimatedSprite2D = _player.get_node("Sprite") as AnimatedSprite2D
	_player.aim_at(_player.global_position + Vector2(0, 50))
	_check("aim down: x", _player.aim_direction.x, 0.0)
	_check("aim down: y", _player.aim_direction.y, 1.0)
	_check("aim pivot rotates", pivot.rotation, PI / 2.0)
	_check("faces down", _player.facing, Player.Facing.DOWN)
	_check_animation("idle_down", sprite)
	_player.aim_at(_player.global_position + Vector2(-30, 0))
	_check("aim left: x", _player.aim_direction.x, -1.0)
	_check_animation("idle_left", sprite)
	_player.aim_at(_player.global_position + Vector2(5, -40))
	_check_animation("idle_up", sprite)
	_player.aim_at(_player.global_position + Vector2(40, 30))
	_check("aim is a unit vector", _player.aim_direction.length(), 1.0)
	_check_animation("idle_right", sprite)
	_check("sprite is never mirrored", float(sprite.flip_h), 0.0)
	var before: Vector2 = _player.aim_direction
	_player.aim_at(_player.global_position)
	_check("aim keeps last direction on the player", _player.aim_direction.distance_to(before), 0.0)


func _test_animation() -> void:
	var sprite: AnimatedSprite2D = _player.get_node("Sprite") as AnimatedSprite2D
	var frames: SpriteFrames = sprite.sprite_frames
	for direction: String in ["down", "up", "left", "right"]:
		_check("idle_%s has 1 frame" % direction, frames.get_frame_count("idle_" + direction), 1)
		_check("walk_%s has 4 frames" % direction, frames.get_frame_count("walk_" + direction), 4)
	_check("dead has 1 frame", frames.get_frame_count(&"dead"), 1)
	var first: AtlasTexture = frames.get_frame_texture(&"walk_right", 2) as AtlasTexture
	_check("walk_right frame 2 region x", first.region.position.x, 48)
	_check("walk_right frame 2 region y", first.region.position.y, 32)
	_check("frame is 16 px wide", first.region.size.x, 16)

	Input.action_press(&"move_right")
	await _wait_frames(6)
	_check("walks while moving", float(String(sprite.animation).begins_with("walk_")), 1.0)
	_check("walk animation is playing", float(sprite.is_playing()), 1.0)
	Input.action_release(&"move_right")
	await _wait_frames(4)
	_check("idles when stopped", float(String(sprite.animation).begins_with("idle_")), 1.0)


func _check_animation(expected: String, sprite: AnimatedSprite2D) -> void:
	_checks += 1
	if String(sprite.animation) != expected:
		_failures += 1
		print("FAIL  animation: got %s, expected %s" % [sprite.animation, expected])

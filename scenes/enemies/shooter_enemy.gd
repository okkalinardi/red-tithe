class_name ShooterEnemy
extends StateEnemy
## A [StateEnemy] that fires projectiles. Holds what its states share: the
## time until the next shot, the direction it circles in, and the shot itself.
## Configured by a [ShooterEnemyData]; see res://scenes/enemies/states/shooter_*.

const FLY_ANIMATIONS: Array[StringName] = [&"fly_down", &"fly_up", &"fly_left", &"fly_right"]
const AIM_ANIMATIONS: Array[StringName] = [&"aim_down", &"aim_up", &"aim_left", &"aim_right"]
const ATTACK_ANIMATIONS: Array[StringName] = [&"attack_down", &"attack_up", &"attack_left", &"attack_right"]

## Seconds until the shooter may start its next attack.
var fire_cooldown_left: float = 0.0
## 1 circles clockwise, -1 anticlockwise. Picked per spawn.
var orbit_sign: float = 1.0
## Replace with a seeded generator to make tests repeatable.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _shooter: ShooterEnemyData
var _prewarmed: Dictionary[PackedScene, bool] = {}


func _physics_process(delta: float) -> void:
	if fire_cooldown_left > 0.0:
		fire_cooldown_left -= delta
	super(delta)


## Fires a volley towards [param target_position]. Returns how many
## projectiles were launched (fewer if the pool is at its limit).
func fire_at(target_position: Vector2) -> int:
	if _shooter == null or _shooter.projectile_scene == null:
		return 0
	var origin: Vector2 = global_position + _shooter.muzzle_offset
	var aim: Vector2 = origin.direction_to(target_position)
	if aim.is_zero_approx():
		aim = Vector2.DOWN
	var count: int = _shooter.projectiles_per_shot
	var spread: float = deg_to_rad(_shooter.spread_degrees)
	# The damage is fixed at the moment of firing, so a shot still in flight
	# is not changed if this enemy is despawned and reused.
	var damage: float = _shooter.projectile_damage * damage_multiplier
	var on_hit: Callable = func(hit: HurtboxComponent) -> void: hit.take_hit(damage)
	var launched: int = 0
	for i: int in count:
		var offset: float = 0.0
		if count > 1:
			offset = lerpf(-spread * 0.5, spread * 0.5, float(i) / (count - 1))
		var projectile: Projectile = Pools.acquire(_shooter.projectile_scene) as Projectile
		if projectile == null:
			break
		projectile.launch(origin, aim.rotated(offset), _shooter.projectile_speed, _shooter.projectile_range, 0, on_hit)
		launched += 1
	return launched


## Starts the wait before the next attack.
func start_fire_cooldown() -> void:
	var variance: float = _shooter.fire_interval_variance
	fire_cooldown_left = _shooter.fire_interval * rng.randf_range(1.0 - variance, 1.0 + variance)


func can_fire() -> bool:
	return fire_cooldown_left <= 0.0


## True if the shooter is inside the camera's view, shrunk by [param margin]
## pixels. Without a camera it counts as on screen.
func is_on_screen(margin: float = 8.0) -> bool:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return true
	var size: Vector2 = get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - size * 0.5, size)
	return view.grow(-margin).has_point(global_position)


## Plays the one of four [param animations] (down, up, left, right) that
## looks along [param direction].
func play_directional(animations: Array[StringName], direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	var index: int
	if absf(direction.x) > absf(direction.y):
		index = 3 if direction.x > 0.0 else 2
	else:
		index = 0 if direction.y > 0.0 else 1
	play_animation(animations[index])


func _activate(
	enemy_data: EnemyData,
	at: Vector2,
	target_node: Node2D,
	hp_multiplier: float,
	damage_multiplier_value: float,
) -> void:
	_shooter = enemy_data as ShooterEnemyData
	if _shooter == null:
		push_error("ShooterEnemy needs a ShooterEnemyData, got '%s'." % enemy_data.id)
	else:
		_prewarm_projectiles()
		fire_cooldown_left = rng.randf_range(_shooter.first_shot_delay.x, _shooter.first_shot_delay.y)
	orbit_sign = 1.0 if rng.randf() < 0.5 else -1.0
	super(enemy_data, at, target_node, hp_multiplier, damage_multiplier_value)


func _prewarm_projectiles() -> void:
	var scene: PackedScene = _shooter.projectile_scene
	if scene == null or _prewarmed.has(scene):
		return
	_prewarmed[scene] = true
	Pools.prewarm(scene, _shooter.projectile_pool_prewarm)

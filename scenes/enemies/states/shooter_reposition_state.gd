class_name ShooterRepositionState
extends EnemyState
## Keeps between [member ShooterEnemyData.min_distance] and
## [member ShooterEnemyData.max_distance] of the target, circling it, until
## it is ready to fire, in range and on screen.

## Entered when it is time to attack.
@export var attack_state: State


func physics_update(_delta: float) -> void:
	var shooter: ShooterEnemy = enemy as ShooterEnemy
	var data: ShooterEnemyData = shooter.data as ShooterEnemyData
	if shooter.can_fire() and get_distance_to_target() <= data.fire_range and shooter.is_on_screen():
		transition_to(attack_state)


func get_velocity() -> Vector2:
	var shooter: ShooterEnemy = enemy as ShooterEnemy
	var data: ShooterEnemyData = shooter.data as ShooterEnemyData
	var direction: Vector2 = get_direction_to_target()
	shooter.play_directional(ShooterEnemy.FLY_ANIMATIONS, direction)
	if direction.is_zero_approx():
		return shooter.get_separation_velocity()
	var distance: float = get_distance_to_target()
	var radial: float = 0.0
	if distance > data.max_distance:
		radial = 1.0
	elif distance < data.min_distance:
		radial = -1.0
	var orbit: Vector2 = direction.orthogonal() * shooter.orbit_sign * data.orbit_speed_ratio
	var move: Vector2 = (direction * radial + orbit).limit_length(1.0)
	return move * data.move_speed + shooter.get_separation_velocity()

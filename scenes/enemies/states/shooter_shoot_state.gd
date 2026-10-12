class_name ShooterShootState
extends EnemyState
## Fires once on entry, then holds still for a moment. This is when the
## shooter is easiest to hit.

## Entered when the rest after the shot is over.
@export var next_state: State


func enter(previous: State) -> void:
	super(previous)
	var shooter: ShooterEnemy = enemy as ShooterEnemy
	shooter.play_directional(ShooterEnemy.ATTACK_ANIMATIONS, get_direction_to_target())
	if is_instance_valid(shooter.target):
		shooter.fire_at(shooter.target.global_position)
	shooter.start_fire_cooldown()


func physics_update(_delta: float) -> void:
	if get_time_in_state() >= (enemy.data as ShooterEnemyData).recover_time:
		transition_to(next_state)

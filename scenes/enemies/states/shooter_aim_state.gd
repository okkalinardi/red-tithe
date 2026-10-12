class_name ShooterAimState
extends EnemyState
## Hovers and winds up, turning to follow the target. The shot is aimed at
## where the target is when the wind-up ends.

## Entered when the wind-up is over.
@export var next_state: State


func enter(previous: State) -> void:
	super(previous)
	var shooter: ShooterEnemy = enemy as ShooterEnemy
	shooter.set_tint((shooter.data as ShooterEnemyData).aim_tint)
	shooter.play_directional(ShooterEnemy.AIM_ANIMATIONS, get_direction_to_target())


func exit() -> void:
	enemy.set_tint(Color.WHITE)


func physics_update(_delta: float) -> void:
	var shooter: ShooterEnemy = enemy as ShooterEnemy
	shooter.play_directional(ShooterEnemy.AIM_ANIMATIONS, get_direction_to_target())
	if get_time_in_state() >= (shooter.data as ShooterEnemyData).aim_time:
		transition_to(next_state)


func get_velocity() -> Vector2:
	return enemy.get_separation_velocity()

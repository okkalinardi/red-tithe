class_name ChargerTelegraphState
extends EnemyState
## Stands still and winds up. The enemy keeps turning to face the target, so
## the charge is aimed at where the target is when the wind-up ends.

## Entered when the wind-up is over.
@export var next_state: State


func enter(previous: State) -> void:
	super(previous)
	enemy.set_tint((enemy.data as ChargerEnemyData).telegraph_tint)


func exit() -> void:
	enemy.set_tint(Color.WHITE)


func physics_update(_delta: float) -> void:
	enemy.face_direction(get_direction_to_target())
	if get_time_in_state() >= (enemy.data as ChargerEnemyData).telegraph_time:
		transition_to(next_state)

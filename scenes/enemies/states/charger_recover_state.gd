class_name ChargerRecoverState
extends EnemyState
## Stands still after a charge. This is when the enemy is easy to hit.

## Entered when the rest is over.
@export var next_state: State


func physics_update(_delta: float) -> void:
	if get_time_in_state() >= (enemy.data as ChargerEnemyData).recover_time:
		transition_to(next_state)

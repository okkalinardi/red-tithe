class_name ChargerApproachState
extends EnemyState
## Walks towards the target until it is within charge range.

## Entered when the target is in range.
@export var in_range_state: State


func physics_update(_delta: float) -> void:
	var data: ChargerEnemyData = enemy.data as ChargerEnemyData
	if get_distance_to_target() <= data.charge_range:
		transition_to(in_range_state)


func get_velocity() -> Vector2:
	var direction: Vector2 = get_direction_to_target()
	enemy.face_direction(direction)
	return direction * enemy.data.move_speed + enemy.get_separation_velocity()

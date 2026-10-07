class_name EnemyState
extends State
## Base for the states of a [StateEnemy].

## Played when the state is entered. Leave empty to keep the current one.
@export var animation: StringName = &""

## The enemy this state drives.
var enemy: Enemy:
	get:
		return machine.actor as Enemy


func enter(_previous: State) -> void:
	if animation != &"":
		enemy.play_animation(animation)


## The velocity the enemy should have while in this state.
func get_velocity() -> Vector2:
	return Vector2.ZERO


## The unit vector from the enemy to its target, or zero without a target.
func get_direction_to_target() -> Vector2:
	if not is_instance_valid(enemy.target):
		return Vector2.ZERO
	return enemy.global_position.direction_to(enemy.target.global_position)


func get_distance_to_target() -> float:
	if not is_instance_valid(enemy.target):
		return INF
	return enemy.global_position.distance_to(enemy.target.global_position)

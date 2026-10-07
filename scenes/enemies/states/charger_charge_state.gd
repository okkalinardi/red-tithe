class_name ChargerChargeState
extends EnemyState
## Runs in a straight line. The direction is fixed when the charge starts, so
## stepping aside dodges it. Ends after the charge distance or at a wall.

## Entered when the charge ends.
@export var next_state: State

var _direction: Vector2 = Vector2.ZERO
var _start: Vector2 = Vector2.ZERO
var _has_moved: bool = false


func enter(previous: State) -> void:
	super(previous)
	var data: ChargerEnemyData = enemy.data as ChargerEnemyData
	_direction = get_direction_to_target()
	_start = enemy.global_position
	_has_moved = false
	enemy.face_direction(_direction)
	enemy.set_contact_damage(data.charge_damage)


func exit() -> void:
	enemy.set_contact_damage(enemy.data.contact_damage)


func physics_update(_delta: float) -> void:
	var data: ChargerEnemyData = enemy.data as ChargerEnemyData
	var travelled: float = enemy.global_position.distance_to(_start)
	# A collision reported before the first step of the charge is left over
	# from the walk that came before it.
	var hit_wall: bool = _has_moved and enemy.get_slide_collision_count() > 0
	if _direction == Vector2.ZERO or travelled >= data.charge_distance or hit_wall:
		transition_to(next_state)
		return
	_has_moved = true


func get_velocity() -> Vector2:
	return _direction * (enemy.data as ChargerEnemyData).charge_speed

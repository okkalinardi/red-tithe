class_name StateEnemy
extends Enemy
## An enemy whose behaviour is a [StateMachine]. Each state decides how the
## enemy moves; see res://scenes/enemies/states/.
##
## A scene for a new behaviour inherits enemy.tscn, uses this script, and
## adds a StateMachine node with the states it needs.

@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	super()
	state_machine.setup(self)


func _activate(
	enemy_data: EnemyData,
	at: Vector2,
	target_node: Node2D,
	hp_multiplier: float,
	damage_multiplier_value: float,
) -> void:
	super(enemy_data, at, target_node, hp_multiplier, damage_multiplier_value)
	state_machine.start()


func _get_desired_velocity(delta: float) -> Vector2:
	state_machine.physics_update(delta)
	var state: EnemyState = state_machine.current as EnemyState
	return state.get_velocity() if state != null else Vector2.ZERO


# States choose the animation and the facing themselves.
func _update_animation() -> void:
	pass

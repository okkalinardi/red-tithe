class_name StateMachine
extends Node
## A small finite state machine. Its child [State] nodes are the states.
##
## It does not run by itself: its owner calls [method setup] once,
## [method start] to begin (and to begin again after pooling), and
## [method physics_update] every physics frame. That keeps the order of
## updates in the owner's hands.
## [codeblock]
## state_machine.setup(self)
## state_machine.start()
## state_machine.physics_update(delta)
## [/codeblock]

signal state_changed(previous: State, current: State)

## The state [method start] enters.
@export var initial_state: State

## Whatever the states control, usually the machine's parent.
var actor: Node
var current: State
## Seconds since the current state was entered.
var time_in_state: float = 0.0


func setup(actor_node: Node) -> void:
	actor = actor_node
	for child: Node in get_children():
		var state: State = child as State
		if state != null:
			state.machine = self


## Enters the initial state, leaving the current one first if there is one.
func start() -> void:
	if initial_state == null:
		push_error("StateMachine '%s' has no initial state." % get_path())
		return
	_switch(initial_state)


func physics_update(delta: float) -> void:
	if current == null:
		return
	time_in_state += delta
	current.physics_update(delta)


func transition_to(state: State) -> void:
	if state == null:
		push_error("StateMachine '%s': transition to a missing state." % get_path())
		return
	_switch(state)


## The current state's node name, or an empty name before [method start].
func get_state_name() -> StringName:
	return current.name if current != null else &""


func _switch(state: State) -> void:
	var previous: State = current
	if previous != null:
		previous.exit()
	current = state
	time_in_state = 0.0
	current.enter(previous)
	state_changed.emit(previous, current)

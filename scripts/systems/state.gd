class_name State
extends Node
## One state of a [StateMachine]. Extend it and override the methods you need.
##
## A state is a child node of its machine. Wire states together in the
## scene with exported references (for example a next_state property), or
## jump by name with [method transition_to].

## The machine this state belongs to. Set by the machine.
var machine: StateMachine


## Called when the machine switches to this state. [param _previous] is null
## when the machine starts.
func enter(_previous: State) -> void:
	pass


## Called when the machine leaves this state.
func exit() -> void:
	pass


## Called every physics frame while this is the current state.
func physics_update(_delta: float) -> void:
	pass


## Seconds since this state was entered.
func get_time_in_state() -> float:
	return machine.time_in_state


func transition_to(state: State) -> void:
	machine.transition_to(state)

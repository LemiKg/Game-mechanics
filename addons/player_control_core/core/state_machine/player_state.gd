class_name PlayerState
extends Node
## Abstract base class for player states.
##
## States handle specific player behaviors (grounded, airborne, UI).
## Override virtual methods to implement state-specific logic.


## Reference to the owning state machine. Set automatically.
var state_machine: PlayerStateMachine

## Reference to the player controller (via state machine).
var controller: BasePlayerController3D:
	get:
		return state_machine.controller if state_machine else null

## Reference to the motor (via controller).
var motor: PlayerMotor3D:
	get:
		return controller.motor if controller else null

## Reference to the input router (via controller).
var input_router: PlayerInputRouter3D:
	get:
		return controller.input_router if controller else null


## Called when entering this state.
func enter() -> void:
	pass


## Called when exiting this state.
func exit() -> void:
	pass


## Called every physics frame while active.
func physics_update(delta: float) -> void:
	pass


## Called every frame while active.
func frame_update(delta: float) -> void:
	pass


## Handle input events. Return true if consumed.
func handle_input(event: InputEvent) -> bool:
	return false


## Request transition to another state by name.
func transition_to(state_name: StringName) -> void:
	if state_machine:
		state_machine.transition_to(state_name)

class_name PlayerState
extends Node
## Abstract base class for player states.
##
## States handle specific player behaviors (grounded, airborne, UI).
## Override virtual methods to implement state-specific logic.


## Emitted when an animation should play. Connect an AnimationController to this.
signal animation_requested(animation_name: StringName, blend_time: float)


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

## Reference to movement settings (via controller).
var movement_settings: MovementSettings3D:
	get:
		return controller.movement_settings if controller else null


## Request an animation to play. Override blend_time for custom transitions.
func request_animation(anim_name: StringName, blend_time: float = 0.2) -> void:
	animation_requested.emit(anim_name, blend_time)


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

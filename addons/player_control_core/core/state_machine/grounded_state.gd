class_name GroundedState
extends PlayerState
## Active when the player is on the floor.
##
## Handles walking, sprinting, crouching, and jumping.
## Transitions to Airborne when jump or falling.


## Whether currently sprinting.
var is_sprinting: bool = false

## Whether currently crouching.
var is_crouching: bool = false


func enter() -> void:
	is_sprinting = false
	is_crouching = false
	if motor:
		motor.set_walk_speed()


func exit() -> void:
	is_sprinting = false
	is_crouching = false


func physics_update(delta: float) -> void:
	if not motor or not input_router:
		return
	
	# Check if we fell off a ledge
	if not motor.is_grounded:
		transition_to(&"airborne")
		return
	
	# Handle sprint/crouch modifiers
	_update_movement_modifiers()
	
	# Handle jump
	if input_router.jump_pressed:
		if motor.try_jump():
			transition_to(&"airborne")
			return


func _update_movement_modifiers() -> void:
	if not input_router or not motor:
		return
	
	# Crouch takes priority (can't sprint while crouching)
	is_crouching = input_router.crouch_held
	is_sprinting = input_router.sprint_held and not is_crouching
	
	# Update motor speed based on modifiers
	if is_crouching:
		motor.set_crouch_speed()
	elif is_sprinting:
		motor.set_sprint_speed()
	else:
		motor.set_walk_speed()

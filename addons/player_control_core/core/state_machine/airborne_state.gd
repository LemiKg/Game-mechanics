class_name AirborneState
extends PlayerState
## Active when the player is not on the floor.
##
## Applies gravity and limited air control.
## Transitions to Grounded when landing.


func enter() -> void:
	# Air control uses walk speed as base
	if motor:
		motor.set_walk_speed()


func physics_update(delta: float) -> void:
	if not motor:
		return
	
	# Apply gravity
	motor.apply_gravity(delta)
	
	# Check if landed
	if motor.is_grounded:
		transition_to(&"grounded")
		return

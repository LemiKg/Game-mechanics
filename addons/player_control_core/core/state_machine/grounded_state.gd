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


## Track last animation to avoid redundant requests.
var _current_animation: StringName = &""


func enter() -> void:
	is_sprinting = false
	is_crouching = false
	_current_animation = &""
	if motor:
		motor.set_walk_speed()
	_update_animation()


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
	
	# Handle jump (consume the buffered input)
	if input_router.consume_jump():
		if motor.try_jump():
			request_animation(&"jump", 0.1)
			transition_to(&"airborne")
			return
	
	# Update animation based on movement
	_update_animation()


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


func _update_animation() -> void:
	if not input_router:
		return
	
	var new_animation: StringName
	var has_movement := input_router.movement_intent.length() > 0.1
	
	if is_crouching:
		new_animation = &"crouch_idle" if not has_movement else &"crouch_walk"
	elif is_sprinting and has_movement:
		new_animation = &"run"
	elif has_movement:
		new_animation = &"walk"
	else:
		new_animation = &"idle"
	
	# Only request if animation changed
	if new_animation != _current_animation:
		_current_animation = new_animation
		request_animation(new_animation)

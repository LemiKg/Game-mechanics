class_name AirborneState
extends PlayerState
## Active when the player is not on the floor.
##
## Applies gravity and limited air control.
## Transitions to Grounded when landing.
## Supports coyote time (late jump) and jump buffering.


## Time since leaving the ground (for coyote time).
var _time_since_left_ground: float = 0.0

## Whether coyote jump has been used.
var _coyote_used: bool = false

## Buffered jump request for landing.
var _jump_buffered: bool = false

## Time remaining on jump buffer.
var _jump_buffer_timer: float = 0.0

## Track if we're falling (for animation).
var _is_falling: bool = false


func enter() -> void:
	# Air control uses walk speed as base
	if motor:
		motor.set_walk_speed()
	
	# Reset coyote/buffer state
	_time_since_left_ground = 0.0
	_coyote_used = false
	_jump_buffered = false
	_jump_buffer_timer = 0.0
	_is_falling = false
	
	# Request jump or fall animation based on vertical velocity
	if motor and motor.body:
		if motor.body.velocity.y > 0:
			request_animation(&"jump", 0.1)
		else:
			request_animation(&"fall", 0.2)
			_is_falling = true


func physics_update(delta: float) -> void:
	if not motor:
		return
	
	_time_since_left_ground += delta
	
	# Handle jump input
	if input_router and input_router.consume_jump():
		# Try coyote time jump (jumped late after leaving platform)
		if _can_coyote_jump():
			if motor.try_jump():
				_coyote_used = true
				request_animation(&"jump", 0.1)
				_is_falling = false
		else:
			# Buffer the jump for landing
			_jump_buffered = true
			_jump_buffer_timer = movement_settings.jump_buffer_time if movement_settings else 0.1
	
	# Decay jump buffer timer
	if _jump_buffered:
		_jump_buffer_timer -= delta
		if _jump_buffer_timer <= 0:
			_jump_buffered = false
	
	# Apply gravity
	motor.apply_gravity(delta)
	
	# Transition to fall animation when starting to descend
	if not _is_falling and motor.body and motor.body.velocity.y < 0:
		_is_falling = true
		request_animation(&"fall", 0.2)
	
	# Check if landed
	if motor.is_grounded:
		_on_landed()
		return


func _can_coyote_jump() -> bool:
	if _coyote_used:
		return false
	var coyote := movement_settings.coyote_time if movement_settings else 0.1
	return _time_since_left_ground <= coyote


func _on_landed() -> void:
	# Check if we should execute a buffered jump
	if _jump_buffered:
		if motor.try_jump():
			request_animation(&"jump", 0.1)
			# Stay in airborne state
			_time_since_left_ground = 0.0
			_coyote_used = false
			_jump_buffered = false
			_is_falling = false
			return
	
	# Normal landing - transition to grounded
	request_animation(&"land", 0.1)
	transition_to(&"grounded")

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


func enter() -> void:
	print("[AirborneState] Frame %d: ENTER" % Engine.get_process_frames())
	# Air control uses walk speed as base
	if motor:
		motor.set_walk_speed()
	
	# Reset coyote/buffer state
	_time_since_left_ground = 0.0
	_coyote_used = false
	_jump_buffered = false
	_jump_buffer_timer = 0.0
	
	# Always start with jump animation when entering airborne
	print("[AirborneState] Frame %d: requesting 'jump' animation" % Engine.get_process_frames())
	request_animation(&"jump", 0.05)


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
				request_animation(&"jump", 0.05)
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
	
	# Check if landed (ignore first few frames to let physics settle after jump)
	# At 60 FPS with jump_velocity=4.5, we need at least ~5 frames before we could possibly land
	var min_airtime := 0.1 # 100ms minimum
	if motor.is_grounded and _time_since_left_ground > min_airtime:
		_on_landed()
		return


func _can_coyote_jump() -> bool:
	if _coyote_used:
		return false
	var coyote := movement_settings.coyote_time if movement_settings else 0.1
	return _time_since_left_ground <= coyote


func _on_landed() -> void:
	print("[AirborneState] Frame %d: _on_landed, _jump_buffered=%s" % [Engine.get_process_frames(), _jump_buffered])
	# Check if we should execute a buffered jump
	if _jump_buffered:
		if motor.try_jump():
			print("[AirborneState] Frame %d: buffered jump executed" % Engine.get_process_frames())
			request_animation(&"jump", 0.05)
			# Stay in airborne state
			_time_since_left_ground = 0.0
			_coyote_used = false
			_jump_buffered = false
			return
	
	# Normal landing - request land animation and transition to grounded
	print("[AirborneState] Frame %d: normal landing, requesting 'land' and transitioning to grounded" % Engine.get_process_frames())
	request_animation(&"land", 0.05)
	transition_to(&"grounded")

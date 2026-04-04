class_name AirborneState
extends PlayerState
## Active when the player is not on the floor.
##
## Applies enhanced gravity (snappier falls, variable jump height).
## Supports coyote time, jump buffering, and mantling.


@export_group("Mantling")
## Optional mantle detector for ledge climbing.
@export var mantle_detector: MantleDetector


## Time since leaving the ground (for coyote time).
var _time_since_left_ground: float = 0.0

## Whether coyote jump has been used.
var _coyote_used: bool = false

## Buffered jump request for landing.
var _jump_buffered: bool = false

## Time remaining on jump buffer.
var _jump_buffer_timer: float = 0.0

## Whether the jump button is currently held (for variable jump height).
var _jump_held: bool = false

## Whether we already cut the jump (prevent double-cut).
var _jump_cut_applied: bool = false

## Debug logger for this state.
var _logger := DebugLogger.new("[AirborneState]")


func enter() -> void:
	_logger.debug("ENTER")

	_time_since_left_ground = 0.0
	_coyote_used = false
	_jump_buffered = false
	_jump_buffer_timer = 0.0
	_jump_cut_applied = false

	# Check if jump is currently held (for variable jump height)
	if input_router:
		_jump_held = Input.is_action_pressed(input_router._jump)
	else:
		_jump_held = false

	request_animation(&"jump", 0.05)


func physics_update(delta: float) -> void:
	if not motor:
		return

	_time_since_left_ground += delta

	# Track jump button state for variable jump height
	if input_router:
		var was_held := _jump_held
		_jump_held = Input.is_action_pressed(input_router._jump)

		# Jump release while ascending — cut jump for short hop
		if was_held and not _jump_held and not _jump_cut_applied and motor.body.velocity.y > 0:
			motor.cut_jump()
			_jump_cut_applied = true

	# Handle jump input (coyote time or buffer)
	var jump_input := false
	if input_router:
		jump_input = input_router.consume_jump()
	if not jump_input:
		jump_input = motor.consume_direct_jump()

	if jump_input:
		if _can_coyote_jump():
			if motor.try_jump():
				_coyote_used = true
				_jump_held = true
				_jump_cut_applied = false
				request_animation(&"jump", 0.05)
		else:
			_jump_buffered = true
			_jump_buffer_timer = movement_settings.jump_buffer_time if movement_settings else 0.1

	# Decay jump buffer timer
	if _jump_buffered:
		_jump_buffer_timer -= delta
		if _jump_buffer_timer <= 0:
			_jump_buffered = false

	# Check for mantle
	if _should_check_mantle():
		var ledge_data := mantle_detector.check_for_ledge()
		if not ledge_data.is_empty():
			state_machine.set_meta("mantle_ledge_data", ledge_data)
			transition_to(&"mantle")
			return

	# Apply enhanced gravity (variable jump height + snappy falls)
	motor.apply_gravity_enhanced(delta, _jump_held)

	# Check if landed
	var min_airtime := movement_settings.min_airtime if movement_settings else 0.1
	if motor.is_grounded and _time_since_left_ground > min_airtime:
		_on_landed()
		return


func _should_check_mantle() -> bool:
	if not mantle_detector or not mantle_detector.is_configured():
		return false
	if not input_router:
		return false
	return input_router.movement_intent.y > 0.5


func _can_coyote_jump() -> bool:
	if _coyote_used:
		return false
	var coyote := movement_settings.coyote_time if movement_settings else 0.1
	return _time_since_left_ground <= coyote


func _on_landed() -> void:
	if _jump_buffered:
		if motor.try_jump():
			request_animation(&"jump", 0.05)
			_time_since_left_ground = 0.0
			_coyote_used = false
			_jump_buffered = false
			_jump_held = true
			_jump_cut_applied = false
			return

	request_animation(&"land", 0.05)
	transition_to(&"grounded")

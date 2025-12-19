class_name MantleState
extends PlayerState
## Active when the player is climbing/mantling a ledge.
##
## Uses programmatic position interpolation with optional curve.
## Transitions to Grounded when mantle is complete.


@export_group("References")
## Mantle configuration. Required.
@export var mantle_settings: MantleSettings3D


## Start position when mantle began.
var _start_position: Vector3 = Vector3.ZERO

## Target position on ledge.
var _target_position: Vector3 = Vector3.ZERO

## Time elapsed during mantle.
var _mantle_timer: float = 0.0

## Height of the ledge being mantled.
var _mantle_height: float = 0.0

## Whether this is a high mantle (affects animation).
var _is_high_mantle: bool = false

## Debug logger for this state.
var _logger := DebugLogger.new("[MantleState]")


func enter() -> void:
	_logger.debug("ENTER")
	
	if motor:
		motor.enabled = false # Disable normal movement during mantle
	
	# Get ledge data from state machine meta (set by AirborneState)
	var ledge_data: Dictionary = state_machine.get_meta("mantle_ledge_data", {})
	if ledge_data.is_empty():
		_logger.debug("no ledge data found, aborting mantle")
		transition_to(&"airborne")
		return
	
	_start_position = controller.body.global_position
	_target_position = ledge_data.get("position", Vector3.ZERO)
	_mantle_height = ledge_data.get("height", 1.0)
	_mantle_timer = 0.0
	
	# Determine mantle type based on height
	var threshold := mantle_settings.low_mantle_threshold if mantle_settings else 1.0
	_is_high_mantle = _mantle_height > threshold
	
	# Request appropriate animation
	var anim_name: StringName
	if mantle_settings:
		anim_name = mantle_settings.high_mantle_animation if _is_high_mantle else mantle_settings.low_mantle_animation
	else:
		anim_name = &"high_mantle" if _is_high_mantle else &"low_mantle"
	
	_logger.debugf("starting %s mantle, height=%.2f, target=%s",
		["high" if _is_high_mantle else "low", _mantle_height, _target_position])
	request_animation(anim_name, 0.1)


func exit() -> void:
	_logger.debug("EXIT")
	
	if motor:
		motor.enabled = true # Re-enable movement
	
	# Clean up meta data
	if state_machine.has_meta("mantle_ledge_data"):
		state_machine.remove_meta("mantle_ledge_data")


func physics_update(delta: float) -> void:
	if not controller or not controller.body:
		transition_to(&"grounded")
		return
	
	var duration := mantle_settings.mantle_duration if mantle_settings else 0.5
	_mantle_timer += delta
	var progress := _mantle_timer / duration
	
	# Check if mantle is complete
	if progress >= 1.0:
		controller.body.global_position = _target_position
		_zero_velocity()
		_logger.debug("mantle complete, transitioning to grounded")
		transition_to(&"grounded")
		return
	
	# Apply curve if available
	var curved_progress := progress
	if mantle_settings and mantle_settings.mantle_curve:
		curved_progress = mantle_settings.mantle_curve.sample(progress)
	
	# Interpolate position
	var current_pos := _start_position.lerp(_target_position, curved_progress)
	
	# Add arc for visual appeal
	var arc_factor := mantle_settings.arc_height_factor if mantle_settings else 0.3
	var arc_height := _mantle_height * arc_factor * sin(progress * PI)
	current_pos.y += arc_height
	
	controller.body.global_position = current_pos


func _zero_velocity() -> void:
	if not controller or not controller.body:
		return
	
	# Zero velocity based on body type
	if controller.body.has_method("move_and_slide"):
		# CharacterBody3D
		controller.body.velocity = Vector3.ZERO
	elif "linear_velocity" in controller.body:
		# RigidBody3D
		controller.body.linear_velocity = Vector3.ZERO

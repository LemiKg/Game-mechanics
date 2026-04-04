class_name DodgeState
extends PlayerState
## Committed dodge/roll action.
##
## On enter: consumes stamina, locks movement direction, plays roll animation.
## During: moves body at dodge_speed in locked direction. Motor is disabled.
## Optional invincibility frames during a configurable window of the dodge.
## On exit: re-enables motor, transitions to grounded or airborne.


## Emitted when invincibility frames start.
signal iframes_started()

## Emitted when invincibility frames end.
signal iframes_ended()


@export_group("Settings")
## Dodge movement speed.
@export_range(1.0, 20.0, 0.5) var dodge_speed: float = 8.0

## Total dodge duration in seconds.
@export_range(0.1, 2.0, 0.05) var dodge_duration: float = 0.6

## Normalized start time for invincibility frames (0-1 of duration).
@export_range(0.0, 1.0, 0.05) var iframes_start: float = 0.1

## Normalized end time for invincibility frames (0-1 of duration).
@export_range(0.0, 1.0, 0.05) var iframes_end: float = 0.5

@export_group("References")
## Optional stamina component. If set, dodge consumes stamina.
@export var stamina_component: Node


## Locked dodge direction (set on enter).
var _dodge_direction: Vector3 = Vector3.ZERO

## Timer tracking dodge progress.
var _dodge_timer: float = 0.0

## Whether currently in invincibility frames.
var _in_iframes: bool = false

## Debug logger.
var _logger := DebugLogger.new("[DodgeState]")


func enter() -> void:
	_logger.debug("ENTER")
	_dodge_timer = 0.0
	_in_iframes = false

	if not motor or not controller or not controller.body:
		transition_to(&"grounded")
		return

	# Determine dodge direction from input — requires directional input
	var dodge_dir := Vector3.ZERO
	if input_router:
		var input := input_router.movement_intent
		if input.length() > 0.1:
			dodge_dir = (motor.movement_basis.x * input.x + motor.movement_basis.z * input.y).normalized()

	if dodge_dir.length() < 0.1:
		# No direction held — cancel dodge, return to grounded
		if motor:
			motor.enabled = true
		transition_to(&"grounded")
		return

	_dodge_direction = dodge_dir.normalized()
	_dodge_direction.y = 0.0

	# Rotate body to face dodge direction (third-person only).
	# In first-person the body IS the camera yaw node — rotating it
	# would jerk the view away from where the player is looking.
	if controller is DualPerspectiveController3D and controller.is_third_person():
		controller.body.rotation.y = atan2(_dodge_direction.x, _dodge_direction.z)

	# Disable motor — we control movement directly
	motor.enabled = false

	# Zero vertical velocity to prevent floating dodges
	if controller.body.has_method("move_and_slide"):
		controller.body.velocity = _dodge_direction * dodge_speed

	request_animation(&"dodge", 0.05)


func exit() -> void:
	_logger.debug("EXIT")

	if motor:
		motor.enabled = true

	# End iframes if still active
	if _in_iframes:
		_in_iframes = false
		iframes_ended.emit()


func physics_update(delta: float) -> void:
	if not controller or not controller.body:
		transition_to(&"grounded")
		return

	_dodge_timer += delta
	var progress := _dodge_timer / dodge_duration

	# Check if dodge is complete
	if progress >= 1.0:
		_finish_dodge()
		return

	# Update invincibility frames
	_update_iframes(progress)

	# Apply dodge movement with easeout in final 30%
	if controller.body.has_method("move_and_slide"):
		var gravity := movement_settings.gravity if movement_settings else 9.8
		var speed_factor := 1.0
		if progress > 0.7:
			# Ease out speed in the last 30% of the dodge
			speed_factor = (1.0 - progress) / 0.3
		var current_dodge_speed := dodge_speed * speed_factor
		controller.body.velocity.x = _dodge_direction.x * current_dodge_speed
		controller.body.velocity.z = _dodge_direction.z * current_dodge_speed
		controller.body.velocity.y -= gravity * delta
		controller.body.move_and_slide()


func _update_iframes(progress: float) -> void:
	var should_be_in_iframes := progress >= iframes_start and progress < iframes_end

	if should_be_in_iframes and not _in_iframes:
		_in_iframes = true
		iframes_started.emit()
	elif not should_be_in_iframes and _in_iframes:
		_in_iframes = false
		iframes_ended.emit()


func _finish_dodge() -> void:
	# Request the next movement animation immediately to prevent T-pose flash.
	# Determine what animation should play based on input state.
	# Blend times match the AnimationTree xfade_time on roll exit transitions.
	if input_router and input_router.movement_intent.length() > 0.1:
		if input_router.sprint_held:
			request_animation(&"run", 0.35)
		else:
			request_animation(&"walk", 0.4)
	else:
		request_animation(&"idle", 0.45)

	# Determine next state based on ground check
	if motor and motor.is_grounded:
		transition_to(&"grounded")
	else:
		transition_to(&"airborne")

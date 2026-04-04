class_name GroundedState
extends PlayerState
## Active when the player is on the floor.
##
## Handles gait selection (walk/run/sprint), stance (stand/crouch),
## jumping, and rotate-in-place. Transitions to Airborne when jumping or falling.


## Track last animation to avoid redundant requests.
var _current_animation: StringName = &""

## Grace period after landing to ignore brief "not grounded" moments.
var _landing_grace_timer: float = 0.0

## Whether we just landed (skip immediate animation update).
var _just_landed: bool = false

## Whether currently in a rotate-in-place turn.
var _is_rotating_in_place: bool = false

## Target yaw for rotate-in-place.
var _rotation_target: float = 0.0

## Debug logger for this state.
var _logger := DebugLogger.new("[GroundedState]")


func enter() -> void:
	_logger.debug("ENTER")
	_current_animation = &""
	_is_rotating_in_place = false
	if motor:
		motor.gait = PlayerMotor3D.Gait.RUN
		motor.stance = PlayerMotor3D.Stance.STANDING

	var grace_time := movement_settings.landing_grace_time if movement_settings else 0.5
	_landing_grace_timer = grace_time
	_just_landed = true


func exit() -> void:
	_is_rotating_in_place = false


func physics_update(delta: float) -> void:
	if not motor or not input_router:
		return

	# Countdown landing grace period
	if _landing_grace_timer > 0:
		_landing_grace_timer -= delta
		var has_movement := input_router.movement_intent.length() > 0.3
		if has_movement and _landing_grace_timer < 0.35:
			_landing_grace_timer = 0

		if _landing_grace_timer <= 0:
			_just_landed = false
			_update_animation()

	# Check if we fell off a ledge
	if not motor.is_grounded and _landing_grace_timer <= 0:
		transition_to(&"airborne")
		return

	# Update gait and stance from input
	_update_movement_modifiers()

	# Rotate-in-place
	if movement_settings and movement_settings.enable_rotate_in_place:
		if not motor.is_moving:
			_check_rotate_in_place(delta)
		else:
			_is_rotating_in_place = false

	# Handle jump
	var jump_consumed := input_router.consume_jump() or motor.consume_direct_jump()
	if jump_consumed:
		if motor.try_jump():
			request_animation(&"jump", 0.1)
			transition_to(&"airborne")
			return

	# Update animation
	if not _just_landed:
		_update_animation()


func _update_movement_modifiers() -> void:
	if not input_router or not motor:
		return

	# Stance: crouch input
	if input_router.crouch_held:
		motor.stance = PlayerMotor3D.Stance.CROUCHING
	else:
		motor.stance = PlayerMotor3D.Stance.STANDING

	# Gait: sprint takes priority, cannot sprint while crouching
	if input_router.sprint_held and motor.stance != PlayerMotor3D.Stance.CROUCHING:
		motor.gait = PlayerMotor3D.Gait.SPRINT
	else:
		motor.gait = PlayerMotor3D.Gait.RUN


func _update_animation() -> void:
	if not input_router or not motor:
		return

	var new_animation: StringName
	var has_movement := input_router.movement_intent.length() > 0.1

	if motor.stance == PlayerMotor3D.Stance.CROUCHING:
		new_animation = &"crouch_idle" if not has_movement else &"crouch_walk"
	elif motor.gait == PlayerMotor3D.Gait.SPRINT and has_movement:
		new_animation = &"run"
	elif has_movement:
		new_animation = &"walk"
	else:
		new_animation = &"idle"

	if new_animation != _current_animation:
		_current_animation = new_animation
		request_animation(new_animation)


func _check_rotate_in_place(delta: float) -> void:
	var body_node := controller.body
	if not body_node:
		return

	var camera_yaw := _get_camera_yaw()
	var body_yaw := body_node.rotation.y
	var angle_diff := rad_to_deg(angle_difference(body_yaw, camera_yaw))
	var threshold := movement_settings.rotation_threshold_degrees

	if abs(angle_diff) > threshold and not _is_rotating_in_place:
		_is_rotating_in_place = true
		_rotation_target = camera_yaw
		var anim_name: StringName
		if angle_diff < 0:
			anim_name = movement_settings.turn_left_animation
		else:
			anim_name = movement_settings.turn_right_animation
		request_animation(anim_name, 0.1)
		_current_animation = anim_name

	if _is_rotating_in_place:
		var rotation_speed := deg_to_rad(movement_settings.rotation_in_place_speed)
		body_node.rotation.y = rotate_toward(body_node.rotation.y, _rotation_target, rotation_speed * delta)
		if abs(angle_difference(body_node.rotation.y, _rotation_target)) < deg_to_rad(5.0):
			_is_rotating_in_place = false
			request_animation(&"idle", 0.2)
			_current_animation = &"idle"


func _get_camera_yaw() -> float:
	if controller.has_method("get_camera_yaw"):
		return controller.get_camera_yaw()
	return 0.0

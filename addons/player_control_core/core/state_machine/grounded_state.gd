class_name GroundedState
extends PlayerState
## Active when the player is on the floor.
##
## Handles walking, sprinting, crouching, jumping, and rotate-in-place.
## Transitions to Airborne when jump or falling.


## Whether currently sprinting.
var is_sprinting: bool = false

## Whether currently crouching.
var is_crouching: bool = false


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
	is_sprinting = false
	is_crouching = false
	_current_animation = &""
	_is_rotating_in_place = false
	if motor:
		motor.set_walk_speed()
	
	# Check if we're landing (land animation was requested before entering)
	# Give a grace period to let Jump_Land animation play
	# Jump_Start → Jump → Jump_Land takes time in the AnimationTree
	var grace_time := movement_settings.landing_grace_time if movement_settings else 0.5
	_landing_grace_timer = grace_time
	_just_landed = true
	_logger.debugf("starting landing grace period (%ss)", [grace_time])


func exit() -> void:
	is_sprinting = false
	is_crouching = false
	_is_rotating_in_place = false


func physics_update(delta: float) -> void:
	if not motor or not input_router:
		return
	
	# Countdown landing grace period
	if _landing_grace_timer > 0:
		_landing_grace_timer -= delta
		
		# Allow early cancel if player starts moving significantly
		var has_movement := input_router.movement_intent.length() > 0.3
		if has_movement and _landing_grace_timer < 0.35:
			# Player wants to move - end grace early (after minimum 150ms)
			_logger.debug("landing grace cancelled by movement")
			_landing_grace_timer = 0
		
		if _landing_grace_timer <= 0:
			_logger.debug("landing grace period ended")
			_just_landed = false
			# Now update animation based on current movement
			_update_animation()
	
	# Check if we fell off a ledge (skip during landing grace period)
	if not motor.is_grounded and _landing_grace_timer <= 0:
		_logger.debug("fell off ledge, transitioning to airborne")
		transition_to(&"airborne")
		return
	
	# Handle sprint/crouch modifiers
	_update_movement_modifiers()
	
	# Check for rotate-in-place (only when not moving and enabled)
	if movement_settings and movement_settings.enable_rotate_in_place:
		if not motor.is_moving:
			_check_rotate_in_place(delta)
		else:
			_is_rotating_in_place = false
	
	# Handle jump (consume the buffered input)
	if input_router.consume_jump():
		_logger.debug("jump consumed, trying jump")
		if motor.try_jump():
			_logger.debug("jump succeeded, requesting 'jump' anim and transitioning")
			request_animation(&"jump", 0.1)
			transition_to(&"airborne")
			return
	
	# Update animation based on movement (skip during landing grace)
	if not _just_landed:
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
		_logger.debugf("animation changed '%s' -> '%s'", [_current_animation, new_animation])
		_current_animation = new_animation
		request_animation(new_animation)


func _check_rotate_in_place(delta: float) -> void:
	var body := controller.body
	if not body:
		return
	
	var camera_yaw := _get_camera_yaw()
	var body_yaw := body.rotation.y
	
	var angle_diff := rad_to_deg(angle_difference(body_yaw, camera_yaw))
	var threshold := movement_settings.rotation_threshold_degrees
	
	# Check if we should start rotating
	if abs(angle_diff) > threshold and not _is_rotating_in_place:
		_is_rotating_in_place = true
		_rotation_target = camera_yaw
		
		# Request turn animation
		var anim_name: StringName
		if angle_diff < 0:
			anim_name = movement_settings.turn_left_animation
		else:
			anim_name = movement_settings.turn_right_animation
		
		_logger.debugf("starting rotate-in-place, angle_diff=%.1f, anim=%s", [angle_diff, anim_name])
		request_animation(anim_name, 0.1)
		_current_animation = anim_name
	
	# Perform rotation if in rotate-in-place mode
	if _is_rotating_in_place:
		var rotation_speed := deg_to_rad(movement_settings.rotation_in_place_speed)
		body.rotation.y = rotate_toward(body.rotation.y, _rotation_target, rotation_speed * delta)
		
		# Check if rotation is complete
		if abs(angle_difference(body.rotation.y, _rotation_target)) < deg_to_rad(5.0):
			_is_rotating_in_place = false
			_logger.debug("rotate-in-place complete")
			request_animation(&"idle", 0.2)
			_current_animation = &"idle"


func _get_camera_yaw() -> float:
	# Get camera yaw from controller if available
	if controller.has_method("get_camera_yaw"):
		return controller.get_camera_yaw()
	return 0.0

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

## Whether the player wants to stand but can't (ceiling above).
var _wants_to_stand: bool = false

## Whether the player was moving last frame (for stop detection).
var _was_moving: bool = false

## Debug logger for this state.
var _logger := DebugLogger.new("[GroundedState]")

@export_group("Crouch")
## The capsule collision shape to resize when crouching.
@export var collision_shape: CollisionShape3D

@export_group("Stamina")
## Optional stamina component for sprint drain and dodge cost.
@export var stamina_component: Node


func enter() -> void:
	_logger.debug("ENTER")
	_current_animation = &""
	_is_rotating_in_place = false
	_was_moving = false
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

	# Drain stamina while sprinting
	if motor.gait == PlayerMotor3D.Gait.SPRINT and motor.is_moving:
		if stamina_component and stamina_component.has_method("drain"):
			if not stamina_component.drain(stamina_component.sprint_drain, delta):
				motor.gait = PlayerMotor3D.Gait.RUN  # Stamina depleted, force run

	# Rotate-in-place
	if movement_settings and movement_settings.enable_rotate_in_place:
		if not motor.is_moving:
			_check_rotate_in_place(delta)
		else:
			_is_rotating_in_place = false

	# Handle dodge input
	if input_router.consume_dodge():
		if _can_dodge():
			if stamina_component and stamina_component.has_method("try_consume"):
				stamina_component.try_consume(stamina_component.dodge_cost)
			transition_to(&"dodge")
			return

	# Handle jump
	var jump_consumed := input_router.consume_jump() or motor.consume_direct_jump()
	if jump_consumed:
		if motor.try_jump():
			transition_to(&"airborne")
			return

	# Update crouch collision shape
	_update_crouch_collision(delta)

	# Recheck standing if blocked by ceiling
	if _wants_to_stand and _check_can_stand():
		motor.stance = PlayerMotor3D.Stance.STANDING
		_wants_to_stand = false

	# Update animation
	if not _just_landed:
		_update_animation()


func _update_movement_modifiers() -> void:
	if not input_router or not motor:
		return

	# Stance: crouch input with head-bonk detection
	if input_router.crouch_held:
		motor.stance = PlayerMotor3D.Stance.CROUCHING
		_wants_to_stand = false
	elif motor.stance == PlayerMotor3D.Stance.CROUCHING:
		# Want to stand — check for ceiling
		if _check_can_stand():
			motor.stance = PlayerMotor3D.Stance.STANDING
			_wants_to_stand = false
		else:
			_wants_to_stand = true

	# Gait: sprint takes priority, cannot sprint while crouching
	# Sprint requires stamina if stamina component is present
	var can_sprint := input_router.sprint_held and motor.stance != PlayerMotor3D.Stance.CROUCHING
	if can_sprint and stamina_component and stamina_component.has_method("can_sprint"):
		can_sprint = stamina_component.can_sprint()

	if can_sprint:
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
		# Stop prediction: if we were moving and now stopped, play stop anim
		if _was_moving and motor.is_moving:
			# Still decelerating — predict time to stop
			var gait_data := motor.get_current_gait_data()
			var speed := Vector2(motor.actual_velocity.x, motor.actual_velocity.z).length()
			var time_to_stop := speed / maxf(gait_data.deceleration, 1.0)
			if time_to_stop < 0.3:
				new_animation = &"stop"
			else:
				new_animation = &"idle"
		else:
			new_animation = &"idle"

	_was_moving = has_movement

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


func _can_dodge() -> bool:
	if not state_machine.has_state(&"dodge"):
		return false
	if stamina_component and stamina_component.has_method("can_dodge"):
		return stamina_component.can_dodge()
	return true  # Allow dodge if no stamina component


func _update_crouch_collision(delta: float) -> void:
	if not collision_shape or not collision_shape.shape is CapsuleShape3D:
		return
	if not movement_settings:
		return

	var capsule: CapsuleShape3D = collision_shape.shape
	var target_height: float
	var speed := movement_settings.crouch_transition_speed if "crouch_transition_speed" in movement_settings else 10.0

	if motor.stance == PlayerMotor3D.Stance.CROUCHING:
		target_height = movement_settings.crouch_height
	else:
		target_height = movement_settings.stand_height

	# Lerp capsule height
	capsule.height = lerpf(capsule.height, target_height, speed * delta)

	# Adjust capsule center position so feet stay planted
	collision_shape.position.y = capsule.height * 0.5


func _check_can_stand() -> bool:
	if not controller or not controller.body:
		return true
	if not movement_settings:
		return true

	# Raycast upward from current position to check for ceiling
	var space_state := controller.body.get_world_3d().direct_space_state
	var origin := controller.body.global_position + Vector3.UP * movement_settings.crouch_height
	var margin := movement_settings.crouch_clearance_margin if "crouch_clearance_margin" in movement_settings else 0.1
	var check_distance := movement_settings.stand_height - movement_settings.crouch_height + margin

	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + Vector3.UP * check_distance
	)
	query.exclude = [controller.body.get_rid()]
	var result := space_state.intersect_ray(query)

	return result.is_empty()  # Can stand if nothing above

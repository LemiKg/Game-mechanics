class_name DualPerspectiveController3D
extends BasePlayerController3D
## Player controller supporting both first-person and third-person perspectives.
##
## Can toggle between FPS and third-person views at runtime.
## Both perspectives share the same state machine and movement settings.


## Emitted when perspective changes.
signal perspective_changed(is_first_person: bool)
## Emitted when lock-on target is acquired.
signal lock_on_started(target: Node3D)
## Emitted when lock-on is released.
signal lock_on_ended()

## Perspective modes.
enum Perspective {
	FIRST_PERSON,
	THIRD_PERSON
}

## Character rotation modes for third-person.
enum RotationMode {
	FACE_MOVEMENT, ## Body rotates to face movement direction
	STRAFE, ## Body faces camera direction
	FREE, ## No automatic rotation
	AIMING, ## Precision strafe with FOV zoom and tighter rotation
	LOCK_ON ## Face locked target node
}


@export_group("Perspective")
## Current perspective mode.
@export var perspective: Perspective = Perspective.FIRST_PERSON:
	set(value):
		var changed := perspective != value
		perspective = value
		if changed and is_inside_tree():
			_apply_perspective()

## Input action to toggle perspective (optional).
@export var toggle_action: StringName = &"toggle_perspective"

@export_group("First-Person Components")
## Look controller for FPS yaw/pitch camera.
@export var fps_look_controller: PlayerLookController3D
## The node for pitch rotation (FPS camera pivot).
@export var fps_pitch_pivot: Node3D
## The first-person camera.
@export var fps_camera: Camera3D

@export_group("Third-Person Components")
## Orbit camera controller for third-person view.
@export var orbit_camera_controller: OrbitCameraController3D
## The third-person camera (child of orbit controller).
@export var third_person_camera: Camera3D

@export_group("First-Person Settings")
## Look settings for FPS mode.
@export var fps_look_settings: FPSLookSettings3D:
	set(value):
		fps_look_settings = value
		if fps_look_controller:
			fps_look_controller.look_settings = value
			fps_look_controller.refresh_settings()

@export_group("Third-Person Settings")
## Camera settings for third-person mode.
@export var orbit_camera_settings: OrbitCameraSettings3D:
	set(value):
		orbit_camera_settings = value
		if orbit_camera_controller:
			orbit_camera_controller.camera_settings = value
			orbit_camera_controller.refresh_settings()

## How the character rotates in third-person.
@export var rotation_mode: RotationMode = RotationMode.FACE_MOVEMENT

## Speed at which character rotates to face movement direction.
@export_range(1.0, 30.0, 0.5) var rotation_speed: float = 10.0

## Character mesh to show/hide based on perspective.
@export var character_mesh: Node3D

@export_group("Aiming Mode")
## FOV when aiming (zoomed in).
@export_range(20.0, 90.0, 1.0) var aiming_fov: float = 50.0
## Rotation speed when aiming (tighter control).
@export_range(5.0, 50.0, 1.0) var aiming_rotation_speed: float = 20.0
## Speed of FOV transition when entering/exiting aiming.
@export_range(1.0, 30.0, 1.0) var aiming_fov_transition_speed: float = 10.0

@export_group("Lock-On Mode")
## Current lock-on target (set via set_lock_on_target).
@export var lock_on_target: Node3D
## Rotation speed when locked on.
@export_range(5.0, 30.0, 1.0) var lock_on_rotation_speed: float = 15.0
## Maximum distance before lock-on breaks.
@export_range(5.0, 100.0, 1.0) var max_lock_on_distance: float = 20.0
## Automatically break lock-on when target is too far.
@export var auto_break_lock_on: bool = true

@export_group("Body Tilt")
## Enable body tilt toward movement direction (third-person only).
@export var enable_body_tilt: bool = false
## Maximum tilt angle in degrees.
@export_range(0.0, 15.0, 0.5) var tilt_amount: float = 5.0
## Speed of tilt interpolation.
@export_range(1.0, 30.0, 1.0) var tilt_speed: float = 10.0


## Default FOV for restoring after aiming.
var _default_fov: float = 75.0


func _ready() -> void:
	super._ready()
	_validate_perspective_dependencies()
	_wire_perspective_components()
	_apply_perspective()
	# Cache default FOV
	if third_person_camera:
		_default_fov = third_person_camera.fov


func _validate_perspective_dependencies() -> void:
	if not fps_look_controller:
		push_warning("DualPerspectiveController3D: 'fps_look_controller' not assigned.")
	if not fps_pitch_pivot:
		push_warning("DualPerspectiveController3D: 'fps_pitch_pivot' not assigned.")
	if not fps_camera:
		push_warning("DualPerspectiveController3D: 'fps_camera' not assigned.")
	if not orbit_camera_controller:
		push_warning("DualPerspectiveController3D: 'orbit_camera_controller' not assigned.")
	if not third_person_camera:
		push_warning("DualPerspectiveController3D: 'third_person_camera' not assigned.")


func _wire_perspective_components() -> void:
	# Wire FPS look controller
	if fps_look_controller:
		if body:
			fps_look_controller.yaw_node = body
		if fps_pitch_pivot:
			fps_look_controller.pitch_node = fps_pitch_pivot
		if input_router:
			fps_look_controller.input_router = input_router
		if fps_look_settings:
			fps_look_controller.look_settings = fps_look_settings
			fps_look_controller.refresh_settings()
	
	# Wire orbit camera controller
	if orbit_camera_controller:
		if input_router:
			orbit_camera_controller.input_router = input_router
		if orbit_camera_settings:
			orbit_camera_controller.camera_settings = orbit_camera_settings
			orbit_camera_controller.refresh_settings()


func _unhandled_input(event: InputEvent) -> void:
	# Handle perspective toggle
	if toggle_action and event.is_action_pressed(toggle_action):
		toggle_perspective()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Handle character rotation in third-person
	if perspective == Perspective.THIRD_PERSON:
		if body and motor and rotation_mode != RotationMode.FREE:
			_update_character_rotation(delta)
		
		# Handle body tilt in third-person
		if enable_body_tilt and character_mesh and motor:
			_update_body_tilt(delta)


## Toggle between first-person and third-person perspectives.
func toggle_perspective() -> void:
	if perspective == Perspective.FIRST_PERSON:
		set_perspective(Perspective.THIRD_PERSON)
	else:
		set_perspective(Perspective.FIRST_PERSON)


## Set the perspective mode.
func set_perspective(new_perspective: Perspective) -> void:
	perspective = new_perspective


## Check if currently in first-person mode.
func is_first_person() -> bool:
	return perspective == Perspective.FIRST_PERSON


## Check if currently in third-person mode.
func is_third_person() -> bool:
	return perspective == Perspective.THIRD_PERSON


func _apply_perspective() -> void:
	var is_fps := perspective == Perspective.FIRST_PERSON
	
	# Enable/disable appropriate camera controllers
	if fps_look_controller:
		fps_look_controller.enabled = is_fps and _gameplay_enabled
	if orbit_camera_controller:
		orbit_camera_controller.enabled = not is_fps and _gameplay_enabled
	
	# Switch active cameras
	if fps_camera:
		fps_camera.current = is_fps
	if third_person_camera:
		third_person_camera.current = not is_fps
	
	# Show/hide character mesh (hide in FPS to avoid seeing inside model)
	if character_mesh:
		character_mesh.visible = not is_fps
	
	# Sync yaw between perspectives for smooth transition
	_sync_camera_angles()
	
	perspective_changed.emit(is_fps)


func _sync_camera_angles() -> void:
	# When switching perspectives, sync the yaw angle
	if perspective == Perspective.FIRST_PERSON:
		# Switching to FPS: use orbit camera's yaw
		if orbit_camera_controller and fps_look_controller:
			fps_look_controller.yaw = orbit_camera_controller.yaw
			fps_look_controller.pitch = clamp(
				orbit_camera_controller.pitch,
				fps_look_controller._min_pitch,
				fps_look_controller._max_pitch
			)
			if body:
				body.rotation.y = orbit_camera_controller.yaw
	else:
		# Switching to third-person: use FPS look controller's yaw
		if fps_look_controller and orbit_camera_controller:
			orbit_camera_controller.yaw = fps_look_controller.yaw
			orbit_camera_controller.pitch = clamp(
				fps_look_controller.pitch,
				orbit_camera_controller._min_pitch,
				orbit_camera_controller._max_pitch
			)


## Movement basis depends on current perspective.
func _get_movement_basis() -> Basis:
	if perspective == Perspective.FIRST_PERSON:
		# FPS: body-relative movement
		return body.global_transform.basis if body else Basis.IDENTITY
	else:
		# Third-person: camera-relative movement
		if orbit_camera_controller and orbit_camera_controller.camera:
			var cam_basis := orbit_camera_controller.camera.global_transform.basis
			
			# Flatten camera forward to horizontal plane
			# Camera's -Z is its forward direction
			var forward := -cam_basis.z
			forward.y = 0
			forward = forward.normalized()
			
			var right := cam_basis.x
			right.y = 0
			right = right.normalized()
			
			# Construct basis: X=right, Y=up, Z=back (so -Z = forward)
			# forward is camera's forward, so -forward is back (Z axis)
			return Basis(right, Vector3.UP, -forward)
		
		return body.global_transform.basis if body else Basis.IDENTITY


func _update_character_rotation(delta: float) -> void:
	var target_rotation: float = body.rotation.y
	var current_rotation_speed := rotation_speed
	
	match rotation_mode:
		RotationMode.FACE_MOVEMENT:
			if motor.is_moving:
				var move_dir := motor.actual_velocity
				move_dir.y = 0
				if move_dir.length() > 0.1:
					target_rotation = atan2(move_dir.x, move_dir.z)
			else:
				return # No rotation when stationary
		
		RotationMode.STRAFE:
			if orbit_camera_controller:
				target_rotation = orbit_camera_controller.yaw
		
		RotationMode.FREE:
			return # No rotation
		
		RotationMode.AIMING:
			if orbit_camera_controller:
				target_rotation = orbit_camera_controller.yaw
				current_rotation_speed = aiming_rotation_speed
				_update_aiming_fov(delta)
		
		RotationMode.LOCK_ON:
			if _is_lock_on_valid():
				var to_target := lock_on_target.global_position - body.global_position
				to_target.y = 0
				if to_target.length() > 0.1:
					target_rotation = atan2(to_target.x, to_target.z)
				current_rotation_speed = lock_on_rotation_speed
			else:
				_break_lock_on()
				return
	
	# Smooth rotation
	body.rotation.y = lerp_angle(body.rotation.y, target_rotation, current_rotation_speed * delta)


func _update_aiming_fov(delta: float) -> void:
	if not third_person_camera:
		return
	var target_fov := aiming_fov if rotation_mode == RotationMode.AIMING else _default_fov
	third_person_camera.fov = lerp(third_person_camera.fov, target_fov, aiming_fov_transition_speed * delta)


func _is_lock_on_valid() -> bool:
	if not lock_on_target or not is_instance_valid(lock_on_target):
		return false
	if auto_break_lock_on and body:
		var distance := body.global_position.distance_to(lock_on_target.global_position)
		return distance <= max_lock_on_distance
	return true


func _break_lock_on() -> void:
	lock_on_target = null
	rotation_mode = RotationMode.FACE_MOVEMENT
	lock_on_ended.emit()


## Set a lock-on target and switch to lock-on mode.
func set_lock_on_target(target: Node3D) -> void:
	lock_on_target = target
	if target:
		rotation_mode = RotationMode.LOCK_ON
		lock_on_started.emit(target)
	else:
		rotation_mode = RotationMode.FACE_MOVEMENT
		lock_on_ended.emit()


## Clear the current lock-on target.
func clear_lock_on() -> void:
	set_lock_on_target(null)


## Get the camera's current yaw angle.
func get_camera_yaw() -> float:
	if perspective == Perspective.FIRST_PERSON:
		return fps_look_controller.yaw if fps_look_controller else 0.0
	else:
		return orbit_camera_controller.yaw if orbit_camera_controller else 0.0


func _update_body_tilt(delta: float) -> void:
	var target_tilt := Vector3.ZERO
	
	if motor.is_moving:
		var velocity := motor.actual_velocity
		velocity.y = 0
		
		if velocity.length() > 0.5:
			var sprint_speed := movement_settings.sprint_speed if movement_settings else 8.0
			var speed_factor := clamp(velocity.length() / sprint_speed, 0.0, 1.0)
			
			# Calculate tilt based on velocity relative to body facing
			var local_velocity := body.global_transform.basis.inverse() * velocity.normalized()
			
			# Forward tilt (pitch) based on forward speed
			target_tilt.x = - local_velocity.z * deg_to_rad(tilt_amount) * speed_factor
			
			# Side tilt (roll) based on strafe
			target_tilt.z = local_velocity.x * deg_to_rad(tilt_amount) * speed_factor
	
	# Smooth interpolation
	character_mesh.rotation.x = lerp(character_mesh.rotation.x, target_tilt.x, tilt_speed * delta)
	character_mesh.rotation.z = lerp(character_mesh.rotation.z, target_tilt.z, tilt_speed * delta)


## Called by UIState when entering.
func _on_ui_state_entered() -> void:
	if fps_look_controller:
		fps_look_controller.enabled = false
	if orbit_camera_controller:
		orbit_camera_controller.enabled = false


## Called by UIState when exiting.
func _on_ui_state_exited() -> void:
	# Re-enable the appropriate controller based on current perspective
	if perspective == Perspective.FIRST_PERSON:
		if fps_look_controller:
			fps_look_controller.enabled = true
	else:
		if orbit_camera_controller:
			orbit_camera_controller.enabled = true

class_name ThirdPersonController3D
extends BasePlayerController3D
## Third-person player controller with orbit camera.
##
## Extends BasePlayerController3D with camera-relative movement
## and optional character rotation toward movement direction.


## Emitted when lock-on target is acquired.
signal lock_on_started(target: Node3D)
## Emitted when lock-on is released.
signal lock_on_ended()


## Character rotation modes.
enum RotationMode {
	FACE_MOVEMENT, ## Body rotates to face movement direction
	STRAFE, ## Body faces camera direction (strafe mode)
	FREE, ## No automatic rotation
	AIMING, ## Precision strafe with FOV zoom and tighter rotation
	LOCK_ON ## Face locked target node
}


@export_group("Third-Person Components")
## Orbit camera controller. Required.
@export var camera_controller: OrbitCameraController3D

@export_group("Third-Person Settings")
## Camera settings resource.
@export var camera_settings: OrbitCameraSettings3D:
	set(value):
		camera_settings = value
		if camera_controller:
			camera_controller.camera_settings = value
			camera_controller.refresh_settings()

## How the character rotates relative to movement/camera.
@export var rotation_mode: RotationMode = RotationMode.FACE_MOVEMENT

## Speed at which character rotates to face movement direction.
@export_range(1.0, 30.0, 0.5) var rotation_speed: float = 10.0

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
## Enable body tilt toward movement direction.
@export var enable_body_tilt: bool = false
## Character mesh to tilt (not the body itself).
@export var character_mesh: Node3D
## Maximum tilt angle in degrees.
@export_range(0.0, 15.0, 0.5) var tilt_amount: float = 5.0
## Speed of tilt interpolation.
@export_range(1.0, 30.0, 1.0) var tilt_speed: float = 10.0


## Default FOV for restoring after aiming.
var _default_fov: float = 75.0


func _ready() -> void:
	super._ready()
	_validate_3rd_person_dependencies()
	_wire_3rd_person_components()
	# Cache default FOV
	if camera_controller and camera_controller.camera:
		_default_fov = camera_controller.camera.fov


func _validate_3rd_person_dependencies() -> void:
	if not camera_controller:
		push_warning("ThirdPersonController3D: 'camera_controller' is not assigned.")


func _wire_3rd_person_components() -> void:
	if camera_controller:
		if input_router:
			camera_controller.input_router = input_router
		if camera_settings:
			camera_controller.camera_settings = camera_settings
			camera_controller.refresh_settings()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Handle character rotation based on mode
	if body and motor and rotation_mode != RotationMode.FREE:
		_update_character_rotation(delta)
	
	# Handle body tilt
	if enable_body_tilt and character_mesh and motor:
		_update_body_tilt(delta)


## Third-person uses camera-relative movement (flatten camera forward).
func _get_movement_basis() -> Basis:
	if camera_controller and camera_controller.camera:
		var cam_basis := camera_controller.camera.global_transform.basis
		
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
			if camera_controller:
				target_rotation = camera_controller.yaw
		
		RotationMode.FREE:
			return # No rotation
		
		RotationMode.AIMING:
			if camera_controller:
				target_rotation = camera_controller.yaw
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
	if not camera_controller or not camera_controller.camera:
		return
	var target_fov := aiming_fov if rotation_mode == RotationMode.AIMING else _default_fov
	camera_controller.camera.fov = lerp(camera_controller.camera.fov, target_fov, aiming_fov_transition_speed * delta)


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
	if camera_controller:
		return camera_controller.yaw
	return 0.0


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


## Called by UIState when entering. Disable camera controller.
func _on_ui_state_entered() -> void:
	if camera_controller:
		camera_controller.enabled = false


## Called by UIState when exiting. Re-enable camera controller.
func _on_ui_state_exited() -> void:
	if camera_controller:
		camera_controller.enabled = true

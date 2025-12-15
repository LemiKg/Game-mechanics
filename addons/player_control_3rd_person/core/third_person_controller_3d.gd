class_name ThirdPersonController3D
extends BasePlayerController3D
## Third-person player controller with orbit camera.
##
## Extends BasePlayerController3D with camera-relative movement
## and optional character rotation toward movement direction.


## Character rotation modes.
enum RotationMode {
	FACE_MOVEMENT, ## Body rotates to face movement direction
	STRAFE, ## Body faces camera direction (strafe mode)
	FREE ## No automatic rotation
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


func _ready() -> void:
	super._ready()
	_validate_3rd_person_dependencies()
	_wire_3rd_person_components()


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


## Third-person uses camera-relative movement (flatten camera forward).
func _get_movement_basis() -> Basis:
	if camera_controller and camera_controller.camera:
		var cam_basis := camera_controller.camera.global_transform.basis
		
		# Flatten camera forward to horizontal plane
		var forward := -cam_basis.z
		forward.y = 0
		forward = forward.normalized()
		
		var right := cam_basis.x
		right.y = 0
		right = right.normalized()
		
		# Return a basis where Z is forward (toward camera look direction)
		return Basis(right, Vector3.UP, -forward)
	
	return body.global_transform.basis if body else Basis.IDENTITY


func _update_character_rotation(delta: float) -> void:
	match rotation_mode:
		RotationMode.FACE_MOVEMENT:
			_rotate_to_movement(delta)
		RotationMode.STRAFE:
			_rotate_to_camera(delta)


func _rotate_to_movement(delta: float) -> void:
	if not input_router:
		return
	
	var input_dir := input_router.movement_intent
	if input_dir.length() < 0.1:
		return # No input, don't rotate
	
	# Get movement direction in world space
	var move_basis := _get_movement_basis()
	var move_dir := (move_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Calculate target rotation
	var target_rotation := atan2(move_dir.x, move_dir.z)
	
	# Smoothly rotate toward target
	var current_rotation := body.rotation.y
	body.rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)


func _rotate_to_camera(delta: float) -> void:
	if not camera_controller:
		return
	
	# Face the same direction as the camera (yaw only)
	var target_rotation := camera_controller.yaw
	var current_rotation := body.rotation.y
	body.rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)


## Called by UIState when entering. Disable camera controller.
func _on_ui_state_entered() -> void:
	if camera_controller:
		camera_controller.enabled = false


## Called by UIState when exiting. Re-enable camera controller.
func _on_ui_state_exited() -> void:
	if camera_controller:
		camera_controller.enabled = true

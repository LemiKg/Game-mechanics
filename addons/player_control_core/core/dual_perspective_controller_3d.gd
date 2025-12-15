class_name DualPerspectiveController3D
extends BasePlayerController3D
## Player controller supporting both first-person and third-person perspectives.
##
## Can toggle between FPS and third-person views at runtime.
## Both perspectives share the same state machine and movement settings.


## Emitted when perspective changes.
signal perspective_changed(is_first_person: bool)

## Perspective modes.
enum Perspective {
	FIRST_PERSON,
	THIRD_PERSON
}

## Character rotation modes for third-person.
enum RotationMode {
	FACE_MOVEMENT, ## Body rotates to face movement direction
	STRAFE, ## Body faces camera direction
	FREE ## No automatic rotation
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


func _ready() -> void:
	super._ready()
	_validate_perspective_dependencies()
	_wire_perspective_components()
	_apply_perspective()


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
			var forward := -cam_basis.z
			forward.y = 0
			forward = forward.normalized()
			
			var right := cam_basis.x
			right.y = 0
			right = right.normalized()
			
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
	if not orbit_camera_controller:
		return
	
	# Face the same direction as the camera (yaw only)
	var target_rotation := orbit_camera_controller.yaw
	var current_rotation := body.rotation.y
	body.rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)


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

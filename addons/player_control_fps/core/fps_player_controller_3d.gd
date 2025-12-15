class_name FPSPlayerController3D
extends BasePlayerController3D
## First-person player controller.
##
## Extends BasePlayerController3D with FPS-specific camera handling.
## Uses body-relative movement and yaw/pitch look controls.


@export_group("FPS Components")
## Look controller for yaw/pitch camera. Required.
@export var look_controller: PlayerLookController3D

@export_group("Rig References")
## The node for pitch rotation (camera pivot). Passed to look controller.
@export var pitch_pivot: Node3D
## The camera node (optional, for reference).
@export var camera: Camera3D

@export_group("FPS Settings")
## Look settings resource.
@export var look_settings: FPSLookSettings3D:
	set(value):
		look_settings = value
		if look_controller:
			look_controller.look_settings = value
			look_controller.refresh_settings()


func _ready() -> void:
	super._ready()
	_validate_fps_dependencies()
	_wire_fps_components()


func _validate_fps_dependencies() -> void:
	if not look_controller:
		push_warning("FPSPlayerController3D: 'look_controller' is not assigned.")
	if not pitch_pivot:
		push_warning("FPSPlayerController3D: 'pitch_pivot' is not assigned.")


func _wire_fps_components() -> void:
	# Wire look controller
	if look_controller:
		if body:
			look_controller.yaw_node = body
		if pitch_pivot:
			look_controller.pitch_node = pitch_pivot
		if input_router:
			look_controller.input_router = input_router
		if look_settings:
			look_controller.look_settings = look_settings
			look_controller.refresh_settings()


## FPS uses body-relative movement (look direction = move direction).
func _get_movement_basis() -> Basis:
	return body.global_transform.basis if body else Basis.IDENTITY


## Called by UIState when entering. Disable look controller.
func _on_ui_state_entered() -> void:
	if look_controller:
		look_controller.enabled = false


## Called by UIState when exiting. Re-enable look controller.
func _on_ui_state_exited() -> void:
	if look_controller:
		look_controller.enabled = true

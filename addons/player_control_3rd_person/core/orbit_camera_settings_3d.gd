@tool
class_name OrbitCameraSettings3D
extends Resource
## Tuning values for third-person orbit camera.
##
## Create a .tres file to customize camera feel per project.


@export_group("Distance")
## Default distance from target.
@export_range(0.5, 20.0, 0.1) var default_distance: float = 5.0
## Minimum zoom distance.
@export_range(0.5, 10.0, 0.1) var min_distance: float = 1.5
## Maximum zoom distance.
@export_range(1.0, 30.0, 0.1) var max_distance: float = 10.0

@export_group("Position")
## Height offset above target pivot.
@export_range(0.0, 5.0, 0.1) var height_offset: float = 1.5

@export_group("Rotation")
## Mouse sensitivity for orbiting.
@export_range(0.0001, 0.01, 0.0001) var orbit_sensitivity: float = 0.003
## Minimum pitch angle in radians (looking up). Negative = look up.
@export_range(-1.57, 0.0, 0.01) var min_pitch: float = -1.2
## Maximum pitch angle in radians (looking down). Positive = look down.
@export_range(0.0, 1.57, 0.01) var max_pitch: float = 1.4

@export_group("Smoothing")
## Camera position follow smoothing. Higher = faster catch up.
@export_range(1.0, 50.0, 0.5) var follow_smoothing: float = 10.0
## Camera rotation smoothing. Higher = snappier rotation.
@export_range(1.0, 50.0, 0.5) var rotation_smoothing: float = 15.0

@export_group("Collision")
## Physics layers for camera collision detection.
@export_flags_3d_physics var collision_mask: int = 1
## Distance to push camera away from collision point.
@export_range(0.0, 1.0, 0.05) var collision_margin: float = 0.2


@export_group("Shoulder")
## Horizontal offset magnitude for shoulder view (positive = right).
@export_range(0.0, 2.0, 0.05) var shoulder_offset: float = 0.5
## How fast the camera transitions between shoulder positions.
@export_range(1.0, 30.0, 1.0) var shoulder_switch_speed: float = 8.0

@export_group("FOV")
## Base field of view.
@export_range(50.0, 120.0, 1.0) var base_fov: float = 75.0
## FOV when sprinting (for speed effect).
@export_range(50.0, 120.0, 1.0) var sprint_fov: float = 85.0
## How fast FOV transitions.
@export_range(1.0, 30.0, 1.0) var fov_transition_speed: float = 5.0

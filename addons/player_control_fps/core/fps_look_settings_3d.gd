@tool
class_name FPSLookSettings3D
extends Resource
## Tuning values for FPS mouse look.
##
## Create a .tres file to customize look feel per project.


@export_group("Sensitivity")
## Mouse sensitivity multiplier. Lower = slower camera movement.
@export_range(0.0001, 0.01, 0.0001) var mouse_sensitivity: float = 0.002
## Invert vertical mouse movement (true = moving mouse up looks down).
@export var invert_y: bool = false

@export_group("Pitch Limits")
## Minimum pitch angle in degrees (looking up). Usually negative.
@export_range(-90.0, 0.0, 1.0) var min_pitch_degrees: float = -89.0
## Maximum pitch angle in degrees (looking down). Usually positive.
@export_range(0.0, 90.0, 1.0) var max_pitch_degrees: float = 89.0

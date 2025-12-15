@tool
class_name MovementSettings3D
extends Resource
## Tuning values for player movement physics.
##
## Create a .tres file to customize movement feel per project or character.
## Used by both FPS and third-person controllers.


@export_group("Speed")
## Walking speed in units per second.
@export_range(0.0, 50.0, 0.1) var walk_speed: float = 5.0
## Sprinting speed in units per second.
@export_range(0.0, 50.0, 0.1) var sprint_speed: float = 8.0
## Crouching speed in units per second.
@export_range(0.0, 50.0, 0.1) var crouch_speed: float = 2.5

@export_group("Acceleration")
## How quickly the player reaches target speed (units/second²).
@export_range(0.0, 100.0, 0.5) var acceleration: float = 10.0
## How quickly the player stops when no input (units/second²).
@export_range(0.0, 100.0, 0.5) var deceleration: float = 10.0
## Movement control multiplier while airborne (0 = no air control, 1 = full).
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.3

@export_group("Jump & Gravity")
## Upward velocity applied when jumping.
@export_range(0.0, 20.0, 0.1) var jump_velocity: float = 4.5
## Gravity strength (positive = downward).
@export_range(0.0, 50.0, 0.1) var gravity: float = 9.8

@export_group("Crouch")
## Height of collision shape when crouching.
@export_range(0.0, 3.0, 0.1) var crouch_height: float = 1.0
## Height of collision shape when standing.
@export_range(0.0, 3.0, 0.1) var stand_height: float = 1.8

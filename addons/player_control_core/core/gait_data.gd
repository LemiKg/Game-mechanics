@tool
class_name GaitData
extends Resource
## Per-gait movement tuning values.
##
## Each gait (walk, run, sprint) has its own speed, acceleration,
## deceleration, and rotation rate. Create as .tres files or inline
## in MovementSettings3D.


## Target movement speed for this gait (units/second).
@export_range(0.0, 50.0, 0.1) var speed: float = 5.0

## How fast the player reaches target speed (units/second²).
@export_range(0.0, 100.0, 0.5) var acceleration: float = 25.0

## How fast the player stops when no input (units/second²).
@export_range(0.0, 100.0, 0.5) var deceleration: float = 30.0

## How fast the body turns to face movement direction (degrees/second).
@export_range(0.0, 720.0, 5.0) var rotation_rate: float = 360.0

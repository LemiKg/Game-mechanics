@tool
class_name FPSInputActions
extends Resource
## Configurable input action names for FPS controls.
##
## This is a pure data Resource for Inspector editability and serialization.
## Create a .tres file to customize action names per project.


@export_group("Movement Actions")
## Action name for moving forward.
@export var move_forward: StringName = &"move_forward"
## Action name for moving backward.
@export var move_back: StringName = &"move_back"
## Action name for moving left.
@export var move_left: StringName = &"move_left"
## Action name for moving right.
@export var move_right: StringName = &"move_right"

@export_group("Actions")
## Action name for jumping.
@export var jump: StringName = &"jump"
## Action name for interacting (optional).
@export var interact: StringName = &"interact"

@tool
class_name MantleSettings3D
extends Resource
## Configuration for mantling/climbing behavior.
##
## Controls ledge detection, mantle movement, and animation selection.


@export_group("Detection")
## Length of forward ray to detect walls.
@export_range(0.1, 2.0, 0.1) var forward_ray_length: float = 0.8
## Height above character origin for forward ray.
@export_range(0.1, 2.0, 0.1) var forward_ray_height: float = 0.5
## Length of downward ray to find ledge top.
@export_range(0.5, 3.0, 0.1) var ground_ray_length: float = 1.5
## Length of upward ray to check clearance on ledge.
@export_range(0.5, 3.0, 0.1) var clearance_ray_length: float = 1.0
## Minimum ledge height to trigger mantle.
@export_range(0.1, 1.5, 0.1) var min_ledge_height: float = 0.5
## Maximum ledge height for mantle (above this = too high).
@export_range(1.0, 4.0, 0.1) var max_ledge_height: float = 2.0
## Collision mask for ledge detection raycasts.
@export_flags_3d_physics var collision_mask: int = 1


@export_group("Movement")
## Duration of mantle movement in seconds.
@export_range(0.1, 2.0, 0.05) var mantle_duration: float = 0.5
## Curve for position interpolation (null = linear).
@export var mantle_curve: Curve
## Extra height added to target position for clearance.
@export_range(0.0, 0.5, 0.05) var mantle_height_offset: float = 0.1
## Arc height multiplier for visual appeal (0 = straight line).
@export_range(0.0, 0.5, 0.05) var arc_height_factor: float = 0.3


@export_group("Animation")
## Ledge height threshold for low/high mantle distinction.
@export_range(0.5, 2.0, 0.1) var low_mantle_threshold: float = 1.0
## Animation for high mantles (above threshold).
@export var high_mantle_animation: StringName = &"high_mantle"
## Animation for low mantles (below threshold).
@export var low_mantle_animation: StringName = &"low_mantle"

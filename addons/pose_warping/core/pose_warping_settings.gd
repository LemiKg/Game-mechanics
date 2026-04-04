class_name PoseWarpingSettings
extends Resource
## Centralized configuration for all pose warping behaviors.
##
## Assign this resource to PoseWarpingController. Settings are forwarded
## to each modifier automatically.


# =============================================================================
# STRIDE WARPING
# =============================================================================

@export_group("Stride Warping")

## Enable or disable stride warping.
@export var enable_stride_warping: bool = true

## The Walk animation's intended speed (m/s). Stride scales relative to this.
@export_range(0.1, 10.0, 0.1) var base_walk_speed: float = 2.0

## The Sprint animation's intended speed (m/s). Used when speed exceeds walk threshold.
@export_range(0.1, 20.0, 0.1) var base_sprint_speed: float = 5.0

## Maximum stride scale multiplier (1.2 = 20% stretch, industry standard).
@export_range(1.0, 1.5, 0.05) var max_speed_scale: float = 1.2

## Minimum stride scale multiplier (0.8 = 20% compression).
@export_range(0.5, 1.0, 0.05) var min_speed_scale: float = 0.8

## Minimum speed before stride warping activates.
@export_range(0.0, 2.0, 0.1) var min_speed_for_stride: float = 0.5

## How fast stride warping interpolates to target values.
@export_range(1.0, 30.0, 1.0) var stride_blend_speed: float = 10.0

## Foot bone names (end effectors to scale relative to hips).
@export var foot_bone_names: Array[String] = ["DEF-foot.L", "DEF-foot.R"]

## Hips bone name (reference point for foot offset calculation).
@export var hips_bone_name: String = "DEF-hips"

## Thigh bone names (for leg chain length calculation, same order as foot_bone_names).
@export var thigh_bone_names: Array[String] = ["DEF-thigh.L", "DEF-thigh.R"]

## Shin bone names (for leg chain length calculation, same order as foot_bone_names).
@export var shin_bone_names: Array[String] = ["DEF-shin.L", "DEF-shin.R"]

## Maximum pelvis pull-down distance when legs hyper-extend (meters in bone-local space).
@export_range(0.0, 1.0, 0.01) var max_stride_pelvis_pulldown: float = 0.3


# =============================================================================
# ORIENTATION WARPING
# =============================================================================

@export_group("Orientation Warping")

## Enable or disable orientation warping.
@export var enable_orientation_warping: bool = true

## Maximum angle (degrees) the spine can rotate toward look direction.
@export_range(0.0, 180.0, 5.0) var max_orientation_angle: float = 90.0

## How fast orientation warping interpolates to target values.
@export_range(1.0, 30.0, 1.0) var orientation_blend_speed: float = 10.0

## Names of spine bones to rotate. Order: lowest to highest.
@export var spine_bone_names: Array[String] = [
	"DEF-spine.001", "DEF-spine.002", "DEF-spine.003"
]

## Weight distribution for each spine bone. Should sum to ~1.0.
## Higher weight = more rotation applied to that bone.
@export var spine_weight_distribution: Array[float] = [0.25, 0.35, 0.40]


# =============================================================================
# SLOPE WARPING
# =============================================================================

@export_group("Slope Warping")

## Enable or disable slope warping. Disabled by default.
@export var enable_slope_warping: bool = false

## Length of downward raycast for ground detection.
@export_range(0.1, 3.0, 0.1) var slope_raycast_length: float = 1.5

## How fast feet adapt to terrain height changes.
@export_range(1.0, 30.0, 1.0) var slope_adaptation_speed: float = 10.0

## Collision mask for slope raycasts.
@export_flags_3d_physics var slope_collision_mask: int = 1

## Maximum pelvis height adjustment for slope (meters).
@export_range(0.0, 0.5, 0.01) var max_pelvis_offset: float = 0.3

## How much to rotate feet to align with ground normal (0-1).
@export_range(0.0, 1.0, 0.1) var foot_rotation_blend: float = 0.8

## Height offset from foot bone to ground contact point.
@export_range(0.0, 0.2, 0.01) var foot_height_offset: float = 0.05

## Raycast origin height above foot world position.
@export_range(0.0, 1.0, 0.1) var raycast_origin_height: float = 0.5


# =============================================================================
# THRESHOLDS
# =============================================================================

@export_group("Thresholds")

## Speed below which the character is considered idle (no warping applied).
@export_range(0.0, 1.0, 0.05) var idle_speed_threshold: float = 0.1

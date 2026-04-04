# Pose Warping System Rewrite - Design Spec

## Summary

Rewrite the pose warping addon to fix fundamental implementation issues. The current system scales FK bone origins (wrong technique) and only half-implements orientation warping. The rewrite targets the actual Quaternius skeleton bone names and works with forward-only locomotion animations (Walk_Loop, Sprint_Loop).

**Approach:** Upper-body twist + IK-style stride warping + slope foot placement. No cardinal direction animations required.

## Architecture

```
PoseWarpingController (Node, child of Player)
    Reads velocity from PlayerMotor3D (duck-typed)
    Computes movement direction, look direction, speed
    Distributes data to modifiers each physics frame

Modifiers (SkeletonModifier3D, children of Skeleton3D):
    OrientationWarpingModifier  - Spine twist toward look direction
    StrideWarpingModifier       - Foot position scaling + pelvis pull-down
    SlopeWarpingModifier        - Raycast foot placement on terrain
```

Modifiers operate on foot end-effector positions (DEF-foot.L/R) relative to hips, not on FK bone origins (thigh/shin). The hips bone (DEF-hips) acts as the reference point.

## Data Flow

### Per-Frame Pipeline (order matters)

1. AnimationTree produces base pose (Walk/Sprint/Idle)
2. PoseWarpingController._physics_process(delta):
   - Read actual_velocity from PlayerMotor3D
   - Compute movement_direction (XZ plane, from velocity)
   - Compute look_direction (from camera/controller forward)
   - Compute speed (horizontal magnitude)
   - Call update_warping() on each modifier
3. Skeleton3D._process_modification() (Godot callback):
   - OrientationWarpingModifier._process_modification() - rotate spine
   - StrideWarpingModifier._process_modification() - scale feet, pull pelvis
   - SlopeWarpingModifier._process_modification() - offset feet to ground

### Direction Sources

- `movement_direction`: Extracted from `actual_velocity` on XZ plane
- `look_direction`: From the active camera's `-basis.z` (works for both FPS and 3rd person via DualPerspectiveController3D)

### Bone Mapping (Quaternius Skeleton)

| Role | Bone Name |
|------|-----------|
| Hips/Pelvis | DEF-hips |
| Spine chain | DEF-spine.001, DEF-spine.002, DEF-spine.003 |
| Left leg | DEF-thigh.L, DEF-shin.L, DEF-foot.L |
| Right leg | DEF-thigh.R, DEF-shin.R, DEF-foot.R |
| Toes | DEF-toe.L, DEF-toe.R |

## Modifier Specifications

### Orientation Warping (Upper-Body Twist)

- Compute signed angle between movement direction and look direction using atan2 (not unsigned angle_to())
- Distribute rotation across spine bones with weights: [0.25, 0.35, 0.40] (lower spine less, upper spine more)
- Rotate around bone local Y-axis using Basis(Vector3.UP, angle * weight)
- Clamp max rotation to 90 degrees (configurable)
- Smooth interpolation via lerp toward target angle
- Disable when speed < idle threshold (no twisting while standing still)

### Stride Warping (Foot Position Scaling)

- stride_scale = actual_speed / base_animation_speed, clamped to [0.8, 1.2]
- For each foot bone (DEF-foot.L/R):
  - Get foot position relative to hips: foot_offset = foot_pose.origin - hips_pose.origin
  - Scale the forward component: foot_offset.z *= stride_scale
  - Write back: foot_pose.origin = hips_pose.origin + foot_offset
- Pelvis pull-down: After scaling, check if either leg chain would hyper-extend (foot distance > thigh_length + shin_length). If so, lower hips by the overshoot, clamped to a max.
- Leg chain lengths cached at _ready() from rest poses
- Min speed threshold: skip warping when near zero speed (start/stop transitions)

### Slope Warping (Foot Placement on Terrain)

- Raycast downward from each foot's actual world position
- Exclude character's own collision RID from raycast
- foot_offset = hit_point.y - character_ground_y + clearance
- Lower pelvis by min(left_offset, right_offset), clamped to max_pelvis_offset
- Rotate foot to align with ground normal via cross product
- Smooth all offsets and rotations via lerp/slerp
- Disabled by default (Phase 2)

### Shared Modifier Behavior

- _warping_enabled flag controlled by controller
- Smooth blend to zero when warping stops (no pop)
- Bone index caching at _ready() with validation
- Early return when disabled

## Settings Resource (PoseWarpingSettings)

```
# Stride Warping
enable_stride_warping: bool = true
base_walk_speed: float = 2.0
base_sprint_speed: float = 5.0
max_speed_scale: float = 1.2
min_speed_scale: float = 0.8
min_speed_for_stride: float = 0.5
stride_blend_speed: float = 10.0
foot_bone_names: Array[String] = ["DEF-foot.L", "DEF-foot.R"]
hips_bone_name: String = "DEF-hips"
thigh_bone_names: Array[String] = ["DEF-thigh.L", "DEF-thigh.R"]
shin_bone_names: Array[String] = ["DEF-shin.L", "DEF-shin.R"]

# Orientation Warping
enable_orientation_warping: bool = true
max_orientation_angle: float = 90.0
orientation_blend_speed: float = 10.0
spine_bone_names: Array[String] = ["DEF-spine.001", "DEF-spine.002", "DEF-spine.003"]
spine_weight_distribution: Array[float] = [0.25, 0.35, 0.40]

# Slope Warping (disabled by default)
enable_slope_warping: bool = false
slope_raycast_length: float = 1.5
slope_adaptation_speed: float = 10.0
slope_collision_mask: int = 1
max_pelvis_offset: float = 0.3
foot_rotation_blend: float = 0.8
foot_height_offset: float = 0.05
raycast_origin_height: float = 0.5

# Thresholds
idle_speed_threshold: float = 0.1
```

## Changes From Current Implementation

| What | Current (Broken) | New (Correct) |
|------|-----------------|---------------|
| Stride warping target | FK bone origins (thigh/shin .origin.z) | Foot end-effector positions relative to hips |
| Stride scale range | [0.5, 1.5] | [0.8, 1.2] (industry 15-20% rule) |
| Pelvis pull-down | Not implemented | Implemented with leg chain length validation |
| Orientation angle | Unsigned angle_to() | Signed atan2 |
| Orientation approach | Spine rotation only | Spine rotation toward look direction |
| Slope raycast exclusion | Empty (hits self) | Excludes character collision RID |
| Slope raycast origin | Character center + lateral offset | Actual foot bone world position |
| Settings .tres file | Empty (0 bytes) | Properly saved with defaults |
| Bone name defaults | Mixamo convention | Quaternius DEF- convention |
| Min speed guard | Missing (division by ~0 possible) | Implemented |
| Debug prints | Always on | Removed |

## Files to Modify

- `addons/pose_warping/core/pose_warping_settings.gd` - Rewrite settings
- `addons/pose_warping/core/pose_warping_controller.gd` - Rewrite controller
- `addons/pose_warping/core/stride_warping_modifier.gd` - Rewrite with IK-style foot scaling
- `addons/pose_warping/core/orientation_warping_modifier.gd` - Rewrite with signed angle
- `addons/pose_warping/core/slope_warping_modifier.gd` - Fix raycast exclusion, use foot world pos
- `addons/pose_warping/default_pose_warping_settings.tres` - Create proper resource
- `addons/pose_warping/pose_warping_plugin.gd` - Update registered types if needed
- `scenes/player.tscn` - Verify modifier nodes exist on Skeleton3D

## Extensibility

The architecture supports adding full orientation warping (Approach B with cardinal direction animations) later by:
1. Adding a blend space with directional animations
2. Extending OrientationWarpingModifier to rotate the lower body + counter-rotate spine
3. Adding IK foot counter-rotation

No structural changes needed — just modifier logic expansion.

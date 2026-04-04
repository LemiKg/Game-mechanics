# Pose Warping Addon

Procedural animation warping system for Godot 4.x that reduces foot sliding and enables upper-body orientation warping for humanoid characters.

## Features

- **Stride Warping:** Adjusts leg bone transforms to match actual movement speed, reducing foot sliding
- **Orientation Warping:** Rotates spine bones toward look direction while legs follow movement direction
- **Slope Warping (Phase 2):** Foot placement IK for uneven terrain using raycasts
- **Duck-typed velocity detection:** Works with any node that provides velocity (`CharacterBody3D`, `RigidBody3D`, `PlayerMotor3D`, or custom)
- **Configurable bone names:** Works with any humanoid skeleton via exported arrays

## Installation

1. Copy the `addons/pose_warping` folder to your project's `addons/` directory
2. Enable the plugin in Project Settings → Plugins

## Usage

### Scene Setup

Add the following nodes as children of your `Skeleton3D`:

```
Skeleton3D
  ├── PoseWarpingController
  ├── StrideWarpingModifier
  └── OrientationWarpingModifier
```

### Configuration

1. Create a `PoseWarpingSettings` resource (or use the default)
2. Assign the settings to `PoseWarpingController` and all modifiers
3. Set `velocity_source` on the controller to your `CharacterBody3D`, `PlayerMotor3D`, or any node with velocity
4. Set `skeleton` on the controller to your `Skeleton3D`
5. Configure bone names in the settings to match your skeleton rig

### Velocity Source Compatibility

The controller uses duck typing to detect velocity from any source:

| Source Type | Detected Property/Method |
|-------------|-------------------------|
| `PlayerMotor3D` | `get_velocity()`, `actual_velocity` |
| `CharacterBody3D` | `velocity` |
| `RigidBody3D` | `linear_velocity` |
| Custom | `get_velocity()` method |

### Settings Reference

#### Stride Warping
- `enable_stride_warping`: Toggle stride warping on/off
- `base_walk_speed`: The animation's intended walk speed (used for speed ratio calculation)
- `max_speed_scale`: Maximum leg scaling multiplier
- `min_speed_for_stride`: Minimum speed before stride warping activates
- `leg_bone_names`: Array of leg bone names to modify

#### Orientation Warping
- `enable_orientation_warping`: Toggle orientation warping on/off
- `max_orientation_angle`: Maximum spine rotation angle (degrees)
- `orientation_blend`: Blend weight for orientation (0-1)
- `spine_bone_names`: Array of spine bone names to rotate
- `spine_weight_distribution`: Weight distribution for each spine bone

#### Speed Thresholds
- `idle_speed_threshold`: Speed below which character is considered idle
- `walk_speed`: Reference walk speed
- `run_speed`: Reference run speed

## Signals

### PoseWarpingController

- `warping_started()`: Emitted when character starts moving and warping activates
- `warping_stopped()`: Emitted when character stops and warping deactivates
- `velocity_updated(velocity: Vector3, speed: float)`: Emitted every physics frame with current velocity

## Integration Example

```gdscript
# In your character script
@onready var pose_controller: PoseWarpingController = $Skeleton3D/PoseWarpingController

func _ready() -> void:
    # Assuming CharacterBody3D is the velocity source
    pose_controller.velocity_source = self
    pose_controller.skeleton = $Skeleton3D
```

## Bone Name Examples

### Mixamo Rig
```gdscript
leg_bone_names = ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]
spine_bone_names = ["Spine", "Spine1", "Spine2"]
foot_bone_names = ["LeftFoot", "RightFoot"]
```

### Generic Humanoid
```gdscript
leg_bone_names = ["thigh.L", "thigh.R", "shin.L", "shin.R"]
spine_bone_names = ["spine", "spine.001", "spine.002"]
foot_bone_names = ["foot.L", "foot.R"]
```

## Performance Notes

- Bone indices are cached on `_ready()` for efficiency
- Warping is skipped when character is idle (below `idle_speed_threshold`)
- Consider disabling warping for distant characters (LOD)

## License

MIT License

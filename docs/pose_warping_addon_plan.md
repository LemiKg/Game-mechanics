# Pose Warping Addon — Implementation Plan

## 0) Context and Constraints (Project Rules)
This repository uses a **modular addon architecture**:
- Each mechanic is a self-contained addon under `addons/<addon_name>/`.
- **Data layer:** `Resource` types in `core/` (pure data + validation).
- **Logic layer:** `Node` components/controllers/handlers in `core/`.
- **UI layer:** `ui/` contains `Control` scripts + scenes (display only).
- **Dependency injection:** use `@export` for external dependencies; guard nulls; avoid tree traversal.
- **Decoupled communication:** use signals with sufficient context.

This addon is **standalone** — it has no hard dependency on `player_control_core`. It works with any node that provides velocity/direction information via duck typing.

## 1) Goals

### Must-have (MVP)
- **Stride Warping:** Adjust leg IK to match actual movement speed, reducing foot sliding.
- **Orientation Warping:** Rotate spine bones to match camera/look direction while legs follow velocity.
- **Configurable bone names:** Work with any humanoid skeleton via exported arrays.
- **Speed-based blending:** Automatically blend warping intensity based on movement speed.
- **Signal-based integration:** Connect to any velocity source without hard coupling.

### Nice-to-have (Phase 2)
- **Slope Warping:** Foot placement IK for uneven terrain using raycasts.
- **Turn-in-place warping:** Procedural hip rotation during stationary turns.
- **Animation curve support:** Custom blend curves for warping intensity.

### Non-goals (deferred)
- Full IK system (use Godot's built-in or third-party IK)
- Facial animation / look-at IK
- Hand IK for weapon holding
- Networked pose synchronization

## 2) Architecture Overview

```
┌────────────────────────────────────────────────────────────────┐
│                       Game Scene                                │
│  ┌─────────────────┐      ┌─────────────────────────────────┐  │
│  │ PlayerMotor3D   │      │ Any Velocity Provider           │  │
│  │ (or any source) │      │ (CharacterBody3D, RigidBody3D)  │  │
│  └────────┬────────┘      └──────────────┬──────────────────┘  │
│           │                              │                      │
│           └──────────┬───────────────────┘                      │
│                      │ velocity / direction                     │
│                      ▼                                          │
│           ┌─────────────────────┐                               │
│           │ PoseWarpingController│ (Orchestrator)               │
│           └──────────┬──────────┘                               │
│                      │                                          │
│      ┌───────────────┼───────────────┐                          │
│      ▼               ▼               ▼                          │
│ ┌──────────┐  ┌────────────┐  ┌────────────┐                   │
│ │ Stride   │  │Orientation │  │   Slope    │                   │
│ │ Warping  │  │  Warping   │  │  Warping   │                   │
│ │ Modifier │  │  Modifier  │  │  Modifier  │                   │
│ └──────────┘  └────────────┘  └────────────┘                   │
│      │               │               │                          │
│      └───────────────┴───────────────┘                          │
│                      │                                          │
│                      ▼                                          │
│              ┌──────────────┐                                   │
│              │  Skeleton3D  │                                   │
│              └──────────────┘                                   │
└────────────────────────────────────────────────────────────────┘
```

### Duck Typing Integration Pattern

The addon uses duck typing to connect to any velocity source:

```gdscript
# PoseWarpingController checks for these methods/properties:
if velocity_source.has_method("get_velocity"):
    velocity = velocity_source.get_velocity()
elif "velocity" in velocity_source:
    velocity = velocity_source.velocity
elif "actual_velocity" in velocity_source:
    velocity = velocity_source.actual_velocity
```

This allows integration with:
- `CharacterBody3D` (has `velocity` property)
- `RigidBody3D` (has `linear_velocity` property)
- `PlayerMotor3D` (will have `actual_velocity` property)
- Any custom node with a `get_velocity()` method

## 3) Addon Structure

```
addons/
  pose_warping/
    plugin.cfg
    pose_warping_plugin.gd
    README.md
    core/
      pose_warping_controller.gd       # Orchestrator node
      stride_warping_modifier.gd       # SkeletonModifier3D
      orientation_warping_modifier.gd  # SkeletonModifier3D
      slope_warping_modifier.gd        # SkeletonModifier3D (Phase 2)
      pose_warping_settings.gd         # Resource
    icons/
      pose_warping.svg                 # Editor icon
```

## 4) Core Components

### 4.1 `PoseWarpingSettings` (Resource)

Purpose: Centralized configuration for all warping behaviors.

```gdscript
class_name PoseWarpingSettings
extends Resource

## Stride Warping
@export_group("Stride Warping")
@export var enable_stride_warping: bool = true
@export var stride_warping_blend: float = 1.0
@export var min_speed_for_stride: float = 0.5
@export var max_speed_scale: float = 1.5
@export var leg_bone_names: Array[String] = ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]

## Orientation Warping
@export_group("Orientation Warping")
@export var enable_orientation_warping: bool = true
@export var orientation_blend: float = 1.0
@export var max_orientation_angle: float = 90.0  # degrees
@export var spine_bone_names: Array[String] = ["Spine", "Spine1", "Spine2"]
@export var spine_weight_distribution: Array[float] = [0.3, 0.4, 0.3]

## Slope Warping (Phase 2)
@export_group("Slope Warping")
@export var enable_slope_warping: bool = false
@export var slope_raycast_length: float = 1.0
@export var slope_adaptation_speed: float = 10.0
@export var foot_bone_names: Array[String] = ["LeftFoot", "RightFoot"]

## Speed Thresholds
@export_group("Speed Thresholds")
@export var idle_speed_threshold: float = 0.1
@export var walk_speed: float = 2.0
@export var run_speed: float = 5.0
@export var sprint_speed: float = 8.0
```

### 4.2 `PoseWarpingController` (Node)

Purpose: Orchestrates all warping modifiers, manages velocity input, and distributes data.

```gdscript
class_name PoseWarpingController
extends Node

## Signals
signal warping_started()
signal warping_stopped()
signal velocity_updated(velocity: Vector3, speed: float)

## Dependencies (Duck Typed)
@export_group("Velocity Source")
@export var velocity_source: Node  ## Any node with velocity/get_velocity()
@export var direction_source: Node  ## Optional: separate look direction source

@export_group("Skeleton")
@export var skeleton: Skeleton3D

@export_group("Modifiers")
@export var stride_modifier: StrideWarpingModifier
@export var orientation_modifier: OrientationWarpingModifier
@export var slope_modifier: SlopeWarpingModifier  ## Optional

@export_group("Settings")
@export var settings: PoseWarpingSettings

## Public Properties
var enabled: bool = true
var current_velocity: Vector3
var current_speed: float
var movement_direction: Vector3
var look_direction: Vector3
var is_warping: bool = false
```

#### Key Methods

```gdscript
## Called every physics frame
func _physics_process(delta: float) -> void:
    if not enabled or not _validate_dependencies():
        return
    
    _update_velocity()
    _update_directions()
    _distribute_to_modifiers(delta)

## Get velocity using duck typing
func _update_velocity() -> void:
    if velocity_source.has_method("get_velocity"):
        current_velocity = velocity_source.get_velocity()
    elif velocity_source.has_method("get_linear_velocity"):
        current_velocity = velocity_source.get_linear_velocity()
    elif "velocity" in velocity_source:
        current_velocity = velocity_source.velocity
    elif "actual_velocity" in velocity_source:
        current_velocity = velocity_source.actual_velocity
    elif "linear_velocity" in velocity_source:
        current_velocity = velocity_source.linear_velocity
    else:
        push_warning("PoseWarpingController: velocity_source has no velocity property")
        current_velocity = Vector3.ZERO
    
    current_speed = current_velocity.length()
    velocity_updated.emit(current_velocity, current_speed)

## Distribute warping data to modifiers
func _distribute_to_modifiers(delta: float) -> void:
    var should_warp := current_speed > settings.idle_speed_threshold
    
    if should_warp != is_warping:
        is_warping = should_warp
        if is_warping:
            warping_started.emit()
        else:
            warping_stopped.emit()
    
    if stride_modifier and settings.enable_stride_warping:
        stride_modifier.update_warping(current_velocity, current_speed, delta)
    
    if orientation_modifier and settings.enable_orientation_warping:
        orientation_modifier.update_warping(movement_direction, look_direction, delta)
    
    if slope_modifier and settings.enable_slope_warping:
        slope_modifier.update_warping(velocity_source.global_position, delta)
```

### 4.3 `StrideWarpingModifier` (SkeletonModifier3D)

Purpose: Adjusts leg bone transforms to match actual movement speed, reducing foot sliding.

```gdscript
class_name StrideWarpingModifier
extends SkeletonModifier3D

@export var settings: PoseWarpingSettings

## Cached bone indices
var _leg_bone_indices: Array[int] = []
var _current_speed_scale: float = 1.0

func _ready() -> void:
    _cache_bone_indices()

func _cache_bone_indices() -> void:
    if not get_skeleton():
        return
    _leg_bone_indices.clear()
    for bone_name in settings.leg_bone_names:
        var idx := get_skeleton().find_bone(bone_name)
        if idx >= 0:
            _leg_bone_indices.append(idx)

func update_warping(velocity: Vector3, speed: float, delta: float) -> void:
    if speed < settings.min_speed_for_stride:
        _current_speed_scale = lerp(_current_speed_scale, 1.0, delta * 10.0)
        return
    
    # Calculate speed scale based on animation vs actual speed
    var animation_speed := settings.walk_speed  # Base animation speed
    var target_scale := clamp(speed / animation_speed, 0.5, settings.max_speed_scale)
    _current_speed_scale = lerp(_current_speed_scale, target_scale, delta * 10.0)

func _process_modification() -> void:
    if not settings.enable_stride_warping:
        return
    
    var skeleton := get_skeleton()
    if not skeleton:
        return
    
    # Apply stride scaling to leg bones
    for bone_idx in _leg_bone_indices:
        var pose := skeleton.get_bone_pose(bone_idx)
        # Scale the bone's local transform to adjust stride length
        pose.origin *= Vector3(1.0, 1.0, _current_speed_scale)
        skeleton.set_bone_pose(bone_idx, pose)
```

### 4.4 `OrientationWarpingModifier` (SkeletonModifier3D)

Purpose: Rotates spine bones to face the look direction while legs follow movement direction.

```gdscript
class_name OrientationWarpingModifier
extends SkeletonModifier3D

@export var settings: PoseWarpingSettings

## Cached bone indices and weights
var _spine_bone_indices: Array[int] = []
var _spine_weights: Array[float] = []
var _current_rotation_offset: float = 0.0

func _ready() -> void:
    _cache_bone_indices()

func _cache_bone_indices() -> void:
    if not get_skeleton():
        return
    _spine_bone_indices.clear()
    _spine_weights.clear()
    
    for i in settings.spine_bone_names.size():
        var bone_name: String = settings.spine_bone_names[i]
        var idx := get_skeleton().find_bone(bone_name)
        if idx >= 0:
            _spine_bone_indices.append(idx)
            var weight: float = settings.spine_weight_distribution[i] if i < settings.spine_weight_distribution.size() else 0.33
            _spine_weights.append(weight)

func update_warping(movement_dir: Vector3, look_dir: Vector3, delta: float) -> void:
    if movement_dir.is_zero_approx() or look_dir.is_zero_approx():
        _current_rotation_offset = lerp(_current_rotation_offset, 0.0, delta * 10.0)
        return
    
    # Calculate angle between movement and look directions (horizontal plane)
    var move_flat := Vector2(movement_dir.x, movement_dir.z).normalized()
    var look_flat := Vector2(look_dir.x, look_dir.z).normalized()
    var angle_diff := move_flat.angle_to(look_flat)
    
    # Clamp to max orientation angle
    var max_rad := deg_to_rad(settings.max_orientation_angle)
    angle_diff = clamp(angle_diff, -max_rad, max_rad)
    
    _current_rotation_offset = lerp(_current_rotation_offset, angle_diff, delta * 10.0)

func _process_modification() -> void:
    if not settings.enable_orientation_warping:
        return
    
    var skeleton := get_skeleton()
    if not skeleton:
        return
    
    # Distribute rotation across spine bones
    for i in _spine_bone_indices.size():
        var bone_idx: int = _spine_bone_indices[i]
        var weight: float = _spine_weights[i] if i < _spine_weights.size() else 0.33
        
        var pose := skeleton.get_bone_pose(bone_idx)
        var rotation_amount := _current_rotation_offset * weight * settings.orientation_blend
        
        # Apply Y-axis rotation to spine
        var additional_rotation := Basis(Vector3.UP, rotation_amount)
        pose.basis = additional_rotation * pose.basis
        skeleton.set_bone_pose(bone_idx, pose)
```

### 4.5 `SlopeWarpingModifier` (SkeletonModifier3D) — Phase 2

Purpose: Adjusts foot placement using raycasts for uneven terrain.

```gdscript
class_name SlopeWarpingModifier
extends SkeletonModifier3D

@export var settings: PoseWarpingSettings
@export var collision_mask: int = 1

## Foot IK targets
var _left_foot_target: Vector3
var _right_foot_target: Vector3
var _left_foot_bone_idx: int = -1
var _right_foot_bone_idx: int = -1

func _ready() -> void:
    _cache_bone_indices()

func _cache_bone_indices() -> void:
    if not get_skeleton() or settings.foot_bone_names.size() < 2:
        return
    _left_foot_bone_idx = get_skeleton().find_bone(settings.foot_bone_names[0])
    _right_foot_bone_idx = get_skeleton().find_bone(settings.foot_bone_names[1])

func update_warping(character_position: Vector3, delta: float) -> void:
    if not settings.enable_slope_warping:
        return
    
    # Raycast for each foot
    _left_foot_target = _raycast_foot_position(character_position + Vector3(-0.15, 0.5, 0.0))
    _right_foot_target = _raycast_foot_position(character_position + Vector3(0.15, 0.5, 0.0))

func _raycast_foot_position(origin: Vector3) -> Vector3:
    var space_state := get_skeleton().get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(
        origin,
        origin + Vector3.DOWN * settings.slope_raycast_length,
        collision_mask
    )
    var result := space_state.intersect_ray(query)
    
    if result:
        return result.position
    return origin + Vector3.DOWN * 0.5  # Default foot height

func _process_modification() -> void:
    if not settings.enable_slope_warping:
        return
    
    # Apply foot IK adjustments
    # Note: Full IK implementation would use Godot's SkeletonIK3D
    # This is a simplified version that adjusts foot bone positions
    pass
```

## 5) Plugin Registration

### 5.1 `plugin.cfg`

```ini
[plugin]

name="Pose Warping"
description="Procedural animation warping for stride matching, orientation, and slope adaptation"
author="Your Name"
version="1.0.0"
script="pose_warping_plugin.gd"
```

### 5.2 `pose_warping_plugin.gd`

```gdscript
@tool
extends EditorPlugin

func _enter_tree() -> void:
    add_custom_type(
        "PoseWarpingController",
        "Node",
        preload("core/pose_warping_controller.gd"),
        preload("icons/pose_warping.svg")
    )
    add_custom_type(
        "StrideWarpingModifier",
        "SkeletonModifier3D",
        preload("core/stride_warping_modifier.gd"),
        null
    )
    add_custom_type(
        "OrientationWarpingModifier",
        "SkeletonModifier3D",
        preload("core/orientation_warping_modifier.gd"),
        null
    )
    add_custom_type(
        "SlopeWarpingModifier",
        "SkeletonModifier3D",
        preload("core/slope_warping_modifier.gd"),
        null
    )

func _exit_tree() -> void:
    remove_custom_type("PoseWarpingController")
    remove_custom_type("StrideWarpingModifier")
    remove_custom_type("OrientationWarpingModifier")
    remove_custom_type("SlopeWarpingModifier")
```

## 6) Integration Examples

### 6.1 With PlayerMotor3D (player_control_core)

```gdscript
# In your character scene, add PoseWarpingController as child of Skeleton3D
# Wire the velocity_source to your PlayerMotor3D or CharacterBody3D

# Example scene structure:
# Player (CharacterBody3D)
#   ├── PlayerController
#   │   ├── PlayerMotor3D
#   │   └── PlayerStateMachine
#   └── CharacterMesh
#       └── Skeleton3D
#           ├── PoseWarpingController
#           ├── StrideWarpingModifier
#           └── OrientationWarpingModifier
```

### 6.2 With CharacterBody3D Directly

```gdscript
# pose_warping_controller.velocity_source = $".." (CharacterBody3D)
# The controller will read the body's velocity property directly
```

### 6.3 With RigidBody3D

```gdscript
# pose_warping_controller.velocity_source = $RigidBody3D
# The controller will detect linear_velocity property
```

## 7) Implementation Phases

### Phase 1 — Core Infrastructure (MVP)

#### Sprint 1.1: Addon Scaffold
- [ ] Create addon folder structure
- [ ] Create `plugin.cfg` and `pose_warping_plugin.gd`
- [ ] Create `PoseWarpingSettings` resource with all properties
- [ ] Create README.md with usage instructions

#### Sprint 1.2: Controller and Stride Warping
- [ ] Implement `PoseWarpingController` with duck-typed velocity detection
- [ ] Implement `StrideWarpingModifier` with speed-based leg scaling
- [ ] Add bone index caching for performance
- [ ] Test with CharacterBody3D

#### Sprint 1.3: Orientation Warping
- [ ] Implement `OrientationWarpingModifier`
- [ ] Add spine bone rotation distribution
- [ ] Add angle clamping and smooth blending
- [ ] Test with third-person camera setup

### Phase 2 — Advanced Features

#### Sprint 2.1: Slope Warping
- [ ] Implement `SlopeWarpingModifier` with raycasts
- [ ] Add foot IK target calculation
- [ ] Integrate with terrain/ground detection
- [ ] Test on uneven terrain

#### Sprint 2.2: Polish and Optimization
- [ ] Add animation curve support for blend weights
- [ ] Profile and optimize bone lookups
- [ ] Add debug visualization (optional)
- [ ] Create example scenes

## 8) Testing Checklist

### Stride Warping
- [ ] No foot sliding at walk speed
- [ ] No foot sliding at run speed
- [ ] Smooth transition between speeds
- [ ] Works with different skeleton rigs

### Orientation Warping
- [ ] Spine follows camera direction
- [ ] Legs maintain movement direction
- [ ] Smooth blending when changing direction
- [ ] Respects max angle limits

### Slope Warping (Phase 2)
- [ ] Feet plant on sloped surfaces
- [ ] No foot clipping through ground
- [ ] Smooth adaptation when terrain changes

### Integration
- [ ] Works with CharacterBody3D
- [ ] Works with RigidBody3D
- [ ] Works with PlayerMotor3D (player_control_core)
- [ ] No errors when velocity_source is null
- [ ] Graceful degradation with missing bones

## 9) Performance Considerations

- **Bone caching:** Cache bone indices on `_ready()`, not every frame
- **Conditional updates:** Skip warping when character is idle
- **LOD support:** Consider disabling warping for distant characters
- **Modifier order:** SkeletonModifier3D processes in tree order; ensure correct modifier sequence

## 10) Open Decisions

| Decision | Options | Recommendation |
|----------|---------|----------------|
| Velocity source detection | Duck typing vs interface | Duck typing (simpler, GDScript-idiomatic) |
| Blend curve type | Linear vs Curve resource | Curve resource (more control) |
| Foot IK approach | Manual bone adjustment vs SkeletonIK3D | SkeletonIK3D for slope warping (Phase 2) |
| Warping in air | Continue vs disable | Disable (smoother transitions) |

# Movement Addon Improvement Plan

## 0) Context and Constraints (Project Rules)
This repository uses a **modular addon architecture**:
- Each mechanic is a self-contained addon under `addons/<addon_name>/`.
- **Data layer:** `Resource` types in `core/` (pure data + validation).
- **Logic layer:** `Node` components/controllers/handlers in `core/`.
- **Dependency injection:** use `@export` for external dependencies; guard nulls; avoid tree traversal.
- **Decoupled communication:** use signals with sufficient context.

This plan covers improvements to the existing `player_control_core`, `player_control_fps`, and `player_control_3rd_person` addons, inspired by the Advanced Movement System Godot (AMSG) repository.

## 1) Improvement Summary

| Feature | Priority | Complexity | Addon Affected |
|---------|----------|------------|----------------|
| RigidBody3D Support | High | Medium | `player_control_core` |
| Actual Velocity Tracking | High | Low | `player_control_core` |
| Mantling System | Medium | High | `player_control_core` |
| Extended Rotation Modes | Medium | Low | `player_control_3rd_person` |
| Rotate-in-Place | Medium | Medium | `player_control_core` |
| Per-Stance Settings | Low | Low | `player_control_core` |
| Body Tilt | Low | Low | `player_control_3rd_person` |

---

## 2) RigidBody3D Support

### 2.1 Goals
- Support both `CharacterBody3D` and `RigidBody3D` as movement targets
- Use duck typing pattern (GDScript-idiomatic) instead of abstract class hierarchy
- Maintain backward compatibility with existing CharacterBody3D code

### 2.2 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      PlayerMotor3D                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                 Duck Typing Detection                        ││
│  │  if body.has_method("move_and_slide"):                      ││
│  │      → CharacterBody3D path                                  ││
│  │  elif body.has_method("apply_central_force"):               ││
│  │      → RigidBody3D path                                      ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│          ┌───────────────────┴───────────────────┐              │
│          ▼                                       ▼              │
│  ┌───────────────────┐               ┌───────────────────┐      │
│  │ CharacterBody3D   │               │ RigidBody3D       │      │
│  │ - velocity =      │               │ - apply_force()   │      │
│  │ - move_and_slide()│               │ - is_sleeping()   │      │
│  │ - is_on_floor()   │               │ - contact_count   │      │
│  └───────────────────┘               └───────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Changes to `PlayerMotor3D`

```gdscript
class_name PlayerMotor3D
extends Node

## Body type detection (duck typing)
enum BodyType { UNKNOWN, CHARACTER_BODY, RIGID_BODY }

@export var body: Node3D  ## Changed from CharacterBody3D to Node3D

var _body_type: BodyType = BodyType.UNKNOWN
var _cached_is_grounded: bool = false

func _ready() -> void:
    _detect_body_type()

func _detect_body_type() -> void:
    if not body:
        _body_type = BodyType.UNKNOWN
        return
    
    if body.has_method("move_and_slide"):
        _body_type = BodyType.CHARACTER_BODY
    elif body.has_method("apply_central_force"):
        _body_type = BodyType.RIGID_BODY
    else:
        _body_type = BodyType.UNKNOWN
        push_warning("PlayerMotor3D: body is neither CharacterBody3D nor RigidBody3D")
```

### 2.4 Physics Processing by Body Type

```gdscript
func _physics_process(delta: float) -> void:
    if not enabled or not body:
        return
    
    match _body_type:
        BodyType.CHARACTER_BODY:
            _process_character_body(delta)
        BodyType.RIGID_BODY:
            _process_rigid_body(delta)

func _process_character_body(delta: float) -> void:
    _update_grounded_state_character()
    _apply_horizontal_movement_character(delta)
    body.move_and_slide()
    _calculate_actual_velocity(delta)

func _process_rigid_body(delta: float) -> void:
    _update_grounded_state_rigid()
    _apply_horizontal_movement_rigid(delta)
    _calculate_actual_velocity(delta)
```

### 2.5 Grounded Detection

```gdscript
func _update_grounded_state_character() -> void:
    var was_grounded := is_grounded
    is_grounded = body.is_on_floor()
    if is_grounded != was_grounded:
        grounded_changed.emit(is_grounded)

func _update_grounded_state_rigid() -> void:
    var was_grounded := is_grounded
    
    # Use raycast for RigidBody ground detection
    var space_state := body.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(
        body.global_position,
        body.global_position + Vector3.DOWN * 0.1,
        body.collision_mask
    )
    query.exclude = [body.get_rid()]
    var result := space_state.intersect_ray(query)
    
    is_grounded = result != null and result.size() > 0
    
    if is_grounded != was_grounded:
        grounded_changed.emit(is_grounded)
```

### 2.6 Movement Application

```gdscript
## CharacterBody3D: Direct velocity assignment
func _apply_horizontal_movement_character(delta: float) -> void:
    var target_velocity := _calculate_target_velocity()
    var accel := acceleration if input_router.movement_intent.length() > 0.1 else deceleration
    
    body.velocity.x = move_toward(body.velocity.x, target_velocity.x, accel * delta)
    body.velocity.z = move_toward(body.velocity.z, target_velocity.z, accel * delta)

## RigidBody3D: Force-based movement
func _apply_horizontal_movement_rigid(delta: float) -> void:
    var target_velocity := _calculate_target_velocity()
    var current_velocity := Vector3(body.linear_velocity.x, 0, body.linear_velocity.z)
    var velocity_diff := target_velocity - current_velocity
    
    # Apply force proportional to velocity difference
    var force := velocity_diff * _rigid_body_force_multiplier
    body.apply_central_force(force)
    
    # Clamp horizontal velocity
    var horizontal := Vector2(body.linear_velocity.x, body.linear_velocity.z)
    if horizontal.length() > current_speed:
        horizontal = horizontal.normalized() * current_speed
        body.linear_velocity.x = horizontal.x
        body.linear_velocity.z = horizontal.y
```

### 2.7 Jump Implementation

```gdscript
func try_jump() -> bool:
    if not is_grounded:
        return false
    
    match _body_type:
        BodyType.CHARACTER_BODY:
            body.velocity.y = movement_settings.jump_velocity
        BodyType.RIGID_BODY:
            body.apply_central_impulse(Vector3.UP * movement_settings.jump_velocity * body.mass)
    
    jumped.emit()
    return true
```

### 2.8 New Settings

Add to `MovementSettings3D`:

```gdscript
@export_group("RigidBody Settings")
@export var rigid_body_force_multiplier: float = 50.0
@export var rigid_body_drag: float = 5.0
@export var rigid_body_ground_raycast_distance: float = 0.1
```

---

## 3) Actual Velocity Tracking

### 3.1 Goals
- Track the actual displacement per physics frame (not just input-desired velocity)
- Enable pose warping integration
- Detect "stuck" situations (input velocity != actual velocity)

### 3.2 Implementation in `PlayerMotor3D`

```gdscript
## New signals
signal velocity_changed(velocity: Vector3, speed: float)

## New properties
var actual_velocity: Vector3  ## Real displacement per frame
var previous_position: Vector3
var is_moving: bool:
    get: return actual_velocity.length() > 0.1
var input_is_moving: bool:
    get: return input_router and input_router.movement_intent.length() > 0.1

## Add to _physics_process after move_and_slide / force application
func _calculate_actual_velocity(delta: float) -> void:
    if delta > 0:
        actual_velocity = (body.global_position - previous_position) / delta
    else:
        actual_velocity = Vector3.ZERO
    previous_position = body.global_position
    velocity_changed.emit(actual_velocity, actual_velocity.length())

## Public getter for duck typing (pose warping integration)
func get_velocity() -> Vector3:
    return actual_velocity

func get_speed() -> float:
    return actual_velocity.length()
```

---

## 4) Mantling System

### 4.1 Goals
- Detect ledges using raycasts
- Create `MantleState` that handles climbing animation
- Use programmatic position interpolation with configurable curve (not root motion)

### 4.2 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PlayerStateMachine                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │GroundedState│  │AirborneState│  │ MantleState │ ◄── NEW      │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                │                │                      │
│         └────────────────┴────────────────┘                      │
│                          │                                       │
│                          ▼                                       │
│              ┌───────────────────────┐                          │
│              │   MantleDetector      │ (child of AirborneState)  │
│              │   - forward_ray       │                          │
│              │   - ground_ray        │                          │
│              │   - clearance_ray     │                          │
│              └───────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 `MantleSettings3D` Resource

```gdscript
class_name MantleSettings3D
extends Resource

@export_group("Detection")
@export var forward_ray_length: float = 0.8
@export var forward_ray_height: float = 0.5  ## Height above character origin
@export var ground_ray_length: float = 1.5
@export var clearance_ray_length: float = 1.0
@export var min_ledge_height: float = 0.5
@export var max_ledge_height: float = 2.0

@export_group("Movement")
@export var mantle_duration: float = 0.5
@export var mantle_curve: Curve  ## Position interpolation curve
@export var mantle_height_offset: float = 0.1  ## Extra height clearance

@export_group("Animation")
@export var low_mantle_threshold: float = 1.0  ## Below = low mantle
@export var high_mantle_animation: StringName = &"high_mantle"
@export var low_mantle_animation: StringName = &"low_mantle"
```

### 4.4 `MantleDetector` Component

```gdscript
class_name MantleDetector
extends Node

signal ledge_detected(ledge_position: Vector3, ledge_normal: Vector3, ledge_height: float)

@export var settings: MantleSettings3D
@export var body: CharacterBody3D
@export var collision_mask: int = 1

## Detect if a mantleable ledge is in front
func check_for_ledge() -> Dictionary:
    if not body:
        return {}
    
    var forward := -body.global_transform.basis.z
    var origin := body.global_position + Vector3.UP * settings.forward_ray_height
    
    # Step 1: Forward ray - check for wall
    var forward_result := _raycast(origin, forward * settings.forward_ray_length)
    if not forward_result:
        return {}  # No wall ahead
    
    # Step 2: Ground ray from above - find ledge top
    var ledge_check_origin := forward_result.position + forward * 0.1 + Vector3.UP * settings.ground_ray_length
    var ground_result := _raycast(ledge_check_origin, Vector3.DOWN * settings.ground_ray_length)
    if not ground_result:
        return {}  # No ledge top found
    
    # Step 3: Calculate ledge height
    var ledge_height := ground_result.position.y - body.global_position.y
    if ledge_height < settings.min_ledge_height or ledge_height > settings.max_ledge_height:
        return {}  # Outside mantleable range
    
    # Step 4: Clearance ray - check if we can fit on top
    var clearance_origin := ground_result.position + Vector3.UP * 0.1
    var clearance_result := _raycast(clearance_origin, Vector3.UP * settings.clearance_ray_length)
    if clearance_result:
        return {}  # Not enough clearance
    
    var result := {
        "position": ground_result.position + Vector3.UP * settings.mantle_height_offset,
        "normal": forward_result.normal,
        "height": ledge_height
    }
    
    ledge_detected.emit(result.position, result.normal, result.height)
    return result

func _raycast(origin: Vector3, direction: Vector3) -> Dictionary:
    var space_state := body.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction, collision_mask)
    query.exclude = [body.get_rid()]
    return space_state.intersect_ray(query)
```

### 4.5 `MantleState` Implementation

```gdscript
class_name MantleState
extends PlayerState

@export var mantle_settings: MantleSettings3D
@export var mantle_detector: MantleDetector

## Mantle state
var _start_position: Vector3
var _target_position: Vector3
var _mantle_timer: float = 0.0
var _mantle_height: float = 0.0
var _is_high_mantle: bool = false

func enter() -> void:
    motor.enabled = false  # Disable normal movement
    
    # Get ledge data from detector (passed via state context)
    var ledge_data := state_machine.get_meta("mantle_ledge_data", {})
    if ledge_data.is_empty():
        transition_to(&"airborne")
        return
    
    _start_position = controller.body.global_position
    _target_position = ledge_data.position
    _mantle_height = ledge_data.height
    _mantle_timer = 0.0
    
    # Determine mantle type
    _is_high_mantle = _mantle_height > mantle_settings.low_mantle_threshold
    
    # Request animation
    var anim_name := mantle_settings.high_mantle_animation if _is_high_mantle else mantle_settings.low_mantle_animation
    request_animation(anim_name, 0.1)

func exit() -> void:
    motor.enabled = true
    state_machine.remove_meta("mantle_ledge_data")

func physics_update(delta: float) -> void:
    _mantle_timer += delta
    var progress := _mantle_timer / mantle_settings.mantle_duration
    
    if progress >= 1.0:
        # Mantle complete
        controller.body.global_position = _target_position
        controller.body.velocity = Vector3.ZERO
        transition_to(&"grounded")
        return
    
    # Apply curve if available
    var curved_progress := progress
    if mantle_settings.mantle_curve:
        curved_progress = mantle_settings.mantle_curve.sample(progress)
    
    # Interpolate position
    var current_pos := _start_position.lerp(_target_position, curved_progress)
    
    # Add arc for visual appeal
    var arc_height := _mantle_height * 0.3 * sin(progress * PI)
    current_pos.y += arc_height
    
    controller.body.global_position = current_pos
```

### 4.6 Integration with `AirborneState`

Add mantle detection check:

```gdscript
## In AirborneState.physics_update()
func physics_update(delta: float) -> void:
    # ... existing jump buffer and coyote time logic ...
    
    # Check for mantle opportunity
    if _mantle_detector and input_router.movement_intent.y > 0.5:  # Moving forward
        var ledge_data := _mantle_detector.check_for_ledge()
        if not ledge_data.is_empty():
            state_machine.set_meta("mantle_ledge_data", ledge_data)
            transition_to(&"mantle")
            return
    
    # ... rest of airborne logic ...
```

---

## 5) Extended Rotation Modes

### 5.1 Goals
- Add `AIMING` mode: tight strafe with FOV zoom
- Add `LOCK_ON` mode: face a locked target node
- Smooth transitions between modes

### 5.2 Extended Enum

```gdscript
## In ThirdPersonController3D and DualPerspectiveController3D
enum RotationMode {
    FACE_MOVEMENT,  ## Rotate toward velocity direction
    STRAFE,         ## Face camera direction
    FREE,           ## No automatic rotation
    AIMING,         ## Precision strafe with FOV zoom and tighter rotation
    LOCK_ON         ## Face locked target node
}
```

### 5.3 New Properties

```gdscript
@export_group("Aiming Mode")
@export var aiming_fov: float = 50.0  ## FOV when aiming
@export var aiming_rotation_speed: float = 20.0  ## Faster rotation when aiming
@export var aiming_fov_transition_speed: float = 10.0

@export_group("Lock-On Mode")
@export var lock_on_target: Node3D  ## Target to face
@export var lock_on_rotation_speed: float = 15.0
@export var max_lock_on_distance: float = 20.0
@export var auto_break_lock_on: bool = true  ## Break when target too far
```

### 5.4 Updated Rotation Logic

```gdscript
func _update_character_rotation(delta: float) -> void:
    if not body:
        return
    
    var target_rotation: float = body.rotation.y
    var current_rotation_speed := rotation_speed
    
    match rotation_mode:
        RotationMode.FACE_MOVEMENT:
            if motor.is_moving:
                var move_dir := motor.actual_velocity
                move_dir.y = 0
                if move_dir.length() > 0.1:
                    target_rotation = atan2(-move_dir.x, -move_dir.z)
        
        RotationMode.STRAFE:
            target_rotation = camera_controller.yaw
        
        RotationMode.FREE:
            return  # No rotation
        
        RotationMode.AIMING:
            target_rotation = camera_controller.yaw
            current_rotation_speed = aiming_rotation_speed
            _update_aiming_fov(delta)
        
        RotationMode.LOCK_ON:
            if _is_lock_on_valid():
                var to_target := lock_on_target.global_position - body.global_position
                to_target.y = 0
                if to_target.length() > 0.1:
                    target_rotation = atan2(-to_target.x, -to_target.z)
                current_rotation_speed = lock_on_rotation_speed
            else:
                _break_lock_on()
    
    # Smooth rotation
    body.rotation.y = lerp_angle(body.rotation.y, target_rotation, current_rotation_speed * delta)

func _update_aiming_fov(delta: float) -> void:
    var target_fov := aiming_fov if rotation_mode == RotationMode.AIMING else _default_fov
    camera_controller.camera.fov = lerp(camera_controller.camera.fov, target_fov, aiming_fov_transition_speed * delta)

func _is_lock_on_valid() -> bool:
    if not lock_on_target or not is_instance_valid(lock_on_target):
        return false
    if auto_break_lock_on:
        var distance := body.global_position.distance_to(lock_on_target.global_position)
        return distance <= max_lock_on_distance
    return true

func _break_lock_on() -> void:
    lock_on_target = null
    rotation_mode = RotationMode.FACE_MOVEMENT
```

### 5.5 Public API for Lock-On

```gdscript
signal lock_on_started(target: Node3D)
signal lock_on_ended()

func set_lock_on_target(target: Node3D) -> void:
    lock_on_target = target
    if target:
        rotation_mode = RotationMode.LOCK_ON
        lock_on_started.emit(target)
    else:
        rotation_mode = RotationMode.FACE_MOVEMENT
        lock_on_ended.emit()

func clear_lock_on() -> void:
    set_lock_on_target(null)
```

---

## 6) Rotate-in-Place

### 6.1 Goals
- Trigger turn animations when camera exceeds angle threshold while stationary
- Suppress forward movement until rotation completes
- Smooth transition back to movement

### 6.2 New Settings in `MovementSettings3D`

```gdscript
@export_group("Rotate in Place")
@export var enable_rotate_in_place: bool = true
@export var rotation_threshold_degrees: float = 90.0
@export var rotation_in_place_speed: float = 180.0  ## degrees per second
@export var turn_left_animation: StringName = &"turn_left"
@export var turn_right_animation: StringName = &"turn_right"
```

### 6.3 Implementation in `GroundedState`

```gdscript
## Add to GroundedState
var _is_rotating_in_place: bool = false
var _rotation_target: float = 0.0

func physics_update(delta: float) -> void:
    # ... existing logic ...
    
    # Check for rotate-in-place (only when not moving)
    if movement_settings.enable_rotate_in_place and not motor.is_moving:
        _check_rotate_in_place(delta)
    else:
        _is_rotating_in_place = false
    
    # ... rest of update ...

func _check_rotate_in_place(delta: float) -> void:
    var body := controller.body
    var camera_yaw := _get_camera_yaw()
    var body_yaw := body.rotation.y
    
    var angle_diff := rad_to_deg(angle_difference(body_yaw, camera_yaw))
    
    if abs(angle_diff) > movement_settings.rotation_threshold_degrees:
        if not _is_rotating_in_place:
            _is_rotating_in_place = true
            _rotation_target = camera_yaw
            
            # Request turn animation
            var anim_name := movement_settings.turn_left_animation if angle_diff < 0 else movement_settings.turn_right_animation
            request_animation(anim_name, 0.1)
    
    if _is_rotating_in_place:
        # Rotate toward target
        var rotation_speed := deg_to_rad(movement_settings.rotation_in_place_speed)
        body.rotation.y = rotate_toward(body.rotation.y, _rotation_target, rotation_speed * delta)
        
        # Check if rotation complete
        if abs(angle_difference(body.rotation.y, _rotation_target)) < deg_to_rad(5.0):
            _is_rotating_in_place = false
            request_animation(&"idle", 0.2)

func _get_camera_yaw() -> float:
    # Get from controller's camera system
    if controller.has_method("get_camera_yaw"):
        return controller.get_camera_yaw()
    return 0.0
```

---

## 7) Per-Stance Settings

### 7.1 Goals
- Allow different speed/acceleration per stance (crouch, sprint)
- Optional override resources (null = use base values)

### 7.2 Extended `MovementSettings3D`

```gdscript
@export_group("Stance Overrides")
@export var crouch_settings_override: MovementSettings3D  ## Optional
@export var sprint_settings_override: MovementSettings3D  ## Optional

## Get effective speed for current stance
func get_walk_speed_for_stance(is_crouching: bool, is_sprinting: bool) -> float:
    if is_crouching and crouch_settings_override:
        return crouch_settings_override.walk_speed
    elif is_sprinting and sprint_settings_override:
        return sprint_settings_override.walk_speed  # Sprint uses its own "walk" as run speed
    return walk_speed

func get_acceleration_for_stance(is_crouching: bool, is_sprinting: bool) -> float:
    if is_crouching and crouch_settings_override:
        return crouch_settings_override.acceleration
    elif is_sprinting and sprint_settings_override:
        return sprint_settings_override.acceleration
    return acceleration
```

### 7.3 Motor Integration

```gdscript
## In PlayerMotor3D
func _get_current_acceleration() -> float:
    if movement_settings.crouch_settings_override or movement_settings.sprint_settings_override:
        var is_crouching := input_router.crouch_held if input_router else false
        var is_sprinting := input_router.sprint_held if input_router else false
        return movement_settings.get_acceleration_for_stance(is_crouching, is_sprinting)
    
    return movement_settings.acceleration if input_router.movement_intent.length() > 0.1 else movement_settings.deceleration
```

---

## 8) Body Tilt

### 8.1 Goals
- Tilt character mesh toward movement direction
- Optional feature with configurable intensity

### 8.2 New Properties in `ThirdPersonController3D`

```gdscript
@export_group("Body Tilt")
@export var enable_body_tilt: bool = false
@export var character_mesh: Node3D  ## Mesh to tilt (not the body)
@export var tilt_amount: float = 5.0  ## Max tilt degrees
@export var tilt_speed: float = 10.0  ## Interpolation speed
```

### 8.3 Implementation

```gdscript
## Add to ThirdPersonController3D._physics_process()
func _physics_process(delta: float) -> void:
    # ... existing logic ...
    
    if enable_body_tilt and character_mesh:
        _update_body_tilt(delta)

func _update_body_tilt(delta: float) -> void:
    var target_tilt := Vector3.ZERO
    
    if motor.is_moving:
        var velocity := motor.actual_velocity
        velocity.y = 0
        
        if velocity.length() > 0.5:
            var speed_factor := clamp(velocity.length() / movement_settings.sprint_speed, 0.0, 1.0)
            
            # Calculate tilt based on velocity relative to body facing
            var local_velocity := body.global_transform.basis.inverse() * velocity.normalized()
            
            # Forward tilt (pitch) based on forward speed
            target_tilt.x = -local_velocity.z * deg_to_rad(tilt_amount) * speed_factor
            
            # Side tilt (roll) based on strafe
            target_tilt.z = local_velocity.x * deg_to_rad(tilt_amount) * speed_factor
    
    # Smooth interpolation
    character_mesh.rotation.x = lerp(character_mesh.rotation.x, target_tilt.x, tilt_speed * delta)
    character_mesh.rotation.z = lerp(character_mesh.rotation.z, target_tilt.z, tilt_speed * delta)
```

---

## 9) Implementation Phases

### Phase 1 — Core Improvements (High Priority)

#### Sprint 1.1: Actual Velocity Tracking
- [ ] Add `actual_velocity`, `previous_position` to `PlayerMotor3D`
- [ ] Add `is_moving` property
- [ ] Add `velocity_changed` signal
- [ ] Add `get_velocity()` method for duck typing
- [ ] Test with existing controllers

#### Sprint 1.2: RigidBody3D Support
- [ ] Change `body` export from `CharacterBody3D` to `Node3D`
- [ ] Add body type detection via duck typing
- [ ] Implement `_process_rigid_body()` path
- [ ] Implement raycast-based ground detection for RigidBody
- [ ] Add RigidBody settings to `MovementSettings3D`
- [ ] Test with both body types

### Phase 2 — Rotation Features (Medium Priority)

#### Sprint 2.1: Extended Rotation Modes
- [ ] Add `AIMING` and `LOCK_ON` to `RotationMode` enum
- [ ] Implement aiming mode with FOV zoom
- [ ] Implement lock-on mode with target tracking
- [ ] Add lock-on signals and public API
- [ ] Test mode transitions

#### Sprint 2.2: Rotate-in-Place
- [ ] Add rotate-in-place settings to `MovementSettings3D`
- [ ] Implement angle threshold detection in `GroundedState`
- [ ] Add turn animation requests
- [ ] Test with turn animations

### Phase 3 — Mantling System (Medium Priority)

#### Sprint 3.1: Mantle Detection
- [ ] Create `MantleSettings3D` resource
- [ ] Create `MantleDetector` component
- [ ] Implement multi-raycast ledge detection
- [ ] Test detection accuracy

#### Sprint 3.2: Mantle State
- [ ] Create `MantleState` extending `PlayerState`
- [ ] Implement curve-based position interpolation
- [ ] Add high/low mantle differentiation
- [ ] Integrate with `AirborneState`
- [ ] Test full mantle flow

### Phase 4 — Polish (Low Priority)

#### Sprint 4.1: Per-Stance Settings
- [ ] Add optional override resources to `MovementSettings3D`
- [ ] Add stance-aware getter methods
- [ ] Update motor to use stance settings
- [ ] Test with crouch/sprint

#### Sprint 4.2: Body Tilt
- [ ] Add body tilt properties to `ThirdPersonController3D`
- [ ] Implement velocity-based tilt calculation
- [ ] Test visual result

---

## 10) Testing Checklist

### RigidBody3D Support
- [ ] CharacterBody3D still works (no regression)
- [ ] RigidBody3D movement feels responsive
- [ ] Ground detection works for RigidBody
- [ ] Jump works with both body types
- [ ] Transitions between states work

### Actual Velocity Tracking
- [ ] `actual_velocity` matches real displacement
- [ ] `is_moving` correctly reflects movement state
- [ ] Works with CharacterBody3D
- [ ] Works with RigidBody3D
- [ ] Pose warping can connect via duck typing

### Mantling
- [ ] Ledge detection triggers at correct height range
- [ ] High mantle animation plays for tall ledges
- [ ] Low mantle animation plays for short ledges
- [ ] Position interpolation is smooth
- [ ] No clipping through geometry
- [ ] Returns to grounded state correctly

### Rotation Modes
- [ ] FACE_MOVEMENT works as before
- [ ] STRAFE works as before
- [ ] AIMING applies FOV zoom
- [ ] AIMING rotation is tighter
- [ ] LOCK_ON faces target correctly
- [ ] LOCK_ON breaks at max distance
- [ ] Mode transitions are smooth

### Rotate-in-Place
- [ ] Triggers at correct angle threshold
- [ ] Correct turn direction detected
- [ ] Turn animation plays
- [ ] Movement resumes after rotation
- [ ] No jittering at threshold boundary

---

## 11) File Changes Summary

| File | Changes |
|------|---------|
| `player_motor_3d.gd` | RigidBody support, actual velocity tracking |
| `movement_settings_3d.gd` | RigidBody settings, rotate-in-place settings, stance overrides |
| `grounded_state.gd` | Rotate-in-place logic |
| `airborne_state.gd` | Mantle detection integration |
| `third_person_controller_3d.gd` | Extended rotation modes, body tilt |
| `dual_perspective_controller_3d.gd` | Extended rotation modes |
| **NEW:** `mantle_state.gd` | Mantle state implementation |
| **NEW:** `mantle_detector.gd` | Ledge detection component |
| **NEW:** `mantle_settings_3d.gd` | Mantle configuration resource |
| `player_control_core_plugin.gd` | Register new types |

---

## 12) Open Decisions

| Decision | Options | Recommendation |
|----------|---------|----------------|
| RigidBody force model | PD controller vs simple force | Simple force (easier to tune) |
| Mantle animation source | Root motion vs programmatic | Programmatic (more reliable) |
| Lock-on target selection | Manual vs auto-detect | Manual (game decides targeting) |
| Rotate-in-place threshold | Fixed vs speed-based | Fixed (simpler) |

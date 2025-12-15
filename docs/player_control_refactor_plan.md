# Player Control Refactor Plan — Core, FPS, & Third-Person

## 0) Context and Motivation

The existing `player_control_fps` addon works but has limitations:
- No state machine — gameplay states managed via simple boolean flags
- FPS-specific code mixed with reusable movement logic
- No path to third-person support without duplication

This refactor extracts shared logic into a core addon with a proper state machine, enabling both FPS and third-person implementations to extend a common base.

### Goals
- **State machine** for player states (Grounded, Airborne, UI, etc.)
- **Shared core** addon with motor, input router, and base controller
- **FPS addon** slimmed to camera-specific code only
- **Third-person addon** with orbit camera and camera-relative movement
- **No breaking changes** to external API where possible

### Non-goals (deferred)
- Networked player prediction
- Advanced parkour (wall-run, mantling)
- Multiple simultaneous players

---

## 1) Architecture Overview

```
addons/
├── player_control_core/              # Shared abstractions + state machine
│   ├── plugin.cfg
│   ├── player_control_core_plugin.gd
│   ├── README.md
│   ├── core/
│   │   ├── base_player_controller_3d.gd    # Abstract orchestrator
│   │   ├── player_motor_3d.gd              # Movement physics
│   │   ├── player_input_router_3d.gd       # Input → intent
│   │   ├── movement_settings_3d.gd         # Walk/jump/gravity tuning
│   │   ├── input_actions_3d.gd             # Action name config
│   │   └── state_machine/
│   │       ├── player_state_machine.gd     # State manager
│   │       ├── player_state.gd             # Abstract base state
│   │       ├── grounded_state.gd
│   │       ├── airborne_state.gd
│   │       └── ui_state.gd
│   └── icons/
│
├── player_control_fps/               # FPS-specific (depends on core)
│   ├── plugin.cfg
│   ├── player_control_fps_plugin.gd
│   ├── README.md
│   ├── core/
│   │   ├── fps_player_controller_3d.gd     # Extends BasePlayerController3D
│   │   ├── player_look_controller_3d.gd    # FPS yaw/pitch camera
│   │   └── fps_look_settings_3d.gd         # Sensitivity, pitch limits
│   └── icons/
│
├── player_control_3rd_person/        # Third-person (depends on core)
│   ├── plugin.cfg
│   ├── player_control_3rd_person_plugin.gd
│   ├── README.md
│   ├── core/
│   │   ├── third_person_controller_3d.gd   # Extends BasePlayerController3D
│   │   ├── orbit_camera_controller_3d.gd   # Orbit + spring arm
│   │   └── orbit_camera_settings_3d.gd     # Distance, collision, smoothing
│   └── icons/
```

### Dependency Graph

```
player_control_fps ──────┐
                         ├──► player_control_core
player_control_3rd_person┘
```

Core has no dependencies. FPS and third-person depend on core.

---

## 2) State Machine Design

### 2.1 Why Nodes (Not Resources)

States are implemented as **Nodes** rather than Resources because:
- Easier signal wiring to controller/motor
- Can have child nodes (timers, raycasts)
- Scene tree visibility for debugging
- `_physics_process` and `_process` available

### 2.2 State Machine Structure

```gdscript
class_name PlayerStateMachine
extends Node

signal state_changed(old_state: PlayerState, new_state: PlayerState)

@export var initial_state: PlayerState
@export var controller: BasePlayerController3D

var current_state: PlayerState
var states: Dictionary = {}  # String name → PlayerState
```

### 2.3 Base State Interface

```gdscript
class_name PlayerState
extends Node

## Reference to the owning state machine.
var state_machine: PlayerStateMachine
## Reference to the player controller (via state machine).
var controller: BasePlayerController3D:
    get: return state_machine.controller if state_machine else null

## Called when entering this state.
func enter() -> void:
    pass

## Called when exiting this state.
func exit() -> void:
    pass

## Called every physics frame while active.
func physics_update(delta: float) -> void:
    pass

## Called every frame while active.
func frame_update(delta: float) -> void:
    pass

## Handle input events. Return true if consumed.
func handle_input(event: InputEvent) -> bool:
    return false

## Request transition to another state by name.
func transition_to(state_name: StringName) -> void:
    state_machine.transition_to(state_name)
```

### 2.4 Core States

| State | Entry Condition | Active Behavior | Exit Condition |
|-------|-----------------|-----------------|----------------|
| **Grounded** | `is_on_floor() == true` | Full movement, can jump | Jump pressed OR `is_on_floor() == false` |
| **Airborne** | `is_on_floor() == false` | Air control only, apply gravity | `is_on_floor() == true` |
| **UI** | `set_gameplay_enabled(false)` | Input disabled, motor disabled | `set_gameplay_enabled(true)` |

### 2.5 State Transitions

```
                    ┌─────────────┐
                    │   Grounded  │◄────────────────┐
                    └──────┬──────┘                 │
                           │                        │
                    jump or│                        │landed
                    fall off│                        │
                           ▼                        │
                    ┌─────────────┐                 │
                    │   Airborne  │─────────────────┘
                    └─────────────┘
                           
        ─────────── UI Toggle ───────────
                           │
                           ▼
                    ┌─────────────┐
                    │     UI      │ (can enter from any state)
                    └─────────────┘
```

### 2.6 Sprint/Crouch as Modifiers (Not States)

To avoid state explosion, sprint and crouch are **modifier flags** within `GroundedState`:

```gdscript
class_name GroundedState
extends PlayerState

var is_sprinting: bool = false
var is_crouching: bool = false

func physics_update(delta: float) -> void:
    # Check sprint input
    is_sprinting = Input.is_action_pressed(controller.input_actions.sprint) and not is_crouching
    
    # Adjust motor speed
    if is_sprinting:
        controller.motor.current_speed = controller.movement_settings.sprint_speed
    elif is_crouching:
        controller.motor.current_speed = controller.movement_settings.crouch_speed
    else:
        controller.motor.current_speed = controller.movement_settings.walk_speed
```

---

## 3) Core Addon Components

### 3.1 `BasePlayerController3D` (Abstract)

```gdscript
class_name BasePlayerController3D
extends Node

signal gameplay_enabled_changed(enabled: bool)
signal mouse_capture_requested(mode: Input.MouseMode)

@export_group("Rig References")
@export var body: CharacterBody3D

@export_group("Core Components")
@export var input_router: PlayerInputRouter3D
@export var motor: PlayerMotor3D
@export var state_machine: PlayerStateMachine

@export_group("Settings")
@export var movement_settings: MovementSettings3D
@export var input_actions: InputActions3D

var _gameplay_enabled: bool = true

## Override in subclasses to provide camera-relative or body-relative basis.
func _get_movement_basis() -> Basis:
    return body.global_transform.basis if body else Basis.IDENTITY

## Enable/disable gameplay. Triggers state machine transition.
func set_gameplay_enabled(enabled: bool) -> void:
    if _gameplay_enabled == enabled:
        return
    _gameplay_enabled = enabled
    
    if state_machine:
        if enabled:
            state_machine.transition_to(&"grounded")
        else:
            state_machine.transition_to(&"ui")
    
    gameplay_enabled_changed.emit(enabled)
    mouse_capture_requested.emit(
        Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
    )
```

### 3.2 `PlayerMotor3D` Updates

Add `reference_basis` parameter for camera-relative movement:

```gdscript
class_name PlayerMotor3D
extends Node

## External basis for movement direction. Set by controller.
var movement_basis: Basis = Basis.IDENTITY

func _physics_process(delta: float) -> void:
    # Use movement_basis instead of body.global_transform.basis
    var input_dir := input_router.movement_intent
    var direction := (movement_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    # ... rest of movement logic
```

### 3.3 `MovementSettings3D` (Renamed)

```gdscript
class_name MovementSettings3D
extends Resource

@export_group("Speed")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5

@export_group("Acceleration")
@export var acceleration: float = 10.0
@export var deceleration: float = 10.0
@export var air_control: float = 0.3

@export_group("Jump & Gravity")
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@export_group("Crouch")
@export var crouch_height: float = 1.0
@export var stand_height: float = 1.8
```

### 3.4 `InputActions3D` (Renamed + Extended)

```gdscript
class_name InputActions3D
extends Resource

@export_group("Movement")
@export var move_forward: StringName = &"move_forward"
@export var move_back: StringName = &"move_back"
@export var move_left: StringName = &"move_left"
@export var move_right: StringName = &"move_right"

@export_group("Actions")
@export var jump: StringName = &"jump"
@export var sprint: StringName = &"sprint"
@export var crouch: StringName = &"crouch"
@export var interact: StringName = &"interact"
```

---

## 4) FPS Addon (Refactored)

### 4.1 `FPSPlayerController3D`

```gdscript
class_name FPSPlayerController3D
extends BasePlayerController3D

@export_group("FPS Components")
@export var look_controller: PlayerLookController3D

@export_group("FPS Settings")
@export var look_settings: FPSLookSettings3D

## FPS uses body-relative movement (look direction = move direction).
func _get_movement_basis() -> Basis:
    return body.global_transform.basis if body else Basis.IDENTITY

func _ready() -> void:
    super._ready()
    _wire_look_controller()

func _wire_look_controller() -> void:
    if look_controller:
        look_controller.yaw_node = body
        look_controller.input_router = input_router
        if look_settings:
            look_controller.look_settings = look_settings
```

### 4.2 Files Remaining in FPS Addon

| File | Purpose |
|------|---------|
| `fps_player_controller_3d.gd` | Extends base, wires look controller |
| `player_look_controller_3d.gd` | FPS yaw/pitch on body + pivot |
| `fps_look_settings_3d.gd` | Sensitivity, invert Y, pitch limits |

---

## 5) Third-Person Addon (New)

### 5.1 `ThirdPersonController3D`

```gdscript
class_name ThirdPersonController3D
extends BasePlayerController3D

@export_group("Third-Person Components")
@export var camera_controller: OrbitCameraController3D

@export_group("Third-Person Settings")
@export var camera_settings: OrbitCameraSettings3D

## Third-person uses camera-relative movement (flatten camera forward).
func _get_movement_basis() -> Basis:
    if camera_controller and camera_controller.camera:
        var cam_basis := camera_controller.camera.global_transform.basis
        # Flatten to horizontal plane
        var forward := -cam_basis.z
        forward.y = 0
        forward = forward.normalized()
        var right := cam_basis.x
        right.y = 0
        right = right.normalized()
        return Basis(right, Vector3.UP, -forward)
    return body.global_transform.basis if body else Basis.IDENTITY
```

### 5.2 `OrbitCameraController3D`

```gdscript
class_name OrbitCameraController3D
extends Node

@export_group("References")
@export var target: Node3D           # What to orbit around (usually body)
@export var camera: Camera3D
@export var input_router: PlayerInputRouter3D

@export_group("Settings")
@export var camera_settings: OrbitCameraSettings3D

var yaw: float = 0.0
var pitch: float = 0.0
var current_distance: float = 5.0

func _physics_process(delta: float) -> void:
    if not enabled or not target or not camera:
        return
    
    # Get look input
    var look_delta := input_router.consume_look_delta()
    
    # Apply yaw/pitch to orbit
    yaw -= look_delta.x * camera_settings.orbit_sensitivity
    pitch -= look_delta.y * camera_settings.orbit_sensitivity
    pitch = clamp(pitch, camera_settings.min_pitch, camera_settings.max_pitch)
    
    # Calculate camera position
    var offset := Vector3.ZERO
    offset.z = current_distance
    offset = offset.rotated(Vector3.RIGHT, pitch)
    offset = offset.rotated(Vector3.UP, yaw)
    
    var target_pos := target.global_position + Vector3(0, camera_settings.height_offset, 0)
    var desired_pos := target_pos + offset
    
    # Camera collision (spring arm behavior)
    desired_pos = _check_collision(target_pos, desired_pos)
    
    # Smooth follow
    camera.global_position = camera.global_position.lerp(desired_pos, camera_settings.follow_smoothing * delta)
    camera.look_at(target_pos)

func _check_collision(from: Vector3, to: Vector3) -> Vector3:
    var space_state := target.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [target.get_rid()]
    query.collision_mask = camera_settings.collision_mask
    
    var result := space_state.intersect_ray(query)
    if result:
        return result.position + (from - to).normalized() * camera_settings.collision_margin
    return to
```

### 5.3 `OrbitCameraSettings3D`

```gdscript
class_name OrbitCameraSettings3D
extends Resource

@export_group("Distance")
@export var default_distance: float = 5.0
@export var min_distance: float = 1.5
@export var max_distance: float = 10.0

@export_group("Position")
@export var height_offset: float = 1.5

@export_group("Rotation")
@export var orbit_sensitivity: float = 0.003
@export var min_pitch: float = -1.2   # ~-70 degrees
@export var max_pitch: float = 1.4    # ~80 degrees

@export_group("Smoothing")
@export var follow_smoothing: float = 10.0
@export var rotation_smoothing: float = 15.0

@export_group("Collision")
@export var collision_mask: int = 1
@export var collision_margin: float = 0.2
```

### 5.4 Character Rotation Modes

Third-person often has multiple rotation behaviors:

```gdscript
enum RotationMode {
    FACE_MOVEMENT,    # Body rotates to face movement direction
    STRAFE,           # Body faces camera direction (like FPS but third-person view)
    FREE              # Body rotation independent of input
}

@export var rotation_mode: RotationMode = RotationMode.FACE_MOVEMENT
```

---

## 6) Implementation Sprints

### Sprint 1 — Core Addon Scaffold
**Deliverables:**
- `player_control_core` folder structure
- `plugin.cfg` and `player_control_core_plugin.gd`
- README documenting dependencies
- Move `PlayerMotor3D`, `PlayerInputRouter3D` from FPS
- Rename settings to `MovementSettings3D`, `InputActions3D`
- Add `sprint`, `crouch` action names

**Acceptance Criteria:**
- Core addon enables without errors
- Types registered in editor

### Sprint 2 — State Machine Implementation
**Deliverables:**
- `PlayerStateMachine` node with transition logic
- `PlayerState` abstract base class
- `GroundedState` with sprint/crouch modifiers
- `AirborneState` with air control
- `UIState` that disables input

**Acceptance Criteria:**
- State transitions work based on `is_on_floor()` changes
- UI state entered via `set_gameplay_enabled(false)`
- Sprint/crouch modify speed in grounded state

### Sprint 3 — Base Controller & Motor Updates
**Deliverables:**
- `BasePlayerController3D` with virtual `_get_movement_basis()`
- Motor uses `movement_basis` from controller
- State machine wired to controller
- Controller owns gameplay enable/disable logic

**Acceptance Criteria:**
- Base controller can be extended
- Motor direction respects provided basis

### Sprint 4 — Refactor FPS Addon
**Deliverables:**
- `FPSPlayerController3D extends BasePlayerController3D`
- Remove motor, input router (now in core)
- Update plugin registration
- Update README with core dependency

**Acceptance Criteria:**
- FPS test scene works identically to before
- FPS addon requires core addon enabled

### Sprint 5 — Third-Person Addon
**Deliverables:**
- `player_control_3rd_person` folder structure
- `ThirdPersonController3D`
- `OrbitCameraController3D` with collision
- `OrbitCameraSettings3D`
- `third_person_test_scene.tscn`

**Acceptance Criteria:**
- Camera orbits player smoothly
- Movement is camera-relative
- Camera collides with walls
- UI gating works (inventory toggle)

### Sprint 6 — Polish & Documentation
**Deliverables:**
- Update all READMEs
- Add debug overlays (optional)
- Test both perspectives with inventory integration
- Document state machine extension points

**Acceptance Criteria:**
- Both test scenes fully functional
- Clear documentation for extending states

---

## 7) Migration Guide

### For Existing FPS Users

1. Enable `player_control_core` addon
2. Update `player_control_fps` addon
3. Replace `PlayerController3D` with `FPSPlayerController3D` in scenes
4. State machine auto-wired; old `set_gameplay_enabled()` API still works

### Breaking Changes

| Old | New |
|-----|-----|
| `FPSMovementSettings3D` | `MovementSettings3D` (in core) |
| `FPSInputActions` | `InputActions3D` (in core) |
| `PlayerController3D` | `FPSPlayerController3D` |

---

## 8) Open Decisions

| Decision | Options | Recommendation |
|----------|---------|----------------|
| State machine location | Child of controller vs sibling | **Child** — cleaner hierarchy |
| State node names | `grounded_state` vs `Grounded` | **snake_case** — matches Godot conventions |
| Camera collision method | SpringArm3D vs manual raycast | **Manual raycast** — more control, no extra node |
| Body rotation in 3rd person | Instant vs smoothed | **Smoothed** — feels better, configurable rate |

---

## 9) Testing Checklist

### Core Addon
- [ ] Motor applies movement with custom basis
- [ ] State machine transitions Grounded ↔ Airborne
- [ ] UI state disables all input
- [ ] Sprint/crouch modifiers work in grounded
- [ ] Signals emit correctly on state change

### FPS Addon
- [ ] Look controller still works
- [ ] Body-relative movement correct
- [ ] Inventory toggle disables look + movement
- [ ] Jump works from grounded only

### Third-Person Addon
- [ ] Camera orbits smoothly
- [ ] Camera collides with geometry
- [ ] Movement is camera-relative
- [ ] Character rotates to face movement (FACE_MOVEMENT mode)
- [ ] Strafe mode keeps character facing camera
- [ ] Inventory toggle works

---

## 10) Future Extensions

Once this refactor is complete, adding new features becomes straightforward:

| Feature | Implementation |
|---------|----------------|
| **Swimming** | Add `SwimmingState` in core, detect water volumes |
| **Climbing** | Add `ClimbingState`, detect ladder/climb surfaces |
| **Sliding** | Add `SlidingState` triggered from sprint + crouch |
| **Vehicle** | Add `VehicleState`, disable character motor |
| **Lock-on targeting** | Third-person camera mode, face locked target |

Each feature is a new state or modifier, contained and testable.

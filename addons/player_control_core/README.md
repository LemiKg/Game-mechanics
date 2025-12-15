# Player Control Core

Core player control framework providing shared abstractions for FPS and third-person player controllers.

## Features

- **State Machine** — Formal player states (Grounded, Airborne, UI) with clean transitions
- **Player Motor** — Physics-based movement with configurable speed, acceleration, and gravity
- **Input Router** — Converts raw input to movement intent, decoupled from motor
- **Base Controller** — Abstract orchestrator for camera-specific implementations to extend

## Dependencies

None. This is the base addon that FPS and third-person addons depend on.

## Installation

1. Copy `addons/player_control_core` to your project's `addons/` folder
2. Enable the plugin in Project Settings → Plugins

## Components

### State Machine

| Class | Purpose |
|-------|---------|
| `PlayerStateMachine` | Manages state transitions and delegates updates to active state |
| `PlayerState` | Abstract base for all states |
| `GroundedState` | Active when on floor; handles sprint/crouch modifiers |
| `AirborneState` | Active when airborne; applies gravity and air control |
| `UIState` | Active when gameplay disabled; blocks input |

### Core Components

| Class | Purpose |
|-------|---------|
| `BasePlayerController3D` | Abstract orchestrator; extend for FPS or third-person |
| `DualPerspectiveController3D` | Unified controller supporting both FPS and third-person with runtime toggle |
| `PlayerMotor3D` | Applies velocity to CharacterBody3D based on input intent |
| `PlayerInputRouter3D` | Converts input actions to movement/look intent vectors |

### Resources

| Class | Purpose |
|-------|---------|
| `MovementSettings3D` | Walk/sprint/crouch speed, acceleration, jump, gravity |
| `InputActions3D` | Configurable input action names |

## Usage

This addon is not used directly. Enable one of:
- `player_control_fps` — First-person controller
- `player_control_3rd_person` — Third-person controller with orbit camera

Both addons extend `BasePlayerController3D` and use the shared state machine.

## Dual Perspective Controller

For games that need both first and third-person views with runtime switching, use `DualPerspectiveController3D`:

```gdscript
# Toggle between perspectives at runtime
player_controller.toggle_perspective()

# Or set directly
player_controller.set_perspective(DualPerspectiveController3D.Perspective.THIRD_PERSON)

# Check current mode
if player_controller.is_first_person():
    pass
```

**Features:**
- Shares the same state machine for both perspectives
- Smooth camera angle sync when switching
- Automatic character mesh show/hide (hidden in FPS)
- Three rotation modes for third-person: `FACE_MOVEMENT`, `STRAFE`, `FREE`

**Required components:**
- Both `PlayerLookController3D` (from FPS addon) and `OrbitCameraController3D` (from third-person addon)
- Input action `toggle_perspective` (optional)

## State Machine Architecture

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

## Extending

To create a custom controller:

```gdscript
class_name MyCustomController3D
extends BasePlayerController3D

## Override to provide camera-relative movement basis.
func _get_movement_basis() -> Basis:
    # Return the basis used for movement direction
    return my_camera.global_transform.basis

## Optional: Handle UI state transitions.
func _on_ui_state_entered() -> void:
    my_camera_controller.enabled = false

func _on_ui_state_exited() -> void:
    my_camera_controller.enabled = true
```

## Signals

### BasePlayerController3D

| Signal | Description |
|--------|-------------|
| `gameplay_enabled_changed(enabled: bool)` | Emitted when gameplay is enabled/disabled |
| `mouse_capture_requested(mode: Input.MouseMode)` | Request mouse capture state change |

### PlayerMotor3D

| Signal | Description |
|--------|-------------|
| `grounded_changed(is_grounded: bool)` | Emitted when grounded state changes |
| `jumped()` | Emitted when player jumps |

### PlayerStateMachine

| Signal | Description |
|--------|-------------|
| `state_changed(old_state, new_state)` | Emitted on state transitions |

### DualPerspectiveController3D

| Signal | Description |
|--------|-------------|
| `perspective_changed(is_first_person: bool)` | Emitted when perspective toggles |

## License

MIT

# Player Control Third Person Addon

A modular third-person player controller addon for Godot 4.x with orbit camera.

## Dependencies

**Requires:** `player_control_core` addon must be enabled before enabling this addon.

The core addon provides:
- `BasePlayerController3D` — Abstract controller base
- `PlayerMotor3D` — Movement physics
- `PlayerInputRouter3D` — Input handling
- `PlayerStateMachine` — State management
- `MovementSettings3D` — Movement configuration
- `InputActions3D` — Input action names

## Features

- **Camera-relative movement** — Move in the direction the camera is facing
- **Orbit camera** with configurable distance, height, and collision
- **Smooth camera follow** with configurable lag
- **Character rotation modes** — Face movement direction or strafe
- **State machine** — Grounded, Airborne, UI states (from core)
- **Signal-based architecture** — decoupled from other systems

## Installation

1. Copy `addons/player_control_core/` to your project's `addons/` directory.
2. Copy `addons/player_control_3rd_person/` to your project's `addons/` directory.
3. Enable **Player Control Core** in Project > Project Settings > Plugins.
4. Enable **Player Control Third Person** in Project > Project Settings > Plugins.

## Third-Person Rig Requirements

**Recommended node layout:**

```
Player (CharacterBody3D)
├── CollisionShape3D
├── MeshInstance3D (character model)
├── CameraTarget (Node3D)              ← what the camera orbits
├── ThirdPersonController3D            ← main entry point
├── PlayerInputRouter3D                ← from core addon
├── PlayerMotor3D                      ← from core addon
├── OrbitCameraController3D            ← from this addon
│   └── Camera3D                       ← child of orbit controller
└── PlayerStateMachine                 ← from core addon
    ├── grounded (GroundedState)
    ├── airborne (AirborneState)
    └── ui (UIState)
```

## Quick Start

1. Create a `CharacterBody3D` scene with the rig structure above.
2. Add addon nodes as children.
3. Configure exports in the Inspector:

```gdscript
# On ThirdPersonController3D:
@export var body: CharacterBody3D
@export var input_router: PlayerInputRouter3D
@export var motor: PlayerMotor3D
@export var state_machine: PlayerStateMachine
@export var camera_controller: OrbitCameraController3D

# On OrbitCameraController3D:
@export var target: Node3D           # The CameraTarget node
@export var camera: Camera3D         # The Camera3D child
@export var input_router: PlayerInputRouter3D
@export var camera_settings: OrbitCameraSettings3D
```

4. Create Resource files (`.tres`) for settings, or use defaults.

## Camera Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `default_distance` | 5.0 | Starting distance from target |
| `min_distance` | 1.5 | Closest zoom distance |
| `max_distance` | 10.0 | Furthest zoom distance |
| `height_offset` | 1.5 | How high above target to look |
| `orbit_sensitivity` | 0.003 | Mouse sensitivity for orbiting |
| `min_pitch` | -1.2 rad | Maximum look up angle |
| `max_pitch` | 1.4 rad | Maximum look down angle |
| `follow_smoothing` | 10.0 | Camera position smoothing |
| `collision_mask` | 1 | Physics layers for camera collision |
| `collision_margin` | 0.2 | Push camera away from walls |

## Character Rotation Modes

```gdscript
enum RotationMode {
    FACE_MOVEMENT,  # Body rotates to face movement direction
    STRAFE,         # Body faces camera direction
    FREE            # No automatic rotation
}
```

## Public API

### ThirdPersonController3D

**Methods:**
- `set_gameplay_enabled(enabled: bool)` — Enable/disable movement and camera input.

**Signals:**
- `gameplay_enabled_changed(enabled: bool)` — Emitted when gameplay state changes.
- `mouse_capture_requested(mode: Input.MouseMode)` — Request mouse mode change.

### OrbitCameraController3D

**Methods:**
- `set_distance(distance: float)` — Set camera distance.
- `reset_orbit()` — Reset yaw/pitch to defaults.

## Input Actions

Uses `InputActions3D` from core addon. Same as FPS:

| Action | Default Name |
|--------|--------------|
| Move Forward | `move_forward` |
| Move Back | `move_back` |
| Move Left | `move_left` |
| Move Right | `move_right` |
| Jump | `jump` |
| Sprint | `sprint` |
| Crouch | `crouch` |

## License

MIT

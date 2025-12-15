# Player Control FPS Addon

A modular first-person player movement and camera control addon for Godot 4.x.

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

- **Walk, sprint, crouch movement** with configurable speeds
- **Jump** with configurable velocity
- **Mouse look** with configurable sensitivity and pitch clamping
- **State machine** — Grounded, Airborne, UI states
- **UI gating** — disable movement/look when UI is open
- **Signal-based architecture** — decoupled from other systems

## Installation

1. Copy `addons/player_control_core/` to your project's `addons/` directory.
2. Copy `addons/player_control_fps/` to your project's `addons/` directory.
3. Enable **Player Control Core** in Project > Project Settings > Plugins.
4. Enable **Player Control FPS** in Project > Project Settings > Plugins.

## FPS Rig Requirements

The addon expects a standard FPS rig structure. Nodes are supplied via `@export`, not hardcoded paths.

**Recommended node layout:**

```
Player (CharacterBody3D)
├── CollisionShape3D
├── PitchPivot (Node3D)         ← pitch rotation applied here
│   └── Camera3D
├── FPSPlayerController3D       ← main entry point (from FPS addon)
├── PlayerInputRouter3D         ← from core addon
├── PlayerMotor3D               ← from core addon
├── PlayerLookController3D      ← from FPS addon
└── PlayerStateMachine          ← from core addon
    ├── grounded (GroundedState)
    ├── airborne (AirborneState)
    └── ui (UIState)
```

- **Yaw** is applied to the `CharacterBody3D` (or a dedicated `YawPivot` node).
- **Pitch** is applied to `PitchPivot`.

## Quick Start

1. Create a `CharacterBody3D` scene with the rig structure above.
2. Add the addon nodes as children.
3. Configure exports in the Inspector:

```gdscript
# On FPSPlayerController3D, wire up:
@export_group("Rig References")
@export var body: CharacterBody3D         # The player body
@export var pitch_pivot: Node3D           # Node for pitch rotation

@export_group("Core Components")
@export var input_router: PlayerInputRouter3D
@export var motor: PlayerMotor3D
@export var state_machine: PlayerStateMachine

@export_group("FPS Components")
@export var look_controller: PlayerLookController3D

@export_group("Settings")
@export var movement_settings: MovementSettings3D  # From core addon
@export var input_actions: InputActions3D          # From core addon
@export var look_settings: FPSLookSettings3D       # FPS-specific
```

4. Create Resource files (`.tres`) for settings, or use defaults.

## Input Actions

The addon uses configurable action names via `InputActions3D` resource. Default action names:

| Action | Default Name |
|--------|--------------|
| Move Forward | `move_forward` |
| Move Back | `move_back` |
| Move Left | `move_left` |
| Move Right | `move_right` |
| Jump | `jump` |
| Sprint | `sprint` |
| Crouch | `crouch` |

**You must define these actions in Project > Project Settings > Input Map.**

## Public API

### FPSPlayerController3D

**Methods:**
- `set_gameplay_enabled(enabled: bool)` — Enable/disable movement and look input.

**Signals:**
- `gameplay_enabled_changed(enabled: bool)` — Emitted when gameplay state changes.
- `mouse_capture_requested(mode: Input.MouseMode)` — Request mouse mode change.

### PlayerMotor3D (from core)

**Signals:**
- `grounded_changed(is_grounded: bool)` — Emitted when grounded state toggles.
- `jumped()` — Emitted when player jumps.

### PlayerStateMachine (from core)

**Signals:**
- `state_changed(old_state, new_state)` — Emitted on state transitions.

## Migration from v1.0

If you're upgrading from the pre-refactor version:

1. Enable `player_control_core` addon first.
2. Replace `PlayerController3D` with `FPSPlayerController3D` in your scenes.
3. Replace `FPSMovementSettings3D` with `MovementSettings3D` (from core).
4. Replace `FPSInputActions` with `InputActions3D` (from core).
5. Add `PlayerStateMachine` with child states (`grounded`, `airborne`, `ui`).
6. Wire the state machine to the controller.

The API for `set_gameplay_enabled()` remains the same.

## License

MIT

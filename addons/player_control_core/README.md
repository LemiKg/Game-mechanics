# Player Control Core

Core player control framework providing shared abstractions for FPS and third-person player controllers.

## Features

- **State Machine** — Formal player states (Grounded, Airborne, UI) with clean transitions
- **Jump Feel** — Coyote time and jump buffering for responsive controls (100ms default)
- **Animation System** — Signal-based animation requests for easy 3D model integration
- **Pushdown Stack** — State stack for temporary interrupts (attacks, stagger, cutscenes)
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
| `PlayerStateMachine` | Manages state transitions, pushdown stack for interrupts |
| `PlayerState` | Abstract base for all states; emits animation signals |
| `GroundedState` | Active when on floor; handles sprint/crouch modifiers |
| `AirborneState` | Active when airborne; coyote time + jump buffering |
| `UIState` | Active when gameplay disabled; blocks input |

### Core Components

| Class | Purpose |
|-------|---------|
| `BasePlayerController3D` | Abstract orchestrator; extend for FPS or third-person |
| `DualPerspectiveController3D` | Unified controller supporting both FPS and third-person with runtime toggle |
| `PlayerMotor3D` | Applies velocity to CharacterBody3D based on input intent |
| `PlayerInputRouter3D` | Converts input actions to movement/look intent vectors |
| `AnimationController` | Bridges state signals to AnimationTree or AnimationPlayer |

### Resources

| Class | Purpose |
|-------|---------|
| `MovementSettings3D` | Walk/sprint/crouch speed, acceleration, jump, gravity, jump feel |
| `InputActions3D` | Configurable input action names |

## Usage

This addon is not used directly. Enable one of:
- `player_control_fps` — First-person controller
- `player_control_3rd_person` — Third-person controller with orbit camera

Both addons extend `BasePlayerController3D` and use the shared state machine.

---

## Jump Feel Settings

The `MovementSettings3D` resource includes settings for responsive jump controls:

| Setting | Default | Description |
|---------|---------|-------------|
| `coyote_time` | 0.1s | Grace period after leaving a platform where jump still works |
| `jump_buffer_time` | 0.1s | How long a jump input is remembered before landing |

**Coyote Time**: Allows the player to jump for a short window after walking off a ledge. Prevents the frustrating "I pressed jump!" feeling.

**Jump Buffering**: If the player presses jump slightly before landing, the jump executes immediately upon landing. Makes chained jumps feel responsive.

```gdscript
# In your MovementSettings3D resource:
coyote_time = 0.1      # 100ms = 6 frames at 60fps (Celeste-style)
jump_buffer_time = 0.1  # 100ms
```

---

## Adding 3D Models with Animations

The animation system uses signals to decouple state logic from animation playback.

### Step 1: Add Your 3D Model

Add your character model (`.glb`, `.gltf`, or `.tscn`) as a child of your player scene.

### Step 2: Set Up AnimationTree (Recommended)

1. Add an `AnimationTree` node
2. Set its `tree_root` to an `AnimationNodeStateMachine`
3. Create states matching the animation names:
   - `idle`, `walk`, `run`
   - `jump`, `fall`, `land`
   - `crouch_idle`, `crouch_walk` (if crouching enabled)
4. Connect states with transitions

### Step 3: Add AnimationController

1. Add an `AnimationController` node as a child of your player
2. Configure the exports:
   - `state_machine` → Your `PlayerStateMachine`
   - `animation_tree` → Your `AnimationTree`
3. The controller automatically connects to all state `animation_requested` signals

### Animation Names Expected

| Animation | Emitted By | When |
|-----------|------------|------|
| `idle` | GroundedState | Standing still |
| `walk` | GroundedState | Moving at walk speed |
| `run` | GroundedState | Sprinting |
| `crouch_idle` | GroundedState | Crouching, not moving |
| `crouch_walk` | GroundedState | Crouching and moving |
| `jump` | GroundedState/AirborneState | Jump initiated or ascending |
| `fall` | AirborneState | Descending |
| `land` | AirborneState | Just landed |

### Custom Animation Handling

If you need custom logic, connect to signals directly:

```gdscript
func _ready() -> void:
    for state in state_machine.states.values():
        state.animation_requested.connect(_on_animation_requested)

func _on_animation_requested(anim_name: StringName, blend_time: float) -> void:
    # Custom animation logic here
    animation_tree["parameters/playback"].travel(anim_name)
```

---

## Pushdown State Stack

For temporary state interrupts that should return to the previous state (attacks, stagger, dialogue), use the pushdown stack:

```gdscript
# Push current state and enter "attack" state
state_machine.push_state(&"attack")

# When attack finishes, return to previous state
state_machine.pop_state()

# Force clear the stack (e.g., on death)
state_machine.clear_state_stack()
```

**Use Cases:**
- Attack animations that return to idle/moving
- Stagger/hurt states that return to gameplay
- Cutscene interrupts
- Dialogue that pauses movement

---

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

### PlayerState

| Signal | Description |
|--------|-------------|
| `animation_requested(name, blend_time)` | Request an animation to play |

### AnimationController

| Signal | Description |
|--------|-------------|
| `animation_started(animation_name)` | Emitted when animation begins playing |

### DualPerspectiveController3D

| Signal | Description |
|--------|-------------|
| `perspective_changed(is_first_person: bool)` | Emitted when perspective toggles |

## License

MIT

# Player Control Core

Core player control framework providing shared abstractions for FPS and third-person player controllers.

## Features

### Movement System
- **Player Motor** — Physics-based movement with configurable speed, acceleration, and gravity
- **Dual Body Support** — Works with both `CharacterBody3D` and `RigidBody3D` via duck typing
- **Actual Velocity Tracking** — Real displacement-based velocity for accurate animation blending
- **Camera-Relative Movement** — Movement direction based on camera orientation

### State Machine
- **Formal States** — Grounded, Airborne, UI, and Mantle states with clean transitions
- **Jump Feel** — Coyote time and jump buffering for responsive controls (100ms default)
- **Pushdown Stack** — State stack for temporary interrupts (attacks, stagger, cutscenes)
- **Rotate-in-Place** — Optional idle rotation when input direction differs from facing

### Mantling System
- **Ledge Detection** — Multi-raycast system for detecting climbable surfaces
- **Programmatic Movement** — Smooth curve-based interpolation to ledge position
- **Configurable Heights** — Min/max reach, surface depth, and detection distances

### Animation & Input
- **Animation System** — Signal-based animation requests for easy 3D model integration
- **Input Router** — Converts raw input to movement intent, decoupled from motor

### Controllers
- **Base Controller** — Abstract orchestrator for camera-specific implementations
- **Dual Perspective Controller** — Unified FPS/third-person with runtime toggle
- **Rotation Modes** — Face Movement, Strafe, Free, Aiming, and Lock-On modes
- **Body Tilt** — Optional lateral tilt when strafing for visual polish

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
| `GroundedState` | Active when on floor; handles sprint/crouch, rotate-in-place |
| `AirborneState` | Active when airborne; coyote time, jump buffering, mantle detection |
| `UIState` | Active when gameplay disabled; blocks input |
| `MantleState` | Active during mantling; programmatic ledge climb |

### Core Components

| Class | Purpose |
|-------|---------|
| `BasePlayerController3D` | Abstract orchestrator; extend for FPS or third-person |
| `DualPerspectiveController3D` | Unified controller supporting FPS/third-person with runtime toggle |
| `PlayerMotor3D` | Applies velocity to CharacterBody3D or RigidBody3D based on input |
| `PlayerInputRouter3D` | Converts input actions to movement/look intent vectors |
| `AnimationController` | Bridges state signals to AnimationTree or AnimationPlayer |
| `MantleDetector` | Multi-raycast ledge detection for mantling system |

### Resources

| Class | Purpose |
|-------|---------|
| `MovementSettings3D` | Walk/sprint/crouch speed, acceleration, jump, gravity, RigidBody settings |
| `InputActions3D` | Configurable input action names |
| `MantleSettings3D` | Ledge detection distances, movement curve, animation names |

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
- Five rotation modes: `FACE_MOVEMENT`, `STRAFE`, `FREE`, `AIMING`, `LOCK_ON`
- Body tilt when strafing for visual polish
- Lock-on targeting with auto-break distance

**Required components:**
- Both `PlayerLookController3D` (from FPS addon) and `OrbitCameraController3D` (from third-person addon)
- Input action `toggle_perspective` (optional)

---

## RigidBody3D Support

The `PlayerMotor3D` supports both `CharacterBody3D` and `RigidBody3D` using duck typing:

```gdscript
# Assign any physics body - motor auto-detects type
@export var body: Node3D  # CharacterBody3D or RigidBody3D

# Motor uses appropriate physics:
# - CharacterBody3D: move_and_slide()
# - RigidBody3D: apply_central_force()
```

**RigidBody Settings** in `MovementSettings3D`:
| Setting | Default | Description |
|---------|---------|-------------|
| `rigid_body_force_multiplier` | 50.0 | Force multiplier for movement |
| `rigid_body_ground_raycast_distance` | 0.2 | Ground detection ray length |

---

## Mantling System

Automatic ledge climbing when jumping near climbable surfaces:

```gdscript
# Add MantleDetector as child of player
# Configure in MantleSettings3D resource:
@export var min_height: float = 0.5      # Minimum ledge height
@export var max_height: float = 2.0      # Maximum reach
@export var max_distance: float = 0.8    # Forward detection range
@export var surface_depth: float = 0.3   # Required surface depth
```

**Components:**
| Class | Purpose |
|-------|---------|
| `MantleDetector` | Casts rays to find valid ledges |
| `MantleState` | Handles the climb animation/movement |
| `MantleSettings3D` | Configuration resource |

**Detection Flow:**
1. AirborneState checks for ledges when ascending and near surfaces
2. MantleDetector casts horizontal ray to find wall
3. Casts downward ray to find ledge surface
4. Validates height and surface depth
5. Transitions to MantleState for climb

---

## Rotation Modes

Third-person and dual-perspective controllers support multiple rotation modes:

| Mode | Description |
|------|-------------|
| `FACE_MOVEMENT` | Character faces movement direction |
| `STRAFE` | Character faces camera direction, can strafe |
| `FREE` | No automatic rotation |
| `AIMING` | Like strafe but with zoom FOV and faster rotation |
| `LOCK_ON` | Character faces a target node |

```gdscript
# Set rotation mode
controller.rotation_mode = ThirdPersonController3D.RotationMode.AIMING

# Lock-on to a target
controller.set_lock_on_target(enemy_node)

# Clear lock-on
controller.clear_lock_on()
```

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
| `velocity_changed(velocity: Vector3, speed: float)` | Emitted when actual velocity changes (for pose warping) |

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
| `lock_on_started(target: Node3D)` | Emitted when lock-on begins |
| `lock_on_ended()` | Emitted when lock-on ends |

### MantleDetector

| Signal | Description |
|--------|-------------|
| `ledge_detected(ledge_info: Dictionary)` | Emitted when a valid ledge is found |

## License

MIT

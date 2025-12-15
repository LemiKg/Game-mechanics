# Player Control Addon (FPS / 3D) — Implementation Plan

## 0) Context and Constraints (Project Rules)
This repository uses a **modular addon architecture**:
- Each mechanic is a self-contained addon under `addons/<addon_name>/`.
- **Data layer:** `Resource` types in `core/` (pure data + validation).
- **Logic layer:** `Node` components/controllers/handlers in `core/`.
- **UI layer:** `ui/` contains `Control` scripts + scenes (display only).
- **Dependency injection:** use `@export` for external dependencies; guard nulls; avoid tree traversal (`get_node()` hard paths, `find_parent()`, groups).
- **Decoupled communication:** use signals with sufficient context.

This plan focuses on **3D first-person (FPS)** only.

## 1) Goals (MVP)
### Must-have
- Character movement using `CharacterBody3D`:
  - Walk movement (WASD).
  - Jump.
  - Gravity application.
- Mouse look:
  - Yaw rotates the player body.
  - Pitch rotates a camera pivot.
  - Pitch clamped to prevent flipping.
- UI gating / mouse capture:
  - When gameplay is enabled: capture mouse.
  - When UI is open: show mouse and disable look/movement.
- Clean modular architecture consistent with existing addons.
- Minimal, well-documented public API.

### Non-goals (deferred)
- Sprint
- Crouch
- Head bob
- Lean
- Advanced slope / step climbing tuning
- Network prediction
- Complex “parkour” movement

## 2) Why not a state machine (yet)?
This repo does not currently include a formal FSM pattern. For the MVP, a full state machine tends to add complexity without much benefit because the required modes are simple:
- `GAMEPLAY` (movement + look enabled)
- `UI` (movement + look disabled)

Instead of a full FSM, the MVP uses an **FSM-lite mode flag** managed by a single controller node with:
- A setter method (single source of truth)
- Signals to broadcast changes

If/when we add sprint/crouch and more transitions (stamina, mantling, ladder, swimming), we can evolve the mode handling into a state machine **without breaking the external API**.

## 3) Addon Name and Structure
Proposed addon folder:

```
addons/
  player_control_fps/
    plugin.cfg
    player_control_fps_plugin.gd
    README.md
    core/
      player_controller_3d.gd
      player_input_router_3d.gd
      player_motor_3d.gd
      player_look_controller_3d.gd
      player_interaction_component_3d.gd   (optional MVP)
      fps_movement_settings_3d.gd          (Resource)
      fps_look_settings_3d.gd              (Resource)
      fps_input_actions.gd                 (Resource)
    ui/
      (empty for MVP, or optional debug overlay later)
```

Notes:
- The addon can be UI-free initially.
- All external node references are injected via `@export`.

## 4) FPS Rig Contract (Scene Expectations)
The addon should work with a standard FPS rig. Recommended node layout:

- `Player` (`CharacterBody3D`)
  - `YawPivot` (`Node3D`) — optional if you want to rotate body directly
    - `PitchPivot` (`Node3D`) — pitch rotates here
      - `Camera3D`

In the simplest setup:
- **Yaw** is applied to the `CharacterBody3D` (or `YawPivot`).
- **Pitch** is applied to `PitchPivot`.

The addon should not assume specific node paths; these nodes are supplied via `@export`.

## 5) Public API (Minimal)
Primary entry point: `PlayerController3D` (logic layer node).

### Methods
- `set_gameplay_enabled(enabled: bool) -> void`
  - Enables/disables movement and look.
  - Emits `gameplay_enabled_changed`.
  - Requests mouse mode change (via signal or direct call, see below).

- `set_mouse_captured(captured: bool) -> void` (optional)
  - Either:
    - Controller sets `Input.set_mouse_mode(...)` directly, OR
    - Controller emits `mouse_capture_requested(mode)` and the game/root scene applies it.

**Recommendation:** emit a signal and let the game/root scene decide, to keep the addon decoupled from UI policies.

### Exported dependencies (examples)
Use `@export_group()` for organized Inspector sections (consistent with inventory addon):

```gdscript
@export_group("Rig References")
@export var body: CharacterBody3D
@export var pitch_pivot: Node3D
@export var camera: Camera3D

@export_group("Components")
@export var input_router: PlayerInputRouter3D
@export var motor: PlayerMotor3D
@export var look_controller: PlayerLookController3D

@export_group("Settings")
@export var movement_settings: FPSMovementSettings3D
@export var look_settings: FPSLookSettings3D
@export var input_actions: FPSInputActions
```

Each exported dependency must be null-guarded with `push_warning()`.

## 6) Signals (Integration Contract)
### Controller-level signals
- `signal gameplay_enabled_changed(enabled: bool)`
- `signal mouse_capture_requested(mode: Input.MouseMode)`
  - Type-safe enum: `Input.MOUSE_MODE_CAPTURED`, `Input.MOUSE_MODE_VISIBLE`, etc.
  - Using the enum type instead of raw `int` improves type safety and editor autocompletion.

### Movement/state signals (MVP)
- `signal grounded_changed(is_grounded: bool)`
- `signal jumped()`

### Interaction signals (optional MVP)
If we include `PlayerInteractionComponent3D`:
- `signal interaction_target_changed(target: Node, hit_position: Vector3, hit_normal: Vector3)`
- `signal interact_requested(target: Node, hit_position: Vector3, hit_normal: Vector3)`

**Contract:** The interaction component must:
1. **Emit signals only** — never call methods on inventory or other addons directly.
2. **Include full context** — target node, world position, and normal so handlers can act without tree queries.
3. **Support duck typing** — listeners check `target.has_method("interact")` rather than type-checking.

Guideline: payloads should be sufficient so listeners do not need to query the scene tree.

## 7) Core Components (Responsibilities)
### 7.1 `FPSInputActions` (Resource)
Purpose: Make action names configurable per project.

**Design note:** This is a pure data Resource with no methods—kept as Resource (rather than `RefCounted` or const dictionary) for Inspector editability and serialization. This follows the data layer pattern where Resources hold configuration that designers can tweak.

Fields (StringName):
- `move_forward`, `move_back`, `move_left`, `move_right`
- `jump`
- `toggle_inventory` (or leave to game-level wiring)
- `interact` (optional)

### 7.2 `FPSMovementSettings3D` (Resource)
Purpose: Tuning values for movement.

Fields (suggested):
- `walk_speed: float`
- `acceleration: float`
- `deceleration: float`
- `jump_velocity: float`
- `gravity: float` (or `gravity_scale`)
- `air_control: float` (optional)

### 7.3 `FPSLookSettings3D` (Resource)
Purpose: Tuning values for mouse look.

Fields (suggested):
- `mouse_sensitivity: float`
- `invert_y: bool`
- `min_pitch_degrees: float` (e.g. -89)
- `max_pitch_degrees: float` (e.g. +89)

### 7.4 `PlayerInputRouter3D` (Node)
Purpose: Convert input into normalized *intent*.

Responsibilities:
- Movement intent (2D vector) from actions.
  - Prefer `Input.get_vector(...)` when possible.
- Jump intent (pressed this frame).
- Look intent from `InputEventMouseMotion`.

Best practice:
- Mouse motion should be handled in `_unhandled_input(event)` so UI can consume events first.

Outputs:
- Stored properties (read by motor/look controller) OR emitted signals (e.g., `look_delta_changed`).

### 7.5 `PlayerMotor3D` (Node)
Purpose: Apply movement physics to a `CharacterBody3D`.

Responsibilities:
- Runs in `_physics_process(delta)`.
- Applies gravity when not grounded.
- Applies jump velocity when requested and grounded.
- Computes horizontal velocity from movement intent, with accel/decel.
- Calls `body.move_and_slide()`.
- Tracks grounded state and emits `grounded_changed` when it toggles.

Best practice:
- Keep all physics updates inside `_physics_process`.

### 7.6 `PlayerLookController3D` (Node)
Purpose: Apply yaw/pitch from look intent to the rig.

Responsibilities:
- Maintain yaw/pitch accumulators (avoid reading/modifying transforms as the source of truth).
- Apply yaw to the body or yaw pivot.
- Apply pitch to pitch pivot.
- Clamp pitch between settings.

Best practice:
- Use `InputEventMouseMotion.screen_relative` (or `relative`) in captured mouse mode.

### 7.7 `PlayerController3D` (Node)
Purpose: Orchestration and one public surface.

Responsibilities:
- Holds references to subcomponents + settings.
- Owns `gameplay_enabled`.
- Wires the update loop or delegates to components.
- Emits `mouse_capture_requested` based on `gameplay_enabled`.

**SRP Note:** This scope is acceptable for MVP. If responsibilities grow (e.g., pause handling, multiple input contexts, accessibility features), consider extracting mouse capture logic into a separate `MouseCaptureController` to maintain single responsibility.

This node is what game scenes should add and wire.

## 8) UI Gating and Inventory Integration
Inventory UI already toggles visibility and mouse mode in the test scripts.

Target integration pattern (no hard dependency):
- Inventory UI (or game/root scene) decides when UI is open.
- When UI opens:
  - call `player_controller.set_gameplay_enabled(false)`
  - set mouse visible (or react to `mouse_capture_requested`)
- When UI closes:
  - call `player_controller.set_gameplay_enabled(true)`
  - recapture mouse

This preserves addon decoupling and avoids cross-addon path coupling.

## 9) Implementation Sprints (Iterative)
### Sprint 0 — Scaffold and Contracts
Deliverables:
- Addon folder skeleton.
- Plugin registration for types.
- README documenting rig requirements and configuration.
- Define empty class shells with `class_name` and exported deps.

Acceptance criteria:
- Addon enables in Project Settings without errors.
- Custom types appear in the editor.

### Sprint 1 — Look Controller (FPS camera)
Deliverables:
- `FPSLookSettings3D` Resource.
- `PlayerLookController3D` Node:
  - yaw/pitch accumulators
  - pitch clamp
  - consumes mouse motion from input router

Acceptance criteria:
- With mouse captured, moving the mouse rotates yaw and pitch correctly.
- Pitch cannot flip over.

### Sprint 2 — Movement Motor (walk + jump)
Deliverables:
- `FPSMovementSettings3D` Resource.
- `PlayerMotor3D` Node:
  - gravity
  - walk
  - jump
  - `move_and_slide()` in `_physics_process`

Acceptance criteria:
- Player walks and jumps consistently.
- Grounded state changes are correct.

### Sprint 3 — Input Router + Controller Orchestration
Deliverables:
- `FPSInputActions` Resource.
- `PlayerInputRouter3D`:
  - movement vector
  - jump pressed
  - look delta from `_unhandled_input`
- `PlayerController3D`:
  - `set_gameplay_enabled`
  - emits `mouse_capture_requested`

Acceptance criteria:
- Movement and look run through the controller, not directly from scene scripts.
- Turning gameplay off stops movement and look.

### Sprint 4 — UI Gating Example + Documentation
Deliverables:
- Example scene/script in `scenes/` (or a new `scenes/fps_test_scene.tscn`) demonstrating:
  - toggling inventory UI
  - calling `set_gameplay_enabled`
  - reacting to `mouse_capture_requested`

Acceptance criteria:
- Inventory open/close reliably changes mouse mode and disables gameplay control.

### Sprint 5 (Later) — Sprint and Crouch
Deliverables:
- Extend settings + motor to support sprint and crouch.
- Decide whether to upgrade FSM-lite to a small state machine.

Acceptance criteria:
- Sprint/crouch work without breaking existing API.

## 10) Testing and Validation Strategy
- Manual test scene(s):
  - Verify FPS look correctness.
  - Verify movement/jump and grounded transitions.
  - Verify UI gating toggles.
- Add debug logging only if needed; prefer signals and inspector-visible state.

## 11) Open Decisions (Choose Early)
- Mouse capture policy:
  - Controller sets mouse mode directly, OR controller emits request signal.
- Interaction component:
  - Include in MVP or defer.
- Camera ownership:
  - Controller owns camera node references only (recommended), not camera creation.

# Movement System Overhaul - Design Spec

## Summary

Overhaul the player control system to support Action RPG + Exploration gameplay in a truly dual-perspective (FPS + third-person) game. Adds orthogonal state composition, weighty movement physics with game-feel polish, crouch collision, ragdoll, dodge/roll, stamina, camera improvements, and AI-reusable movement API.

**Design philosophy:** Weighty, committed movement (Elden Ring meets Valheim). Sprint takes a moment to reach full speed, dodging is a committed action that consumes stamina, turning at sprint is sluggish, but mantling and exploration feel smooth.

## 1. Orthogonal State Composition

### Current Problem
`GroundedState` handles gait (walk/sprint) and stance (stand/crouch) inline with booleans. This doesn't scale when adding roll, slide, stamina interactions.

### New Design — Three Parallel Tracks

```
Movement State (state machine, exclusive):
  grounded → airborne → mantle → ragdoll → dodge

Gait (enum on motor, set by input or AI):
  WALK → RUN → SPRINT
  Each has own speed/accel/decel/rotation from GaitData resource

Stance (enum on motor, set by input or AI):
  STANDING → CROUCHING
  Affects collision height, speed multiplier, animations
```

`PlayerMotor3D` owns `gait` and `stance` as enums. The state machine handles movement states. They're independent — you can be `grounded + sprinting + crouching` or `airborne + walking + standing`.

### GaitData Resource

New file: `core/gait_data.gd`

```
class_name GaitData extends Resource

speed: float           # target movement speed
acceleration: float    # how fast to reach target speed
deceleration: float    # how fast to stop
rotation_rate: float   # how fast body turns to face movement (deg/s)
```

### MovementSettings3D Gait Dictionary

Replace flat `walk_speed`/`sprint_speed` fields with:

```
gait_data: Dictionary = {
  WALK: GaitData(speed=2.5, accel=20, decel=25, rot=8),
  RUN: GaitData(speed=5.0, accel=25, decel=30, rot=10),
  SPRINT: GaitData(speed=8.0, accel=15, decel=35, rot=6),
}
stance_speed_multiplier: Dictionary = {
  STANDING: 1.0,
  CROUCHING: 0.5,
}
```

Sprint has lower acceleration (weighty feel) and lower rotation rate (committed movement — can't turn sharply at full sprint).

## 2. Movement Physics & Game Feel

### Variable Jump Height
- On jump press: apply full `jump_velocity` upward
- On jump release (while ascending): multiply `velocity.y` by `jump_cut_multiplier` (0.5)
- Tap = short hop, hold = full height
- Tracked via `_jump_held: bool` in AirborneState

### Enhanced Fall Gravity
- Descending (`velocity.y < 0`): gravity * `fall_gravity_multiplier` (1.8)
- Ascending + jump released: gravity * `jump_cut_gravity_multiplier` (2.5)
- Ascending + jump held: normal gravity
- Result: snappy landings, floaty peak only when holding jump

### New MovementSettings3D Fields
```
jump_cut_multiplier: float = 0.5
fall_gravity_multiplier: float = 1.8
jump_cut_gravity_multiplier: float = 2.5
```

### Slope Handling
- Read `body.get_floor_normal()` when grounded
- Slope angle: `acos(floor_normal.dot(Vector3.UP))`
- Uphill: speed * `(1.0 - slope_factor * slope_speed_reduction)` (0.3)
- Downhill: speed * `(1.0 + slope_factor * downhill_speed_boost)` (0.15)
- Above `max_walkable_slope` (45 deg): slide

### New MovementSettings3D Fields
```
slope_speed_reduction: float = 0.3
downhill_speed_boost: float = 0.15
max_walkable_slope: float = 45.0
```

### Acceleration Model
Replace `move_toward()` with lerp-based acceleration using per-gait values from GaitData. Smoother transitions, weightier feel.

## 3. Crouch & Physical Interactions

### Crouch Collision Resize
- On crouch: lerp capsule height from `stand_height` (1.8) to `crouch_height` (1.0) over ~0.15s
- On stand: raycast upward for clearance (head-bonk detection)
- If ceiling: stay crouched, set `_wants_to_stand = true`, recheck each frame
- Capsule center offset: move down as height shrinks so feet stay planted

### New MovementSettings3D Fields
```
crouch_transition_speed: float = 10.0
crouch_clearance_margin: float = 0.1
```

### Ragdoll
- New `RagdollState` in state machine
- Enter: `skeleton.physical_bones_start_simulation()`, disable motor, disable collision
- Exit: stop simulation, re-enable motor, snap body to skeleton root position
- Recovery: after configurable `ragdoll_duration`, play get-up animation, transition to grounded
- Triggered externally via `state_machine.transition_to(&"ragdoll")`

### Dodge/Roll (Committed Action)
- New `DodgeState` in state machine
- Input: dodge action
- Enter: consume stamina (`dodge_stamina_cost`), apply velocity in input direction, play roll animation
- During: motor disabled, body moves at `dodge_speed` in locked direction for `dodge_duration` (~0.6s)
- Invincibility frames: optional `dodge_iframes_start` / `dodge_iframes_end` (normalized 0-1)
- Exit: transition to grounded or airborne
- Cannot dodge if stamina < cost

### New MovementSettings3D Fields
```
dodge_speed: float = 8.0
dodge_duration: float = 0.6
dodge_stamina_cost: float = 25.0
dodge_iframes_start: float = 0.1
dodge_iframes_end: float = 0.5
ragdoll_recovery_time: float = 2.0
```

### Stamina System
New `StaminaComponent` (Node) — separate from motor:
```
max_stamina: float = 100.0
current_stamina: float = 100.0
stamina_regen_rate: float = 15.0
stamina_regen_delay: float = 1.0
sprint_stamina_drain: float = 10.0
```
- Sprint drains per second
- Dodge costs flat amount
- No regen for `regen_delay` seconds after last drain
- When depleted during sprint: force gait to RUN
- Signals: `stamina_changed(current, max)`, `stamina_depleted()`

## 4. Camera Overhaul

### SpringArm3D for Third-Person
- Replace manual raycast collision in `OrbitCameraController3D` with `SpringArm3D`
- Camera becomes child of SpringArm
- Keep existing orbit math (yaw/pitch), just change collision handling

### Shoulder Switching
- Three positions: right (+0.5), left (-0.5), center (0.0)
- Cycled via input action
- Smooth lerp between positions

### New OrbitCameraSettings3D Fields
```
shoulder_offset: float = 0.5
shoulder_switch_speed: float = 8.0
```

### Speed-Based FOV
- FOV lerps between `base_fov` (75) and `sprint_fov` (85) based on speed ratio
- Applied in both FPS and third-person for consistency

### New Fields (both camera settings)
```
base_fov: float = 75.0
sprint_fov: float = 85.0
fov_transition_speed: float = 5.0
```

## 5. Animation & Polish

### Stop Prediction
- When grounded, decelerating, no input: `time_to_stop = speed / deceleration`
- If < 0.3s, request stop animation
- Track `_was_moving` in GroundedState to detect moving → stopping transition
- Fallback to idle if no stop animation

### Input Separation for AI
Add public methods on `PlayerMotor3D` that don't require input router:
- `move_in_direction(direction: Vector3, gait: Gait)`
- `request_jump()`
- `set_gait(gait: Gait)`
- `set_stance(stance: Stance)`
- AI scripts call these directly, player input router calls them internally

## 6. File Changes

### New Files
| File | Type | Purpose |
|------|------|---------|
| `core/gait_data.gd` | Resource | Per-gait speed/accel/decel/rotation |
| `core/stamina_component.gd` | Node | Stamina drain/regen/signals |
| `core/state_machine/dodge_state.gd` | PlayerState | Roll/dodge committed action |
| `core/state_machine/ragdoll_state.gd` | PlayerState | Physical bone simulation |

### Modified Files
| File | Changes |
|------|---------|
| `core/player_motor_3d.gd` | Gait/stance enums, per-gait physics, slope handling, enhanced gravity, variable jump, AI API |
| `core/movement_settings_3d.gd` | GaitData dictionary, jump feel params, slope params, crouch params, dodge params, stamina params |
| `core/state_machine/grounded_state.gd` | Remove inline gait/stance, use motor enums, stop prediction, crouch collision resize |
| `core/state_machine/airborne_state.gd` | Variable jump height, enhanced fall gravity |
| `core/player_input_router_3d.gd` | Dodge input, gait cycling, shoulder switch input |
| `core/dual_perspective_controller_3d.gd` | Speed-based FOV for both perspectives |
| `player_control_3rd_person/core/orbit_camera_controller_3d.gd` | SpringArm3D, shoulder switching, speed FOV |
| `player_control_fps/core/player_look_controller_3d.gd` | Speed FOV |
| `scenes/player.tscn` | Add StaminaComponent, DodgeState, RagdollState nodes |

### Plugin Registration
Update `player_control_core` plugin to register: GaitData, StaminaComponent, DodgeState, RagdollState

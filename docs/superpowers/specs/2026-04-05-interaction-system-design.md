# Interaction System Design

## Goal

Add a general-purpose interaction system with two categories: player-initiated toggle actions (sit, torch, dance) and world object interactions (craft, talk, pickup, generic).

## Architecture

Two independent subsystems sharing the existing focus competition pattern from WorldItem.

### 1. Player Actions (Toggle States)

Player-initiated actions triggered by input, no world object required.

**Sit** (new state: `SitState`)
- Input: `sit` action (X key)
- On enter: disable motor, play `sit_enter` animation, then `sit_idle` loop
- Exit triggers: press `sit` again, or any movement input
- On exit: play `sit_exit` animation, re-enable motor, transition to grounded
- Player stays at current position (no snap)

**Dance** (new state: `DanceState`)
- Input: `dance` action (H key)
- On enter: disable motor, play `dance` animation (loops)
- Exit triggers: press `dance` again, or any movement input
- On exit: transition to grounded with idle animation
- Player stays at current position

**Torch** (handled in `GroundedState`)
- Input: `toggle_torch` action (G key)
- Not a separate state — just a flag that swaps the idle animation
- When torch is active: idle plays `torch` instead of `idle`
- Movement animations (walk/run/crouch) are unaffected
- Toggle off by pressing G again

### 2. World Interactions (Interactable Component)

Reusable Area3D node for world objects.

**Interactable** (new node: `Interactable`, extends Area3D)
- Configurable properties:
  - `prompt_text: String` — e.g., "Press E to Craft"
  - `animation_name: StringName` — animation to play on player (e.g., `&"craft"`)
  - `interaction_duration: float` — how long the interaction lasts (0 = instant)
  - `interact_action: StringName` — input action (default `&"interact"`)
  - `require_hold: bool` — whether to require holding the button
  - `hold_duration: float` — hold time if require_hold is true
- Reuses WorldItem's focus competition pattern (static closest-in-range tracking)
- Shows Label3D prompt when focused
- Emits `interacted(player: Node)` signal when interaction completes
- Emits `interaction_started(player: Node)` signal when interaction begins
- Emits `interaction_cancelled(player: Node)` signal if player moves away

**InteractionState** (new player state)
- Entered when player presses interact near a focused Interactable
- On enter: disable motor, face the interactable, play configured animation
- During: wait for interaction_duration (or animation to finish if duration is 0)
- On exit: re-enable motor, emit interacted signal, transition to grounded
- Can be cancelled by movement input

### Input Router Changes

Add to `PlayerInputRouter3D`:
- `sit_requested: bool` + `consume_sit()` — same buffering pattern as dodge
- `dance_requested: bool` + `consume_dance()` — same pattern
- `torch_toggled: bool` + `consume_torch_toggle()` — same pattern

Add to `InputActions3D` (if it exists) or add new cached action names:
- `_sit: StringName = &"sit"`
- `_dance: StringName = &"dance"`
- `_toggle_torch: StringName = &"toggle_torch"`

### State Machine Changes

Add new states as children of `PlayerStateMachine` in `scenes/player.tscn`:
- `sit` (SitState)
- `dance` (DanceState)
- `interaction` (InteractionState)

`GroundedState` handles:
- Consuming sit/dance inputs and transitioning to those states
- Torch toggle (flag + animation swap, no state transition)
- Interaction input when an Interactable is focused (transition to interaction state)

### Signal Flow

**World interaction:**
```
Player enters Interactable area → focus competition selects closest
→ Label3D prompt shown → player presses E
→ GroundedState transitions to InteractionState
→ InteractionState plays animation, waits duration
→ Interactable.interacted signal emitted
→ World object does its thing (open UI, give quest, etc.)
→ Transition back to grounded
```

**Player action (sit):**
```
Player presses X → GroundedState consumes sit input
→ Transitions to SitState → motor disabled, sit_enter plays
→ sit_idle loops → player presses X or moves
→ sit_exit plays → motor re-enabled → transition to grounded
```

### New Files

| File | Type | Purpose |
|------|------|---------|
| `addons/player_control_core/core/state_machine/sit_state.gd` | PlayerState | Sit toggle state |
| `addons/player_control_core/core/state_machine/dance_state.gd` | PlayerState | Dance toggle state |
| `addons/player_control_core/core/state_machine/interaction_state.gd` | PlayerState | World interaction state |
| `addons/player_control_core/core/interactable.gd` | Area3D | Reusable world interactable component |

### Modified Files

| File | Change |
|------|--------|
| `addons/player_control_core/core/player_input_router_3d.gd` | Add sit/dance/torch input buffering |
| `addons/player_control_core/core/state_machine/grounded_state.gd` | Handle sit/dance/torch/interact inputs |
| `scenes/player.tscn` | Add sit/dance/interaction state nodes |
| `assets/characters/quaternius/player.tscn` | Add animation transitions for sit/dance/interact states |

### Animation Transitions Needed

From AnimationTree state machine, add transitions:
- Any locomotion state → Sitting_Enter, Sitting_Enter → Sitting_Idle (auto), Sitting_Idle → Sitting_Exit, Sitting_Exit → Idle (auto)
- Any locomotion state → Dance, Dance → Idle
- Any locomotion state → Interact/Fixing_Kneeling/PickUp_Table, each → Idle
- Idle ↔ Idle_Torch (for torch toggle)

Most of these transitions already exist from the animation wiring done earlier.

### Not In Scope

- Crafting recipes, crafting UI, or crafting logic
- Dialogue system or dialogue UI
- NPC AI or NPC behavior
- Item-specific interaction effects
- Torch light (just animation — actual light source is a separate concern)

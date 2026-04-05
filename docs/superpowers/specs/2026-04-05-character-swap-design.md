# Character Swap System Design

## Goal

Support multiple selectable 3D character models (Quaternius, KayKit Adventurers) via an export variable on the Player node. Characters that lack certain animations gracefully skip those states rather than breaking.

## Approach

**CharacterConfig resource + per-character scenes.** Each character bundles its own mesh, AnimationTree, and animation map. The Player node loads the selected character at runtime and configures the AnimationController accordingly. States guard transitions behind animation support checks.

---

## 1. CharacterConfig Resource

A custom `Resource` with the following properties:

| Property | Type | Description |
|---|---|---|
| `character_name` | `String` | Display name ("Quaternius", "Knight", etc.) |
| `character_scene` | `PackedScene` | Path to character mesh + AnimationTree scene |
| `animation_map` | `Dictionary` | Maps logical names to actual animation names |
| `supported_animations` | `Array[String]` | Logical names this character supports |

Each character gets a `.tres` file:
- `assets/characters/quaternius/quaternius_config.tres`
- `assets/characters/kaykit-adventurers/knight_config.tres`
- (additional KayKit characters follow the same pattern)

`supported_animations` is derived from the keys present in `animation_map`. If a logical name isn't in the map, it's not supported.

---

## 2. Character Scene Structure

Each character has a standalone scene containing mesh, skeleton, and AnimationTree:

### Quaternius (extracted from current player.tscn)

```
quaternius_character.tscn
└── CharacterRoot (Node3D)
    ├── Rig (AnimationLibrary_Godot_Standard.glb)
    │   └── Skeleton3D
    │       ├── OrientationWarpingModifier
    │       ├── StrideWarpingModifier
    │       └── SlopeWarpingModifier
    └── AnimationTree (full state machine, all 36+ states)
```

### KayKit (new)

```
knight_character.tscn
└── CharacterRoot (Node3D)
    ├── Rig (Knight.glb mesh + merged animation library)
    │   └── Skeleton3D
    └── AnimationTree (state machine with supported transitions only)
```

Key points:
- The existing Quaternius mesh + AnimationTree is **extracted** from `player.tscn` into its own scene to make it swappable.
- KayKit characters use the character `.glb` (e.g., Knight.glb) as the visual mesh with all animation `.glb` files merged into one AnimationLibrary.
- Skeleton modifiers (pose warping) are optional per character. KayKit characters skip them initially since the bone structure differs.
- Each character scene is scaled to match ~1.8 unit player height so collision and camera stay consistent.

### Player node integration

`CharacterMesh` becomes a dynamic slot on the Player:
- On `_ready()`, the player reads the exported `CharacterConfig`, instances `character_scene`, and adds it as the `CharacterMesh` child.
- It sets the `animation_map` on the `AnimationController`.

---

## 3. AnimationController Changes

### Current behavior
Hardcoded `animation_map` dictionary. Finds AnimationTree at a fixed node path.

### New behavior

1. **`animation_map` becomes settable** — assigned from `CharacterConfig` at startup. Keeps a default map as fallback.

2. **New method: `is_animation_supported(logical_name: String) -> bool`** — checks if the logical name exists in the current map. States call this before requesting transitions.

3. **`request_animation()` safety check** — if the requested logical name isn't in the map, falls back to `"idle"` and prints a debug warning. Prevents crashes from unsupported animation requests.

4. **AnimationTree path becomes dynamic** — resolves the AnimationTree from the instanced `CharacterMesh` child rather than a hardcoded node path.

### State-side changes

Transition guards are added at the point where `GroundedState` (or other states) decide to transition. Example:

```gdscript
if animation_controller.is_animation_supported("dance"):
    transition_to("dance")
```

Individual states (DanceState, SitState, etc.) don't need changes — if they're entered, the animation is guaranteed to exist. The guard lives at the transition point.

---

## 4. KayKit Animation Merging

All 8 `Rig_Medium_*.glb` files are merged into a single AnimationLibrary per character scene. This matches the Quaternius pattern (one library with all animations) and keeps the AnimationTree setup consistent.

### KayKit Animation Map

```
"idle"         → "Idle_A"
"walk"         → "Walking_A"
"run"          → "Running_A"
"jump"         → "Jump_Start"
"jump_loop"    → "Jump_Idle"
"land"         → "Jump_Land"
"crouch_idle"  → "Crouching"
"crouch_walk"  → "Sneaking"
"dodge"        → "Dodge_Forward"
"sit_enter"    → "Sit_Chair_Down"
"sit_idle"     → "Sit_Chair_Idle"
"sit_exit"     → "Sit_Chair_StandUp"
"dance"        → "Cheering"
"interact"     → "Interact"
"pickup"       → "PickUp"
"hit_chest"    → "Hit_A"
"hit_head"     → "Hit_B"
"death"        → "Death_A"
"sword_idle"   → "Melee_2H_Idle"
"sword_attack" → "Melee_1H_Attack_Slice_Horizontal"
"punch_enter"  → "Melee_Unarmed_Idle"
"punch_jab"    → "Melee_Unarmed_Attack_Punch_A"
"punch_cross"  → "Melee_Unarmed_Attack_Kick"
"torch"        → "Holding_A"
"stop"         → "Idle_A"
```

### Not supported (excluded from KayKit map)

These logical names have no KayKit equivalent and will be skipped:
- `swim_idle`, `swim_fwd` (no swimming animations)
- `drive` (no driving animation)
- `walk_formal`, `talk`, `craft`, `push` (no matching animations)
- `pistol_idle`, `pistol_aim`, `pistol_shoot`, `pistol_reload` (no pistol animations)
- `spell_enter`, `spell_idle`, `spell_shoot`, `spell_exit` (no spell animations — `Ranged_Magic_*` exists but doesn't map cleanly to the 4-phase spell system)

---

## 5. Files Changed

### New files
- `addons/player_control_core/core/character_config.gd` — CharacterConfig resource class
- `assets/characters/quaternius/quaternius_character.tscn` — extracted Quaternius character scene
- `assets/characters/quaternius/quaternius_config.tres` — Quaternius config resource
- `assets/characters/kaykit-adventurers/knight_character.tscn` — Knight character scene
- `assets/characters/kaykit-adventurers/knight_config.tres` — Knight config resource
- (additional `.tscn` / `.tres` per KayKit character: Barbarian, Mage, Rogue, Rogue Hooded)

### Modified files
- `scenes/player.tscn` — remove inline CharacterMesh, add exported `character_config` variable
- `addons/player_control_core/core/animation_controller.gd` — settable animation_map, `is_animation_supported()`, dynamic AnimationTree path, fallback logic
- `addons/player_control_core/core/state_machine/grounded_state.gd` — add `is_animation_supported()` guards before sit/dance/torch transitions
- `addons/player_control_core/core/reusable_player.gd` — load character scene from config on `_ready()`

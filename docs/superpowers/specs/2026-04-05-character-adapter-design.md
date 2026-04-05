# Character Adapter System Design (v2)

> Supersedes `2026-04-05-character-swap-design.md`.

## Goal

Support multiple selectable 3D character models (Quaternius, KayKit Adventurers) via the editor, where each character is a self-contained scene exposing a uniform interface. The player never reaches into a character's internal structure.

## Problem with v1

The first implementation tried to swap characters from the outside — the player removed the old mesh, instanced a new one, and told dependent nodes about it. This broke because:
- 5+ sibling nodes held hardcoded NodePaths into `CharacterMesh/Rig/Skeleton3D`
- `await` in `_ready()` caused initialization ordering chaos
- Different models have different internal hierarchies
- No code rebinding stale references after swap

## Approach: CharacterAdapter

Each character scene's root node extends a `CharacterAdapter` base class that exposes a standard interface. The player and its subsystems query the adapter — never the character's internals.

**Character selection:** Editor-only. Change which scene is instanced as `CharacterMesh` in `player.tscn`. No runtime swapping.

---

## 1. CharacterAdapter Base Class

**File:** `addons/player_control_core/core/character_adapter.gd`

```
class_name CharacterAdapter
extends Node3D
```

### Interface

| Method | Returns | Purpose |
|---|---|---|
| `get_character_name()` | `String` | Display name |
| `get_skeleton()` | `Skeleton3D` | The character's skeleton |
| `get_animation_tree()` | `AnimationTree` | Configured and active AnimationTree |
| `get_animation_map()` | `Dictionary` | `{ &"idle": &"Idle", ... }` — logical to actual names |
| `is_animation_supported(name)` | `bool` | Checks if logical name is in the map |
| `get_pose_warping_modifiers()` | `Dictionary` | `{ "stride": Node, "orientation": Node, "slope": Node }` or `{}` |

### Base implementations

- `is_animation_supported()` — returns `get_animation_map().has(name)`
- `get_pose_warping_modifiers()` — returns `{}` (no warping by default)

### Subclasses must override

- `get_character_name()`
- `get_skeleton()`
- `get_animation_tree()`
- `get_animation_map()`

---

## 2. Player Integration

**File:** `scenes/reusable_player.gd` (modified)

### _bind_character()

The player script gets a new `_bind_character()` method called at the start of `_ready()`. It reads the adapter and distributes references to all dependent nodes:

```gdscript
@onready var character: CharacterAdapter = $CharacterMesh

func _ready() -> void:
    _bind_character()
    # ... rest of existing _ready()

func _bind_character() -> void:
    var skeleton := character.get_skeleton()
    var anim_tree := character.get_animation_tree()
    var anim_map := character.get_animation_map()
    var modifiers := character.get_pose_warping_modifiers()

    # AnimationController
    animation_controller.animation_map = anim_map
    animation_controller.animation_tree = anim_tree
    animation_controller.setup()

    # RagdollState
    ragdoll_state.skeleton = skeleton

    # PoseWarpingController
    pose_warping_controller.skeleton = skeleton
    if modifiers.is_empty():
        pose_warping_controller.set_process(false)
        pose_warping_controller.set_physics_process(false)
    else:
        pose_warping_controller.stride_modifier = modifiers.get("stride")
        pose_warping_controller.orientation_modifier = modifiers.get("orientation")
        pose_warping_controller.slope_modifier = modifiers.get("slope")

    # DualPerspectiveController
    dual_controller.character_mesh = character
```

### New @onready references needed

```gdscript
@onready var character: CharacterAdapter = $CharacterMesh
@onready var animation_controller: AnimationController = $AnimationController
@onready var pose_warping_controller = $PoseWarpingController
@onready var ragdoll_state = $PlayerStateMachine/ragdoll
```

### No await, no runtime swapping

`_bind_character()` is fully synchronous. The character scene is a static instance in the editor. The adapter's `_ready()` runs before the player's `_ready()` (child before parent), so the adapter is fully initialized when queried.

---

## 3. player.tscn Changes

### Remove hardcoded NodePaths

These exported NodePath assignments are **removed** from the scene file:
- `AnimationController.animation_tree = NodePath("../CharacterMesh/AnimationTree")` — assigned by `_bind_character()`
- `RagdollState.skeleton = NodePath("../../CharacterMesh/Rig/Skeleton3D")` — assigned by `_bind_character()`
- `PoseWarpingController.skeleton = NodePath(...)` — assigned by `_bind_character()`
- `PoseWarpingController.stride_modifier = NodePath(...)` — assigned by `_bind_character()`
- `PoseWarpingController.orientation_modifier = NodePath(...)` — assigned by `_bind_character()`
- `PoseWarpingController.slope_modifier = NodePath(...)` — assigned by `_bind_character()`

### Kept as-is

- `DualPerspectiveController.character_mesh = NodePath("../CharacterMesh")` — still works because the adapter IS the CharacterMesh node. However, `_bind_character()` also sets it explicitly for robustness.
- `CharacterMesh` instance line — stays, just needs the adapter script on the instanced scene's root.

---

## 4. AnimationController Changes

**File:** `addons/player_control_core/core/animation_controller.gd`

### Changes

1. **`animation_map` default becomes empty:** `@export var animation_map: Dictionary = {}` — assigned by `_bind_character()`.

2. **New `setup()` method:** Called by `_bind_character()` after `animation_tree` and `animation_map` are assigned. Runs `_setup_animation_tree()` to get the state machine playback reference.

3. **`_ready()` change:** Only calls `_validate_dependencies()` and `_connect_state_signals()`. Does NOT call `_setup_animation_tree()` (deferred to `setup()`).

4. **`_validate_dependencies()` update:** Suppress the animation_tree warning since it's assigned later by `_bind_character()`. Or remove validation entirely — the `setup()` call is the validation point.

5. **`is_animation_supported()` method:** `return animation_map.has(logical_name)`. Same as v1.

6. **Fallback in `play_animation()`:** If a logical name isn't in the map and the map is non-empty, fall back to idle. Same as v1.

### Removed from v1

- `apply_config()` — replaced by direct assignment + `setup()`
- `_find_animation_tree()` — not needed, adapter provides the tree directly

---

## 5. PlayerState Base Class Change

**File:** `addons/player_control_core/core/state_machine/player_state.gd`

Add a convenience method so all states can check animation support:

```gdscript
func is_animation_supported(logical_name: StringName) -> bool:
    if controller and controller.body:
        var anim_ctrl := controller.body.get_node_or_null("AnimationController")
        if anim_ctrl:
            return anim_ctrl.is_animation_supported(logical_name)
    return true
```

No caching. The node lookup is cheap and avoids stale references.

---

## 6. GroundedState Guards

**File:** `addons/player_control_core/core/state_machine/grounded_state.gd`

Add guards using the base class method:

- Sit: `if state_machine.has_state(&"sit") and is_animation_supported(&"sit_enter"):`
- Dance: `if state_machine.has_state(&"dance") and is_animation_supported(&"dance"):`
- Torch: `if is_animation_supported(&"torch"):`

Other states don't need guards — the AnimationController's fallback-to-idle handles unsupported animations at the playback level.

---

## 7. QuaterniusAdapter

**File:** `assets/characters/quaternius/quaternius_adapter.gd`

Extends `CharacterAdapter`. Attached to the root node of the existing `assets/characters/quaternius/player.tscn`.

```gdscript
class_name QuaterniusAdapter
extends CharacterAdapter

func get_character_name() -> String:
    return "Quaternius"

func get_skeleton() -> Skeleton3D:
    return $Rig/Skeleton3D

func get_animation_tree() -> AnimationTree:
    return $AnimationTree

func get_animation_map() -> Dictionary:
    return { &"idle": &"Idle", &"walk": &"Walk", &"run": &"Sprint", ... }

func get_pose_warping_modifiers() -> Dictionary:
    return {
        "stride": $Rig/Skeleton3D/StrideWarpingModifier,
        "orientation": $Rig/Skeleton3D/OrientationWarpingModifier,
        "slope": $Rig/Skeleton3D/SlopeWarpingModifier,
    }
```

**Zero changes to the Quaternius scene structure.** Only the script on the root node is added.

---

## 8. KayKitAdapter

**File:** `assets/characters/kaykit-adventurers/kaykit_adapter.gd`

Extends `CharacterAdapter`. Handles animation merging, track remapping, and state machine building internally.

### Internal responsibilities (all in `_ready()`)

1. Find the Skeleton3D in the instanced mesh child (path varies by model)
2. Load 7 `Rig_Medium_*.glb` files, extract animations
3. Remap animation track paths from source skeleton path to this character's skeleton path
4. Add remapped animations to the local AnimationPlayer's default library
5. Build an AnimationNodeStateMachine with transitions programmatically
6. Assign the state machine as the AnimationTree's tree_root
7. Set `animation_tree.active = true`

### Fix from v1: `instance.free()` not `instance.queue_free()`

Source GLB instances are never added to the scene tree, so `queue_free()` doesn't work. Use `free()` for immediate cleanup.

### Reuse across KayKit characters

The adapter takes an `@export var mesh_node_name: String` to locate the correct child. Knight, Barbarian, Mage, Rogue each get their own scene that instances a different `.glb` but shares the same `KayKitAdapter` script.

### Scene structure

```
KayKitAdapter (Node3D, script: kaykit_adapter.gd)
├── Knight (instanced Knight.glb)
├── AnimationPlayer (empty library, populated in _ready)
└── AnimationTree (configured in _ready)
```

### Animation map

```
&"idle": &"Idle_A", &"walk": &"Walking_A", &"run": &"Running_A",
&"jump": &"Jump_Start", &"jump_loop": &"Jump_Idle", &"land": &"Jump_Land",
&"crouch_idle": &"Crouching", &"crouch_walk": &"Sneaking",
&"dodge": &"Dodge_Forward", &"stop": &"Idle_A",
&"interact": &"Interact", &"pickup": &"PickUp",
&"low_mantle": &"Interact", &"high_mantle": &"Jump_Land",
&"hit_chest": &"Hit_A", &"hit_head": &"Hit_B", &"death": &"Death_A",
&"sword_idle": &"Melee_2H_Idle",
&"sword_attack": &"Melee_1H_Attack_Slice_Horizontal",
&"punch_enter": &"Melee_Unarmed_Idle",
&"punch_jab": &"Melee_Unarmed_Attack_Punch_A",
&"punch_cross": &"Melee_Unarmed_Attack_Kick",
&"torch": &"Holding_A",
&"sit_enter": &"Sit_Chair_Down", &"sit_idle": &"Sit_Chair_Idle",
&"sit_exit": &"Sit_Chair_StandUp",
&"dance": &"Cheering"
```

### Not supported

`swim_idle`, `swim_fwd`, `drive`, `walk_formal`, `talk`, `craft`, `push`, `pistol_*`, `spell_*`

---

## 9. Files Summary

### New files
| File | Purpose |
|---|---|
| `addons/player_control_core/core/character_adapter.gd` | CharacterAdapter base class |
| `assets/characters/quaternius/quaternius_adapter.gd` | Quaternius adapter script |
| `assets/characters/kaykit-adventurers/kaykit_adapter.gd` | KayKit adapter script |
| `assets/characters/kaykit-adventurers/knight_character.tscn` | Knight character scene |

### Modified files
| File | Changes |
|---|---|
| `assets/characters/quaternius/player.tscn` | Attach QuaterniusAdapter script to root node |
| `scenes/reusable_player.gd` | Add `_bind_character()`, new @onready refs |
| `scenes/player.tscn` | Remove hardcoded NodePaths to character internals |
| `addons/player_control_core/core/animation_controller.gd` | Empty default map, `setup()` method, `is_animation_supported()`, fallback logic |
| `addons/player_control_core/core/state_machine/player_state.gd` | Add `is_animation_supported()` convenience method |
| `addons/player_control_core/core/state_machine/grounded_state.gd` | Guard sit/dance/torch transitions |

### Removed (from v1, already reverted)
| File | Reason |
|---|---|
| `addons/player_control_core/core/character_config.gd` | Replaced by CharacterAdapter |
| `assets/characters/quaternius/quaternius_config.tres` | No longer needed |
| `assets/characters/kaykit-adventurers/knight_config.tres` | No longer needed |
| `assets/characters/kaykit-adventurers/kaykit_character_setup.gd` | Folded into KayKitAdapter |

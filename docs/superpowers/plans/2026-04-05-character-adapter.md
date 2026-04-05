# Character Adapter System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Support multiple character models (Quaternius, KayKit) via a CharacterAdapter interface that decouples the player from character internals.

**Architecture:** Each character scene's root extends `CharacterAdapter`, exposing skeleton, AnimationTree, animation map, and pose warping modifiers through a standard interface. The player's `_bind_character()` method queries the adapter once at `_ready()` and distributes references to all dependent nodes. No runtime swapping, no await, no hardcoded NodePaths into characters.

**Tech Stack:** Godot 4.x, GDScript, GLB/GLTF models

---

## File Structure

### New files
| File | Responsibility |
|---|---|
| `addons/player_control_core/core/character_adapter.gd` | Base class defining the adapter interface |
| `assets/characters/quaternius/quaternius_adapter.gd` | Quaternius implementation — returns internal refs |
| `assets/characters/kaykit-adventurers/kaykit_adapter.gd` | KayKit implementation — merges animations, builds state machine |
| `assets/characters/kaykit-adventurers/knight_character.tscn` | Knight character scene using the adapter |

### Modified files
| File | Changes |
|---|---|
| `addons/player_control_core/core/animation_controller.gd` | Empty default map, `setup()` method, `is_animation_supported()`, fallback logic, remove `_setup_animation_tree()` from `_ready()` |
| `addons/player_control_core/core/state_machine/player_state.gd` | Add `is_animation_supported()` convenience method |
| `addons/player_control_core/core/state_machine/grounded_state.gd` | Guard sit/dance/torch behind `is_animation_supported()` |
| `scenes/reusable_player.gd` | Add `_bind_character()`, new @onready refs |
| `scenes/player.tscn` | Remove hardcoded NodePaths for skeleton/animation_tree/modifiers, add pose warping modifiers into Quaternius scene |
| `assets/characters/quaternius/player.tscn` | Attach QuaterniusAdapter script to root, move pose warping modifiers here |

---

### Task 1: Create CharacterAdapter base class

**Files:**
- Create: `addons/player_control_core/core/character_adapter.gd`

- [ ] **Step 1: Create the base class**

```gdscript
class_name CharacterAdapter
extends Node3D
## Base class for swappable character models.
##
## Each character scene's root extends this and overrides the virtual methods
## to expose its skeleton, animations, and optional pose warping modifiers.
## The player queries this interface — never the character's internals.


## Override: return the display name of this character.
func get_character_name() -> String:
	return "Unknown"


## Override: return this character's Skeleton3D node.
func get_skeleton() -> Skeleton3D:
	return null


## Override: return this character's configured AnimationTree.
func get_animation_tree() -> AnimationTree:
	return null


## Override: return the animation name mapping.
## Keys are logical names (StringName), values are actual animation names.
func get_animation_map() -> Dictionary:
	return {}


## Override: return pose warping modifier nodes.
## Return { "stride": Node, "orientation": Node, "slope": Node } or {} if unsupported.
func get_pose_warping_modifiers() -> Dictionary:
	return {}


## Check if a logical animation name is supported by this character.
func is_animation_supported(logical_name: StringName) -> bool:
	return get_animation_map().has(logical_name)
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/character_adapter.gd
git commit -m "feat: add CharacterAdapter base class for swappable characters"
```

---

### Task 2: Add `setup()` and `is_animation_supported()` to AnimationController

**Files:**
- Modify: `addons/player_control_core/core/animation_controller.gd`

- [ ] **Step 1: Replace the hardcoded animation_map default**

Replace lines 38-82 (the `@export var animation_map` with the large dictionary) with:

```gdscript
@export var animation_map: Dictionary = {}
```

- [ ] **Step 2: Change `_ready()` to not call `_setup_animation_tree()`**

Replace lines 95-98:

```gdscript
func _ready() -> void:
	_validate_dependencies()
	_connect_state_signals()
	_setup_animation_tree()
```

With:

```gdscript
func _ready() -> void:
	_connect_state_signals()
```

- [ ] **Step 3: Remove `_validate_dependencies()`**

Delete lines 101-105 entirely (the `_validate_dependencies` method). It's no longer useful — the animation_tree is assigned by `_bind_character()` after `_ready()`.

- [ ] **Step 4: Add `setup()` method**

Add after `_setup_animation_tree()` (line 126):

```gdscript
## Called by the player after assigning animation_tree and animation_map.
## Must be called before any animation playback occurs.
func setup() -> void:
	_setup_animation_tree()
```

- [ ] **Step 5: Add `is_animation_supported()` method**

Add after `setup()`:

```gdscript
## Check if a logical animation name is supported by the current animation map.
func is_animation_supported(logical_name: StringName) -> bool:
	return animation_map.has(logical_name)
```

- [ ] **Step 6: Add fallback logic to `play_animation()`**

Replace lines 142-163 (the `play_animation` method) with:

```gdscript
## Play an animation by name. Uses AnimationTree if available, else AnimationPlayer.
## Automatically remaps animation names using animation_map.
func play_animation(animation_name: StringName, blend_time: float = -1.0) -> void:
	# Remap animation name if mapping exists
	var mapped_name: StringName = _get_mapped_animation(animation_name)

	# Fallback: if the logical name has no mapping and the map is non-empty, use idle
	if mapped_name == animation_name and animation_map.size() > 0 and not animation_map.has(animation_name):
		_logger.debugf("play_animation('%s') - UNSUPPORTED, falling back to idle", [animation_name])
		mapped_name = _get_mapped_animation(&"idle")
		if mapped_name == &"idle" and not animation_map.has(&"idle"):
			return

	_logger.debugf("play_animation('%s') -> mapped='%s', current='%s'",
		[animation_name, mapped_name, current_animation])

	if mapped_name == current_animation:
		_logger.debug("SKIPPED - same as current")
		return

	var actual_blend := blend_time if blend_time >= 0 else default_blend_time

	if animation_tree and _state_playback:
		_play_via_tree(mapped_name, actual_blend)
	elif animation_player:
		_play_via_player(mapped_name, actual_blend)
	else:
		return

	current_animation = mapped_name
	animation_started.emit(mapped_name)
```

- [ ] **Step 7: Commit**

```bash
git add addons/player_control_core/core/animation_controller.gd
git commit -m "feat: add setup(), is_animation_supported(), and fallback to AnimationController"
```

---

### Task 3: Add `is_animation_supported()` to PlayerState base class

**Files:**
- Modify: `addons/player_control_core/core/state_machine/player_state.gd`

- [ ] **Step 1: Add the convenience method**

Add after the `transition_to` method (after line 71):

```gdscript
## Check if the current character supports a logical animation.
## Returns true if no AnimationController is found (permissive fallback).
func is_animation_supported(logical_name: StringName) -> bool:
	if controller and controller.body:
		var anim_ctrl: AnimationController = controller.body.get_node_or_null("AnimationController")
		if anim_ctrl:
			return anim_ctrl.is_animation_supported(logical_name)
	return true
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/state_machine/player_state.gd
git commit -m "feat: add is_animation_supported() to PlayerState base class"
```

---

### Task 4: Guard transitions in GroundedState

**Files:**
- Modify: `addons/player_control_core/core/state_machine/grounded_state.gd`

- [ ] **Step 1: Guard the sit transition**

Replace lines 118-122:

```gdscript
	# Handle sit input
	if input_router.consume_sit():
		if state_machine.has_state(&"sit"):
			transition_to(&"sit")
			return
```

With:

```gdscript
	# Handle sit input
	if input_router.consume_sit():
		if state_machine.has_state(&"sit") and is_animation_supported(&"sit_enter"):
			transition_to(&"sit")
			return
```

- [ ] **Step 2: Guard the dance transition**

Replace lines 124-128:

```gdscript
	# Handle dance input
	if input_router.consume_dance():
		if state_machine.has_state(&"dance"):
			transition_to(&"dance")
			return
```

With:

```gdscript
	# Handle dance input
	if input_router.consume_dance():
		if state_machine.has_state(&"dance") and is_animation_supported(&"dance"):
			transition_to(&"dance")
			return
```

- [ ] **Step 3: Guard the torch toggle**

Replace lines 130-132:

```gdscript
	# Handle torch toggle
	if input_router.consume_torch_toggle():
		_torch_active = not _torch_active
```

With:

```gdscript
	# Handle torch toggle
	if input_router.consume_torch_toggle():
		if is_animation_supported(&"torch"):
			_torch_active = not _torch_active
```

- [ ] **Step 4: Commit**

```bash
git add addons/player_control_core/core/state_machine/grounded_state.gd
git commit -m "feat: guard sit/dance/torch transitions behind animation support checks"
```

---

### Task 5: Create QuaterniusAdapter and update its scene

**Files:**
- Create: `assets/characters/quaternius/quaternius_adapter.gd`
- Modify: `assets/characters/quaternius/player.tscn`

- [ ] **Step 1: Create the adapter script**

```gdscript
class_name QuaterniusAdapter
extends CharacterAdapter
## Adapter for the Quaternius character model.
##
## Exposes the Quaternius skeleton, AnimationTree, animation map,
## and pose warping modifiers through the standard CharacterAdapter interface.


func get_character_name() -> String:
	return "Quaternius"


func get_skeleton() -> Skeleton3D:
	return $Rig/Skeleton3D


func get_animation_tree() -> AnimationTree:
	return $AnimationTree


func get_animation_map() -> Dictionary:
	return {
		&"idle": &"Idle",
		&"walk": &"Walk",
		&"run": &"Sprint",
		&"jog": &"Jog_Fwd",
		&"walk_formal": &"Walk_Formal",
		&"jump": &"Jump_Start",
		&"jump_loop": &"Jump",
		&"land": &"Jump_Land",
		&"crouch_idle": &"Crouch_Idle",
		&"crouch_walk": &"Crouch_Fwd",
		&"dodge": &"Roll",
		&"stop": &"Idle",
		&"interact": &"Interact",
		&"pickup": &"PickUp_Table",
		&"low_mantle": &"Interact",
		&"high_mantle": &"Jump_Land",
		&"hit_chest": &"Hit_Chest",
		&"hit_head": &"Hit_Head",
		&"death": &"Death01",
		&"punch_enter": &"Punch_Enter",
		&"punch_jab": &"Punch_Jab",
		&"punch_cross": &"Punch_Cross",
		&"sword_idle": &"Sword_Idle",
		&"sword_attack": &"Sword_Attack",
		&"pistol_idle": &"Pistol_Idle",
		&"pistol_aim": &"Pistol_Aim_Neutral",
		&"pistol_shoot": &"Pistol_Shoot",
		&"pistol_reload": &"Pistol_Reload",
		&"spell_enter": &"Spell_Simple_Enter",
		&"spell_idle": &"Spell_Simple_Idle",
		&"spell_shoot": &"Spell_Simple_Shoot",
		&"spell_exit": &"Spell_Simple_Exit",
		&"dance": &"Dance",
		&"push": &"Push",
		&"swim_idle": &"Swim_Idle",
		&"swim_fwd": &"Swim_Fwd",
		&"craft": &"Fixing_Kneeling",
		&"sit_enter": &"Sitting_Enter",
		&"sit_idle": &"Sitting_Idle",
		&"sit_exit": &"Sitting_Exit",
		&"talk": &"Idle_Talking",
		&"torch": &"Idle_Torch",
		&"drive": &"Driving",
	}


func get_pose_warping_modifiers() -> Dictionary:
	return {
		"stride": $Rig/Skeleton3D/StrideWarpingModifier,
		"orientation": $Rig/Skeleton3D/OrientationWarpingModifier,
		"slope": $Rig/Skeleton3D/SlopeWarpingModifier,
	}
```

- [ ] **Step 2: Attach the adapter script to the Quaternius scene root**

In `assets/characters/quaternius/player.tscn`, the root node is currently:

```
[node name="CharacterModel" instance=ExtResource("1_model")]
```

This needs a script reference added. First, add an ext_resource for the adapter script. Find the `[ext_resource ...]` section (line 3) and add after it:

```
[ext_resource type="Script" path="res://assets/characters/quaternius/quaternius_adapter.gd" id="2_adapter"]
```

Then update `load_steps` on line 1 from `130` to `131`.

Then change the root node to:

```
[node name="CharacterModel" instance=ExtResource("1_model")]
script = ExtResource("2_adapter")
```

- [ ] **Step 3: Commit**

```bash
git add assets/characters/quaternius/quaternius_adapter.gd assets/characters/quaternius/player.tscn
git commit -m "feat: add QuaterniusAdapter and attach to character scene"
```

---

### Task 6: Update ReusablePlayer with `_bind_character()`

**Files:**
- Modify: `scenes/reusable_player.gd`

- [ ] **Step 1: Add new @onready references**

After line 18 (`@onready var hud_label`), add:

```gdscript
@onready var character: CharacterAdapter = $CharacterMesh
@onready var animation_controller: AnimationController = $AnimationController
@onready var pose_warping_controller = $PoseWarpingController
@onready var ragdoll_state = $PlayerStateMachine/ragdoll
```

- [ ] **Step 2: Add `_bind_character()` call at the start of `_ready()`**

Change line 27-28 from:

```gdscript
func _ready() -> void:
	# Start with gameplay enabled and inventory hidden
```

To:

```gdscript
func _ready() -> void:
	# Bind character adapter references to all dependent nodes
	_bind_character()

	# Start with gameplay enabled and inventory hidden
```

- [ ] **Step 3: Add the `_bind_character()` method**

Add before `_on_mouse_capture_requested` (before line 132):

```gdscript
## Query the CharacterAdapter and distribute references to dependent nodes.
func _bind_character() -> void:
	if not character:
		push_warning("ReusablePlayer: No CharacterAdapter found at $CharacterMesh")
		return

	var skeleton := character.get_skeleton()
	var anim_tree := character.get_animation_tree()
	var anim_map := character.get_animation_map()
	var modifiers := character.get_pose_warping_modifiers()

	# AnimationController
	if animation_controller:
		animation_controller.animation_tree = anim_tree
		animation_controller.animation_map = anim_map
		animation_controller.setup()

	# RagdollState
	if ragdoll_state and skeleton:
		ragdoll_state.skeleton = skeleton

	# PoseWarpingController
	if pose_warping_controller:
		if modifiers.is_empty():
			pose_warping_controller.set_process(false)
			pose_warping_controller.set_physics_process(false)
		else:
			pose_warping_controller.skeleton = skeleton
			pose_warping_controller.stride_modifier = modifiers.get("stride")
			pose_warping_controller.orientation_modifier = modifiers.get("orientation")
			pose_warping_controller.slope_modifier = modifiers.get("slope")

	# DualPerspectiveController
	if dual_controller:
		dual_controller.character_mesh = character


```

- [ ] **Step 4: Commit**

```bash
git add scenes/reusable_player.gd
git commit -m "feat: add _bind_character() to distribute adapter references"
```

---

### Task 7: Remove hardcoded character NodePaths from player.tscn

**Files:**
- Modify: `scenes/player.tscn`

- [ ] **Step 1: Move pose warping modifiers out of player.tscn**

Remove lines 146-153 (the three SkeletonModifier3D node overrides under `CharacterMesh/Rig/Skeleton3D`):

```
[node name="OrientationWarpingModifier" type="SkeletonModifier3D" parent="CharacterMesh/Rig/Skeleton3D"]
script = ExtResource("26_orient_mod")

[node name="StrideWarpingModifier" type="SkeletonModifier3D" parent="CharacterMesh/Rig/Skeleton3D"]
script = ExtResource("27_stride_mod")

[node name="SlopeWarpingModifier" type="SkeletonModifier3D" parent="CharacterMesh/Rig/Skeleton3D"]
script = ExtResource("28_slope_mod")
```

These modifiers should live inside the Quaternius character scene itself (returned by `get_pose_warping_modifiers()`). If they don't already exist there, add them to `assets/characters/quaternius/player.tscn` under `Rig/Skeleton3D`.

Also remove the now-unused ext_resources for the modifier scripts (ids `26_orient_mod`, `27_stride_mod`, `28_slope_mod`) from the `[ext_resource ...]` section, and decrement `load_steps` by 3.

- [ ] **Step 2: Remove hardcoded skeleton path from RagdollState**

Change line 225-228 from:

```
[node name="ragdoll" type="Node" parent="PlayerStateMachine" node_paths=PackedStringArray("skeleton", "collision_shape")]
script = ExtResource("30_ragdoll")
skeleton = NodePath("../../CharacterMesh/Rig/Skeleton3D")
collision_shape = NodePath("../../CollisionShape3D")
```

To:

```
[node name="ragdoll" type="Node" parent="PlayerStateMachine" node_paths=PackedStringArray("collision_shape")]
script = ExtResource("30_ragdoll")
collision_shape = NodePath("../../CollisionShape3D")
```

The `skeleton` will be assigned by `_bind_character()`.

- [ ] **Step 3: Remove hardcoded animation_tree path from AnimationController**

Change lines 239-242 from:

```
[node name="AnimationController" type="Node" parent="." node_paths=PackedStringArray("state_machine", "animation_tree")]
script = ExtResource("20_anim_ctrl")
state_machine = NodePath("../PlayerStateMachine")
animation_tree = NodePath("../CharacterMesh/AnimationTree")
```

To:

```
[node name="AnimationController" type="Node" parent="." node_paths=PackedStringArray("state_machine")]
script = ExtResource("20_anim_ctrl")
state_machine = NodePath("../PlayerStateMachine")
```

- [ ] **Step 4: Remove hardcoded skeleton/modifier paths from PoseWarpingController**

Change lines 244-251 from:

```
[node name="PoseWarpingController" type="Node" parent="." node_paths=PackedStringArray("skeleton", "velocity_source", "stride_modifier", "orientation_modifier", "slope_modifier")]
script = ExtResource("22_pose_ctrl")
skeleton = NodePath("../CharacterMesh/Rig/Skeleton3D")
velocity_source = NodePath("../PlayerMotor3D")
stride_modifier = NodePath("../CharacterMesh/Rig/Skeleton3D/StrideWarpingModifier")
orientation_modifier = NodePath("../CharacterMesh/Rig/Skeleton3D/OrientationWarpingModifier")
slope_modifier = NodePath("../CharacterMesh/Rig/Skeleton3D/SlopeWarpingModifier")
settings = ExtResource("25_pose_settings")
```

To:

```
[node name="PoseWarpingController" type="Node" parent="." node_paths=PackedStringArray("velocity_source")]
script = ExtResource("22_pose_ctrl")
velocity_source = NodePath("../PlayerMotor3D")
settings = ExtResource("25_pose_settings")
```

The `skeleton`, `stride_modifier`, `orientation_modifier`, and `slope_modifier` will be assigned by `_bind_character()`.

- [ ] **Step 5: Verify in editor**

Open `scenes/player.tscn` in Godot. Verify:
1. No errors in the Output panel
2. The CharacterMesh (Quaternius) still displays in the viewport
3. Running the scene works — movement, animations, pose warping all function

- [ ] **Step 6: Commit**

```bash
git add scenes/player.tscn
git commit -m "feat: remove hardcoded character NodePaths from player scene"
```

---

### Task 8: Create KayKitAdapter and Knight character scene

**Files:**
- Create: `assets/characters/kaykit-adventurers/kaykit_adapter.gd`
- Create: `assets/characters/kaykit-adventurers/knight_character.tscn`

- [ ] **Step 1: Create the KayKit adapter script**

```gdscript
class_name KayKitAdapter
extends CharacterAdapter
## Adapter for KayKit character models.
##
## Merges animations from multiple Rig_Medium GLB files at _ready(),
## builds an AnimationNodeStateMachine, and remaps track paths to match
## this character's skeleton.


## The node name of the instanced character mesh (e.g., "Knight", "Barbarian").
@export var mesh_node_name: String = "Knight"

## Animation source GLB scenes to merge into a single library.
@export var animation_sources: Array[PackedScene] = []

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _animation_tree: AnimationTree = $AnimationTree

var _skeleton: Skeleton3D
var _skeleton_path: String = ""


const ANIMATION_MAP := {
	&"idle": &"Idle_A",
	&"walk": &"Walking_A",
	&"run": &"Running_A",
	&"jump": &"Jump_Start",
	&"jump_loop": &"Jump_Idle",
	&"land": &"Jump_Land",
	&"crouch_idle": &"Crouching",
	&"crouch_walk": &"Sneaking",
	&"dodge": &"Dodge_Forward",
	&"stop": &"Idle_A",
	&"interact": &"Interact",
	&"pickup": &"PickUp",
	&"low_mantle": &"Interact",
	&"high_mantle": &"Jump_Land",
	&"hit_chest": &"Hit_A",
	&"hit_head": &"Hit_B",
	&"death": &"Death_A",
	&"sword_idle": &"Melee_2H_Idle",
	&"sword_attack": &"Melee_1H_Attack_Slice_Horizontal",
	&"punch_enter": &"Melee_Unarmed_Idle",
	&"punch_jab": &"Melee_Unarmed_Attack_Punch_A",
	&"punch_cross": &"Melee_Unarmed_Attack_Kick",
	&"torch": &"Holding_A",
	&"sit_enter": &"Sit_Chair_Down",
	&"sit_idle": &"Sit_Chair_Idle",
	&"sit_exit": &"Sit_Chair_StandUp",
	&"dance": &"Cheering",
}


const TRANSITIONS := {
	"Start->Idle_A": { "xfade": 0.0, "advance_mode": 2 },
	"Idle_A->Walking_A": { "xfade": 0.1 },
	"Walking_A->Idle_A": { "xfade": 0.1 },
	"Walking_A->Running_A": { "xfade": 0.1 },
	"Running_A->Walking_A": { "xfade": 0.1 },
	"Running_A->Idle_A": { "xfade": 0.1 },
	"Idle_A->Running_A": { "xfade": 0.1 },
	"Idle_A->Crouching": { "xfade": 0.15 },
	"Crouching->Idle_A": { "xfade": 0.15 },
	"Crouching->Sneaking": { "xfade": 0.1 },
	"Sneaking->Crouching": { "xfade": 0.1 },
	"Sneaking->Idle_A": { "xfade": 0.15 },
	"Crouching->Walking_A": { "xfade": 0.15 },
	"Idle_A->Jump_Start": { "xfade": 0.05 },
	"Walking_A->Jump_Start": { "xfade": 0.05 },
	"Running_A->Jump_Start": { "xfade": 0.05 },
	"Crouching->Jump_Start": { "xfade": 0.1 },
	"Sneaking->Jump_Start": { "xfade": 0.1 },
	"Jump_Start->Jump_Idle": { "xfade": 0.05 },
	"Jump_Idle->Jump_Land": { "xfade": 0.05 },
	"Jump_Land->Idle_A": { "xfade": 0.1 },
	"Jump_Land->Walking_A": { "xfade": 0.1 },
	"Jump_Land->Running_A": { "xfade": 0.1 },
	"Idle_A->Dodge_Forward": { "xfade": 0.05, "switch_mode": 1 },
	"Walking_A->Dodge_Forward": { "xfade": 0.05, "switch_mode": 1 },
	"Running_A->Dodge_Forward": { "xfade": 0.05, "switch_mode": 1 },
	"Dodge_Forward->Idle_A": { "xfade": 0.35 },
	"Dodge_Forward->Walking_A": { "xfade": 0.35 },
	"Dodge_Forward->Running_A": { "xfade": 0.35 },
	"Idle_A->Sit_Chair_Down": { "xfade": 0.2 },
	"Sit_Chair_Down->Sit_Chair_Idle": { "xfade": 0.1 },
	"Sit_Chair_Idle->Sit_Chair_StandUp": { "xfade": 0.1 },
	"Sit_Chair_StandUp->Idle_A": { "xfade": 0.2 },
	"Idle_A->Cheering": { "xfade": 0.2 },
	"Cheering->Idle_A": { "xfade": 0.2 },
	"Idle_A->Interact": { "xfade": 0.15 },
	"Interact->Idle_A": { "xfade": 0.15 },
	"Idle_A->PickUp": { "xfade": 0.15 },
	"PickUp->Idle_A": { "xfade": 0.15 },
	"Idle_A->Hit_A": { "xfade": 0.05, "switch_mode": 1 },
	"Walking_A->Hit_A": { "xfade": 0.05, "switch_mode": 1 },
	"Running_A->Hit_A": { "xfade": 0.05, "switch_mode": 1 },
	"Idle_A->Hit_B": { "xfade": 0.05, "switch_mode": 1 },
	"Walking_A->Hit_B": { "xfade": 0.05, "switch_mode": 1 },
	"Running_A->Hit_B": { "xfade": 0.05, "switch_mode": 1 },
	"Hit_A->Idle_A": { "xfade": 0.1 },
	"Hit_B->Idle_A": { "xfade": 0.1 },
	"Idle_A->Death_A": { "xfade": 0.05, "switch_mode": 1 },
	"Walking_A->Death_A": { "xfade": 0.05, "switch_mode": 1 },
	"Running_A->Death_A": { "xfade": 0.05, "switch_mode": 1 },
	"Idle_A->Melee_2H_Idle": { "xfade": 0.1 },
	"Melee_2H_Idle->Idle_A": { "xfade": 0.1 },
	"Melee_2H_Idle->Melee_1H_Attack_Slice_Horizontal": { "xfade": 0.05 },
	"Melee_1H_Attack_Slice_Horizontal->Idle_A": { "xfade": 0.15 },
	"Melee_1H_Attack_Slice_Horizontal->Melee_2H_Idle": { "xfade": 0.1 },
	"Idle_A->Melee_Unarmed_Idle": { "xfade": 0.1 },
	"Melee_Unarmed_Idle->Idle_A": { "xfade": 0.1 },
	"Melee_Unarmed_Idle->Melee_Unarmed_Attack_Punch_A": { "xfade": 0.05 },
	"Melee_Unarmed_Attack_Punch_A->Melee_Unarmed_Attack_Kick": { "xfade": 0.05 },
	"Melee_Unarmed_Attack_Kick->Idle_A": { "xfade": 0.15 },
	"Melee_Unarmed_Attack_Punch_A->Idle_A": { "xfade": 0.15 },
	"Idle_A->Holding_A": { "xfade": 0.15 },
	"Holding_A->Idle_A": { "xfade": 0.15 },
	"Holding_A->Walking_A": { "xfade": 0.1 },
	"Walking_A->Holding_A": { "xfade": 0.1 },
}


func _ready() -> void:
	_resolve_skeleton()
	_merge_animations()
	_build_state_machine()
	_animation_tree.active = true


# --- CharacterAdapter interface ---

func get_character_name() -> String:
	return mesh_node_name


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_animation_tree() -> AnimationTree:
	return _animation_tree


func get_animation_map() -> Dictionary:
	return ANIMATION_MAP


func get_pose_warping_modifiers() -> Dictionary:
	return {}


# --- Internal setup ---

func _resolve_skeleton() -> void:
	var mesh_node := get_node_or_null(NodePath(mesh_node_name))
	if not mesh_node:
		push_error("KayKitAdapter: Mesh node '%s' not found" % mesh_node_name)
		return
	_skeleton = _find_node_of_type(mesh_node, "Skeleton3D") as Skeleton3D
	if _skeleton:
		_skeleton_path = String(_animation_player.get_path_to(_skeleton))


func _merge_animations() -> void:
	if not _animation_player:
		push_error("KayKitAdapter: No AnimationPlayer found")
		return

	var default_lib: AnimationLibrary
	if _animation_player.has_animation_library(&""):
		default_lib = _animation_player.get_animation_library(&"")
	else:
		default_lib = AnimationLibrary.new()
		_animation_player.add_animation_library(&"", default_lib)

	for source_scene in animation_sources:
		if not source_scene:
			continue
		var instance := source_scene.instantiate()
		var source_player := _find_node_of_type(instance, "AnimationPlayer") as AnimationPlayer
		if not source_player:
			instance.free()
			continue

		for lib_name in source_player.get_animation_library_list():
			var lib := source_player.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				if not default_lib.has_animation(anim_name):
					var remapped := _remap_tracks(lib.get_animation(anim_name))
					default_lib.add_animation(anim_name, remapped)

		instance.free()


func _build_state_machine() -> void:
	var sm := AnimationNodeStateMachine.new()

	# Collect unique animation names
	var anim_names := {}
	for key in TRANSITIONS:
		for part in (key as String).split("->"):
			if part != "Start":
				anim_names[part] = true

	# Add animation nodes
	for anim_name in anim_names:
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = StringName(anim_name)
		sm.add_node(StringName(anim_name), anim_node)

	# Add transitions
	for key in TRANSITIONS:
		var parts := (key as String).split("->")
		var from := StringName(parts[0])
		var to := StringName(parts[1])
		var config: Dictionary = TRANSITIONS[key]

		var trans := AnimationNodeStateMachineTransition.new()

		if from == &"Start":
			if config.has("advance_mode"):
				trans.advance_mode = config["advance_mode"]
			sm.add_transition(&"Start", to, trans)
			continue

		trans.xfade_time = config.get("xfade", 0.1)
		if config.has("switch_mode"):
			trans.switch_mode = config["switch_mode"]
		sm.add_transition(from, to, trans)

	_animation_tree.tree_root = sm
	_animation_tree.anim_player = _animation_tree.get_path_to(_animation_player)


func _remap_tracks(source_anim: Animation) -> Animation:
	if _skeleton_path.is_empty():
		return source_anim
	var anim := source_anim.duplicate()
	for i in anim.get_track_count():
		var path_str := String(anim.track_get_path(i))
		var skel_idx := path_str.find("Skeleton3D")
		if skel_idx == -1:
			continue
		var new_path := _skeleton_path + path_str.substr(skel_idx + len("Skeleton3D"))
		anim.track_set_path(i, NodePath(new_path))
	return anim


func _find_node_of_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child in node.get_children():
		var result := _find_node_of_type(child, type_name)
		if result:
			return result
	return null
```

- [ ] **Step 2: Create the Knight character scene**

Create `assets/characters/kaykit-adventurers/knight_character.tscn`:

```
[gd_scene load_steps=10 format=3]

[ext_resource type="Script" path="res://assets/characters/kaykit-adventurers/kaykit_adapter.gd" id="1_adapter"]
[ext_resource type="PackedScene" uid="uid://cy370uhy3upjc" path="res://assets/characters/kaykit-adventurers/Characters/gltf/Knight.glb" id="2_knight"]
[ext_resource type="PackedScene" uid="uid://p6q2a3gbsfj2" path="res://assets/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb" id="3_move_basic"]
[ext_resource type="PackedScene" path="res://assets/Animations/gltf/Rig_Medium/Rig_Medium_MovementAdvanced.glb" id="4_move_adv"]
[ext_resource type="PackedScene" path="res://assets/Animations/gltf/Rig_Medium/Rig_Medium_General.glb" id="5_general"]
[ext_resource type="PackedScene" path="res://assets/Animations/gltf/Rig_Medium/Rig_Medium_CombatMelee.glb" id="6_combat"]
[ext_resource type="PackedScene" path="res://assets/Animations/gltf/Rig_Medium/Rig_Medium_Simulation.glb" id="7_simulation"]
[ext_resource type="PackedScene" path="res://assets/Animations/gltf/Rig_Medium/Rig_Medium_Tools.glb" id="8_tools"]

[sub_resource type="AnimationLibrary" id="AnimationLibrary_default"]

[node name="CharacterModel" type="Node3D"]
script = ExtResource("1_adapter")
mesh_node_name = "Knight"
animation_sources = Array[PackedScene]([ExtResource("3_move_basic"), ExtResource("4_move_adv"), ExtResource("5_general"), ExtResource("6_combat"), ExtResource("7_simulation"), ExtResource("8_tools")])

[node name="Knight" parent="." instance=ExtResource("2_knight")]

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries = {
	&"": SubResource("AnimationLibrary_default")
}

[node name="AnimationTree" type="AnimationTree" parent="."]
```

- [ ] **Step 3: Commit**

```bash
git add assets/characters/kaykit-adventurers/kaykit_adapter.gd assets/characters/kaykit-adventurers/knight_character.tscn
git commit -m "feat: add KayKitAdapter and Knight character scene"
```

---

### Task 9: Test end-to-end

- [ ] **Step 1: Test with Quaternius (default)**

1. Open Godot, run the main scene
2. Verify Quaternius character loads, all animations work: idle, walk, run, jump, crouch, dodge, sit, dance, torch
3. Verify pose warping functions (character leans into turns, feet match ground slope)
4. Expected: identical behavior to before any character swap changes

- [ ] **Step 2: Test with Knight**

1. In `scenes/player.tscn`, change the `CharacterMesh` instance from `res://assets/characters/quaternius/player.tscn` to `res://assets/characters/kaykit-adventurers/knight_character.tscn`
2. Adjust the transform scale on CharacterMesh to match ~1.8 unit player height
3. Run the scene
4. Verify: Knight model appears, movement animations play, sit/dance/torch work
5. Verify: unsupported animations (swim, drive, spell, pistol) don't cause errors — they fall back to idle
6. Verify: pose warping is disabled (no errors from missing modifiers)

- [ ] **Step 3: Test with null adapter**

1. Remove the adapter script from the Quaternius scene root (temporarily)
2. Run — verify it doesn't crash (`_bind_character` has null checks)
3. Restore the script

- [ ] **Step 4: Commit any fixes found during testing**

```bash
git add -u
git commit -m "fix: address issues found during character adapter testing"
```

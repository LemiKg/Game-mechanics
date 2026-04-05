# Character Swap System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Support multiple selectable character models (Quaternius + KayKit Adventurers) via an export variable on the Player node, with graceful fallback for unsupported animations.

**Architecture:** A `CharacterConfig` resource bundles character scene path, animation map, and supported animation list. The Player loads the selected config at runtime, instances the character scene, and configures the AnimationController. States guard transitions behind `is_animation_supported()` checks.

**Tech Stack:** Godot 4.x, GDScript, GLB/GLTF models

---

## File Structure

### New files
| File | Responsibility |
|---|---|
| `addons/player_control_core/core/character_config.gd` | CharacterConfig resource class definition |
| `assets/characters/quaternius/quaternius_config.tres` | Quaternius character config resource |
| `assets/characters/kaykit-adventurers/knight_config.tres` | Knight character config resource |
| `assets/characters/kaykit-adventurers/knight_character.tscn` | Knight character scene (mesh + AnimationTree) — must be built in editor |

### Modified files
| File | Changes |
|---|---|
| `addons/player_control_core/core/animation_controller.gd` | Add `is_animation_supported()`, `apply_config()`, dynamic AnimationTree resolution, fallback logic |
| `scenes/reusable_player.gd` | Add `@export var character_config: CharacterConfig`, load character on `_ready()` |
| `scenes/player.tscn` | Remove inline CharacterMesh instance, wire up character_config export |
| `addons/player_control_core/core/state_machine/grounded_state.gd` | Add `is_animation_supported()` guards for sit/dance/torch transitions |

---

### Task 1: Create CharacterConfig resource class

**Files:**
- Create: `addons/player_control_core/core/character_config.gd`

- [ ] **Step 1: Create the CharacterConfig resource script**

```gdscript
class_name CharacterConfig
extends Resource
## Configuration for a swappable character model.
##
## Bundles character scene, animation mapping, and supported animation list.
## Assign to the Player's character_config export to select a character.


## Display name for this character.
@export var character_name: String = ""

## The character scene containing mesh, skeleton, and AnimationTree.
@export var character_scene: PackedScene

## Maps logical animation names (used by states) to actual animation names
## in this character's AnimationTree. Keys are StringName, values are StringName.
## Example: { &"idle": &"Idle", &"walk": &"Walk" }
@export var animation_map: Dictionary = {}

## List of logical animation names this character supports.
## States check this before allowing transitions.
## Derived from animation_map keys — keep in sync.
@export var supported_animations: PackedStringArray = []


## Returns true if this character supports the given logical animation name.
func is_animation_supported(logical_name: StringName) -> bool:
	return logical_name in supported_animations
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/character_config.gd
git commit -m "feat: add CharacterConfig resource class for swappable characters"
```

---

### Task 2: Add `is_animation_supported()` and `apply_config()` to AnimationController

**Files:**
- Modify: `addons/player_control_core/core/animation_controller.gd`

- [ ] **Step 1: Replace the hardcoded animation_map default with an empty dictionary and add new methods**

In `animation_controller.gd`, make these changes:

**Change 1:** Replace the `@export var animation_map` default value (lines 38-82) with an empty dictionary:

```gdscript
@export var animation_map: Dictionary = {}
```

**Change 2:** Add these methods after `_setup_animation_tree()` (after line 126):

```gdscript
## Apply a CharacterConfig to this controller.
## Sets the animation map and resolves the AnimationTree from the character scene.
func apply_config(config: CharacterConfig, character_node: Node) -> void:
	if config and config.animation_map.size() > 0:
		animation_map = config.animation_map

	# Resolve AnimationTree from the instanced character scene
	var tree := _find_animation_tree(character_node)
	if tree:
		animation_tree = tree
		_setup_animation_tree()


## Check if a logical animation name is supported by the current config.
func is_animation_supported(logical_name: StringName) -> bool:
	return animation_map.has(logical_name)


## Recursively find an AnimationTree in the given node's children.
func _find_animation_tree(node: Node) -> AnimationTree:
	if node is AnimationTree:
		return node
	for child in node.get_children():
		var result := _find_animation_tree(child)
		if result:
			return result
	return null
```

**Change 3:** Add a fallback in `play_animation()`. Replace the existing `_get_mapped_animation` call block (lines 143-148) with:

```gdscript
func play_animation(animation_name: StringName, blend_time: float = -1.0) -> void:
	# Remap animation name if mapping exists
	var mapped_name: StringName = _get_mapped_animation(animation_name)

	# Fallback: if the logical name has no mapping and isn't a raw animation name, use idle
	if mapped_name == animation_name and animation_map.size() > 0 and not animation_map.has(animation_name):
		_logger.debugf("play_animation('%s') - UNSUPPORTED, falling back to idle", [animation_name])
		mapped_name = _get_mapped_animation(&"idle")
		if mapped_name == &"idle" and not animation_map.has(&"idle"):
			return  # No idle either, skip entirely

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

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/animation_controller.gd
git commit -m "feat: add apply_config, is_animation_supported, and fallback to AnimationController"
```

---

### Task 3: Update ReusablePlayer to load character from config

**Files:**
- Modify: `scenes/reusable_player.gd`

- [ ] **Step 1: Add character_config export and character loading logic**

In `reusable_player.gd`, add the export variable after the existing exports (after line 24):

```gdscript
## Character configuration — determines which model and animations to use.
@export var character_config: CharacterConfig
```

Add an `@onready` reference to the AnimationController (after line 18):

```gdscript
@onready var animation_controller: AnimationController = $AnimationController
```

Add character loading at the beginning of `_ready()` (before line 29, as the first thing in `_ready()`):

```gdscript
func _ready() -> void:
	# Load character from config
	_load_character()

	# Start with gameplay enabled and inventory hidden
	inventory_ui.visible = false
	# ... rest of existing _ready() code unchanged ...
```

Add the `_load_character()` method at the bottom of the script:

```gdscript
## Loads and instances the character scene from the config.
## Replaces the existing CharacterMesh node if present.
func _load_character() -> void:
	if not character_config or not character_config.character_scene:
		return

	# Remove existing character mesh if present
	var old_mesh := get_node_or_null("CharacterMesh")
	if old_mesh:
		old_mesh.queue_free()
		# Wait one frame for the old node to be freed
		await get_tree().process_frame

	# Instance the new character scene
	var character_instance: Node3D = character_config.character_scene.instantiate()
	character_instance.name = "CharacterMesh"
	add_child(character_instance)
	# Move to top so it's after CollisionShape3D but before other nodes
	move_child(character_instance, 1)

	# Apply config to AnimationController
	if animation_controller:
		animation_controller.apply_config(character_config, character_instance)
```

- [ ] **Step 2: Commit**

```bash
git add scenes/reusable_player.gd
git commit -m "feat: load character scene from CharacterConfig in ReusablePlayer"
```

---

### Task 4: Add animation support guards to GroundedState

**Files:**
- Modify: `addons/player_control_core/core/state_machine/grounded_state.gd`

- [ ] **Step 1: Add a helper to access the AnimationController**

Add a cached reference variable near the top of the class (after line 34):

```gdscript
## Cached reference to the animation controller (resolved on enter).
var _animation_controller: AnimationController
```

In the `enter()` method, resolve the AnimationController (add after line 48, inside `enter()`):

```gdscript
	# Resolve animation controller once
	if not _animation_controller:
		_animation_controller = controller.body.get_node_or_null("AnimationController") if controller and controller.body else null
```

- [ ] **Step 2: Add guards to sit, dance, and torch transitions**

Replace the sit input block (lines 119-122) with:

```gdscript
	# Handle sit input
	if input_router.consume_sit():
		if state_machine.has_state(&"sit") and _is_anim_supported(&"sit_enter"):
			transition_to(&"sit")
			return
```

Replace the dance input block (lines 125-128) with:

```gdscript
	# Handle dance input
	if input_router.consume_dance():
		if state_machine.has_state(&"dance") and _is_anim_supported(&"dance"):
			transition_to(&"dance")
			return
```

Replace the torch toggle block (lines 131-132) with:

```gdscript
	# Handle torch toggle
	if input_router.consume_torch_toggle():
		if _is_anim_supported(&"torch"):
			_torch_active = not _torch_active
```

- [ ] **Step 3: Add the helper method at the bottom of the class**

```gdscript
## Check if the current character supports a logical animation.
## Returns true if no animation controller is found (permissive fallback).
func _is_anim_supported(logical_name: StringName) -> bool:
	if _animation_controller:
		return _animation_controller.is_animation_supported(logical_name)
	return true
```

- [ ] **Step 4: Commit**

```bash
git add addons/player_control_core/core/state_machine/grounded_state.gd
git commit -m "feat: guard sit/dance/torch transitions behind animation support checks"
```

---

### Task 5: Create Quaternius character config

**Files:**
- Create: `assets/characters/quaternius/quaternius_config.tres`

- [ ] **Step 1: Create the Quaternius config resource file**

```tres
[gd_resource type="Resource" script_class="CharacterConfig" load_steps=3 format=3]

[ext_resource type="Script" path="res://addons/player_control_core/core/character_config.gd" id="1_script"]
[ext_resource type="PackedScene" uid="uid://c0wo2ldbnefie" path="res://assets/characters/quaternius/player.tscn" id="2_scene"]

[resource]
script = ExtResource("1_script")
character_name = "Quaternius"
character_scene = ExtResource("2_scene")
animation_map = {
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
	&"drive": &"Driving"
}
supported_animations = PackedStringArray("idle", "walk", "run", "jog", "walk_formal", "jump", "jump_loop", "land", "crouch_idle", "crouch_walk", "dodge", "stop", "interact", "pickup", "low_mantle", "high_mantle", "hit_chest", "hit_head", "death", "punch_enter", "punch_jab", "punch_cross", "sword_idle", "sword_attack", "pistol_idle", "pistol_aim", "pistol_shoot", "pistol_reload", "spell_enter", "spell_idle", "spell_shoot", "spell_exit", "dance", "push", "swim_idle", "swim_fwd", "craft", "sit_enter", "sit_idle", "sit_exit", "talk", "torch", "drive")
```

- [ ] **Step 2: Commit**

```bash
git add assets/characters/quaternius/quaternius_config.tres
git commit -m "feat: add Quaternius character config resource"
```

---

### Task 6: Update player.tscn to use CharacterConfig

**Files:**
- Modify: `scenes/player.tscn`

- [ ] **Step 1: Edit player.tscn**

This task requires careful `.tscn` edits. The changes are:

**Change 1:** Add the CharacterConfig resource as an ext_resource. Add this line in the ext_resource section (after line 24):

```
[ext_resource type="Resource" path="res://assets/characters/quaternius/quaternius_config.tres" id="40_char_config"]
```

**Change 2:** Add `character_config` to the Player node. Change the Player node (line 136-137) to:

```
[node name="Player" type="CharacterBody3D" groups=["player"]]
script = ExtResource("21_player_script")
character_config = ExtResource("40_char_config")
```

**Change 3:** The CharacterMesh instance (line 143-144) should remain as the default character. The `_load_character()` method in reusable_player.gd will replace it at runtime if a config is set. This preserves editor preview.

**Change 4:** Update the AnimationController node (lines 239-242) to remove the hardcoded animation_tree path since it will be resolved dynamically:

```
[node name="AnimationController" type="Node" parent="." node_paths=PackedStringArray("state_machine")]
script = ExtResource("20_anim_ctrl")
state_machine = NodePath("../PlayerStateMachine")
```

Note: The `animation_tree` export is left unset — `apply_config()` will resolve it from the character scene at runtime.

- [ ] **Step 2: Verify in editor**

Open the project in Godot, open `scenes/player.tscn`, and verify:
1. The Player node shows a `character_config` property in the inspector set to the Quaternius config
2. The CharacterMesh still displays in the viewport for editor preview
3. No errors in the Output panel

- [ ] **Step 3: Commit**

```bash
git add scenes/player.tscn
git commit -m "feat: wire CharacterConfig export into player scene"
```

---

### Task 7: Build KayKit Knight character scene and config (editor task)

**Files:**
- Create: `assets/characters/kaykit-adventurers/knight_character.tscn` (in editor)
- Create: `assets/characters/kaykit-adventurers/knight_config.tres`

This task requires the Godot editor for scene assembly. It cannot be done purely in code.

- [ ] **Step 1: Build the Knight character scene in the Godot editor**

1. Create a new scene with a `Node3D` root named `CharacterRoot`
2. Instance `assets/characters/kaykit-adventurers/Characters/gltf/Knight.glb` as a child — this provides the mesh and skeleton
3. Determine the scale factor needed to match ~1.8 unit height. The Quaternius model uses 0.5 scale. Test the Knight's default size and adjust `CharacterRoot.transform.scale` accordingly.
4. Import all 7 animation `.glb` files from `assets/Animations/gltf/Rig_Medium/` (excluding `Rig_Medium_Special.glb` which has skeleton-specific anims):
   - `Rig_Medium_MovementBasic.glb`
   - `Rig_Medium_MovementAdvanced.glb`
   - `Rig_Medium_General.glb`
   - `Rig_Medium_CombatMelee.glb`
   - `Rig_Medium_CombatRanged.glb`
   - `Rig_Medium_Simulation.glb`
   - `Rig_Medium_Tools.glb`
5. Create an `AnimationTree` node as a child of `CharacterRoot`
6. Set the AnimationTree's `anim_player` to point to the Knight's AnimationPlayer
7. Set the AnimationTree's `tree_root` to a new `AnimationNodeStateMachine`
8. Add animation state nodes for each animation used in the KayKit animation map:
   - `Idle_A`, `Walking_A`, `Running_A`, `Jump_Start`, `Jump_Idle`, `Jump_Land`
   - `Crouching`, `Sneaking`, `Dodge_Forward`
   - `Sit_Chair_Down`, `Sit_Chair_Idle`, `Sit_Chair_StandUp`
   - `Cheering`, `Interact`, `PickUp`
   - `Hit_A`, `Hit_B`, `Death_A`
   - `Melee_2H_Idle`, `Melee_1H_Attack_Slice_Horizontal`
   - `Melee_Unarmed_Idle`, `Melee_Unarmed_Attack_Punch_A`, `Melee_Unarmed_Attack_Kick`
   - `Holding_A`
9. Add transitions between states matching the patterns from the Quaternius AnimationTree:
   - Start → Idle_A (advance_mode = 2)
   - Idle_A ↔ Walking_A (xfade 0.1)
   - Walking_A ↔ Running_A (xfade 0.1)
   - Running_A ↔ Idle_A (xfade 0.1)
   - Idle_A ↔ Crouching (xfade 0.15)
   - Crouching ↔ Sneaking (xfade 0.1)
   - Idle_A → Jump_Start (xfade 0.05)
   - Jump_Start → Jump_Idle (xfade 0.05)
   - Jump_Idle → Jump_Land (xfade 0.05)
   - Jump_Land → Idle_A (xfade 0.1)
   - Idle_A → Dodge_Forward (xfade 0.05, switch_mode = 1)
   - Dodge_Forward → Idle_A (xfade 0.35)
   - Idle_A ↔ Sit_Chair_Down (xfade 0.2)
   - Sit_Chair_Down → Sit_Chair_Idle (xfade 0.1)
   - Sit_Chair_Idle → Sit_Chair_StandUp (xfade 0.1)
   - Sit_Chair_StandUp → Idle_A (xfade 0.2)
   - Idle_A → Cheering (xfade 0.2)
   - Cheering → Idle_A (xfade 0.2)
   - Idle_A → Interact (xfade 0.15)
   - Interact → Idle_A (xfade 0.15)
   - Idle_A → PickUp (xfade 0.15)
   - PickUp → Idle_A (xfade 0.15)
   - Any → Hit_A (xfade 0.05, switch_mode = 1)
   - Any → Hit_B (xfade 0.05, switch_mode = 1)
   - Hit_A → Idle_A (xfade 0.1)
   - Hit_B → Idle_A (xfade 0.1)
   - Any → Death_A (xfade 0.05, switch_mode = 1)
   - Idle_A ↔ Melee_2H_Idle (xfade 0.1)
   - Melee_2H_Idle → Melee_1H_Attack_Slice_Horizontal (xfade 0.05)
   - Melee_1H_Attack_Slice_Horizontal → Idle_A (xfade 0.15)
   - Idle_A → Melee_Unarmed_Idle (xfade 0.1)
   - Melee_Unarmed_Idle → Melee_Unarmed_Attack_Punch_A (xfade 0.05)
   - Melee_Unarmed_Attack_Punch_A → Melee_Unarmed_Attack_Kick (xfade 0.05)
   - Melee_Unarmed_Attack_Kick → Idle_A (xfade 0.15)
   - Idle_A ↔ Holding_A (xfade 0.15)
   - Connect all movement states bidirectionally to allow free travel
10. Set AnimationTree `active = true`
11. Save the scene as `assets/characters/kaykit-adventurers/knight_character.tscn`

- [ ] **Step 2: Create the Knight config resource file**

```tres
[gd_resource type="Resource" script_class="CharacterConfig" load_steps=3 format=3]

[ext_resource type="Script" path="res://addons/player_control_core/core/character_config.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://assets/characters/kaykit-adventurers/knight_character.tscn" id="2_scene"]

[resource]
script = ExtResource("1_script")
character_name = "Knight"
character_scene = ExtResource("2_scene")
animation_map = {
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
	&"dance": &"Cheering"
}
supported_animations = PackedStringArray("idle", "walk", "run", "jump", "jump_loop", "land", "crouch_idle", "crouch_walk", "dodge", "stop", "interact", "pickup", "low_mantle", "high_mantle", "hit_chest", "hit_head", "death", "sword_idle", "sword_attack", "punch_enter", "punch_jab", "punch_cross", "torch", "sit_enter", "sit_idle", "sit_exit", "dance")
```

- [ ] **Step 3: Commit**

```bash
git add assets/characters/kaykit-adventurers/knight_character.tscn assets/characters/kaykit-adventurers/knight_config.tres
git commit -m "feat: add KayKit Knight character scene and config"
```

---

### Task 8: Test character swapping end-to-end

- [ ] **Step 1: Test with Quaternius config (default)**

1. Open Godot, run the main scene
2. Verify the Quaternius character loads and all animations work as before
3. Test: idle, walk, run, jump, crouch, dodge, sit, dance, torch toggle
4. Expected: identical behavior to before the changes

- [ ] **Step 2: Test with Knight config**

1. In the editor, select the Player node in `scenes/player.tscn`
2. Change the `character_config` export to `assets/characters/kaykit-adventurers/knight_config.tres`
3. Run the scene
4. Verify: Knight model appears at correct scale, movement animations play, sit/dance/torch work
5. Verify unsupported animations (swim, drive, spell, pistol) don't cause errors

- [ ] **Step 3: Test with no config (null)**

1. Clear the `character_config` export (set to null)
2. Run the scene
3. Verify: the default CharacterMesh (Quaternius) still loads from the scene instance
4. This confirms backward compatibility

- [ ] **Step 4: Commit any fixes found during testing**

```bash
git add -u
git commit -m "fix: address issues found during character swap testing"
```

---

### Task 9: Add remaining KayKit character configs (optional, low priority)

**Files:**
- Create: `assets/characters/kaykit-adventurers/barbarian_character.tscn` (editor)
- Create: `assets/characters/kaykit-adventurers/barbarian_config.tres`
- Create: `assets/characters/kaykit-adventurers/mage_character.tscn` (editor)
- Create: `assets/characters/kaykit-adventurers/mage_config.tres`
- Create: `assets/characters/kaykit-adventurers/rogue_character.tscn` (editor)
- Create: `assets/characters/kaykit-adventurers/rogue_config.tres`

- [ ] **Step 1: Duplicate the Knight character scene for each character**

For each character (Barbarian, Mage, Rogue), follow the same process as Task 7 Step 1 but swap the mesh GLB:
- Barbarian: use `Characters/gltf/Barbarian.glb`
- Mage: use `Characters/gltf/Mage.glb`
- Rogue: use `Characters/gltf/Rogue.glb` or `Rogue_Hooded.glb`

The AnimationTree structure is identical — only the mesh differs. The same merged animation library works for all KayKit characters since they share the same rig.

- [ ] **Step 2: Create config .tres files for each**

Each config is identical to the Knight config from Task 7 Step 2, except:
- `character_name` changes (e.g., `"Barbarian"`)
- `character_scene` points to the respective scene

- [ ] **Step 3: Commit**

```bash
git add assets/characters/kaykit-adventurers/barbarian_* assets/characters/kaykit-adventurers/mage_* assets/characters/kaykit-adventurers/rogue_*
git commit -m "feat: add Barbarian, Mage, and Rogue character configs"
```

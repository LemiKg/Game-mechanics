# Interaction System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add player toggle actions (sit, dance, torch) and a reusable world interaction system (Interactable component + InteractionState).

**Architecture:** New player states (SitState, DanceState, InteractionState) follow the existing pattern from DodgeState — disable motor on enter, re-enable on exit. Input buffering added to PlayerInputRouter3D. Interactable is a reusable Area3D component using WorldItem's focus competition pattern. GroundedState dispatches to new states based on input.

**Tech Stack:** GDScript, Godot 4.6

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `addons/player_control_core/core/player_input_router_3d.gd` | Modify | Add sit/dance/torch input buffering + consume methods |
| `addons/player_control_core/core/state_machine/sit_state.gd` | Create | Sit down/idle/stand up state with motor lock |
| `addons/player_control_core/core/state_machine/dance_state.gd` | Create | Dance loop state with motor lock |
| `addons/player_control_core/core/state_machine/interaction_state.gd` | Create | Timed world interaction state with motor lock |
| `addons/player_control_core/core/interactable.gd` | Create | Area3D component for world objects |
| `addons/player_control_core/core/state_machine/grounded_state.gd` | Modify | Handle sit/dance/torch/interact inputs |
| `scenes/player.tscn` | Modify | Add sit/dance/interaction state nodes |
| `assets/characters/quaternius/player.tscn` | Modify | Add missing animation transitions |

---

### Task 1: Add input buffering to PlayerInputRouter3D

**Files:**
- Modify: `addons/player_control_core/core/player_input_router_3d.gd`

- [ ] **Step 1: Add new input properties and cached action names**

After the existing `_dodge` cached action name (line 64), add:

```gdscript
var _sit: StringName = &"sit"
var _dance: StringName = &"dance"
var _toggle_torch: StringName = &"toggle_torch"
```

After the existing `_dodge_buffered` property (line 51), add:

```gdscript
## True if sit was requested (buffered for physics frame).
var sit_requested: bool = false
var _sit_buffered: bool = false

## True if dance was requested (buffered for physics frame).
var dance_requested: bool = false
var _dance_buffered: bool = false

## True if torch toggle was requested (buffered for physics frame).
var torch_toggle_requested: bool = false
var _torch_toggle_buffered: bool = false
```

- [ ] **Step 2: Clear new inputs when disabled**

In the `enabled` setter (line 17-30), add to the clearing block after `_dodge_buffered = false`:

```gdscript
sit_requested = false
_sit_buffered = false
dance_requested = false
_dance_buffered = false
torch_toggle_requested = false
_torch_toggle_buffered = false
```

- [ ] **Step 3: Cache new action names**

In `_cache_action_names()` (line 71-81), add after the dodge cache:

```gdscript
if "sit" in input_actions:
    _sit = input_actions.sit
if "dance" in input_actions:
    _dance = input_actions.dance
if "toggle_torch" in input_actions:
    _toggle_torch = input_actions.toggle_torch
```

- [ ] **Step 4: Buffer new inputs in _process**

In `_process()` (line 84-99), add after the dodge buffer line:

```gdscript
if Input.is_action_just_pressed(_sit):
    _sit_buffered = true
if Input.is_action_just_pressed(_dance):
    _dance_buffered = true
if Input.is_action_just_pressed(_toggle_torch):
    _torch_toggle_buffered = true
```

- [ ] **Step 5: Transfer buffers in _physics_process**

In `_physics_process()` (line 102-110), add after the dodge transfer:

```gdscript
sit_requested = _sit_buffered
_sit_buffered = false
dance_requested = _dance_buffered
_dance_buffered = false
torch_toggle_requested = _torch_toggle_buffered
_torch_toggle_buffered = false
```

- [ ] **Step 6: Add consume methods**

After `consume_dodge()` (line 121-124), add:

```gdscript
func consume_sit() -> bool:
    var was_requested := sit_requested
    sit_requested = false
    return was_requested

func consume_dance() -> bool:
    var was_requested := dance_requested
    dance_requested = false
    return was_requested

func consume_torch_toggle() -> bool:
    var was_requested := torch_toggle_requested
    torch_toggle_requested = false
    return was_requested
```

- [ ] **Step 7: Commit**

```bash
git add addons/player_control_core/core/player_input_router_3d.gd
git commit -m "feat(input): add sit, dance, torch toggle input buffering"
```

---

### Task 2: Create SitState

**Files:**
- Create: `addons/player_control_core/core/state_machine/sit_state.gd`

- [ ] **Step 1: Create the file**

```gdscript
class_name SitState
extends PlayerState
## Toggle state for sitting down anywhere.
##
## On enter: disables motor, plays sit_enter then sit_idle.
## On exit: plays sit_exit, re-enables motor.
## Exit triggers: sit input again, or any movement input.


## Timer tracking the enter/exit animation before allowing input.
var _anim_timer: float = 0.0

## Whether we're in the idle (seated) phase vs enter/exit animation.
var _is_seated: bool = false

## Whether we're playing the exit animation.
var _is_exiting: bool = false

## Duration of enter/exit animations (approximate).
@export_range(0.1, 2.0, 0.05) var transition_duration: float = 0.5

var _logger := DebugLogger.new("[SitState]")


func enter() -> void:
    _logger.debug("ENTER")
    _anim_timer = 0.0
    _is_seated = false
    _is_exiting = false

    if not motor or not controller or not controller.body:
        transition_to(&"grounded")
        return

    # Clear buffered inputs
    if input_router:
        input_router.consume_jump()
        input_router.consume_dodge()
        input_router.consume_sit()

    motor.enabled = false
    controller.body.velocity = Vector3.ZERO
    request_animation(&"sit_enter", 0.15)


func exit() -> void:
    _logger.debug("EXIT")
    if motor:
        motor.enabled = true


func physics_update(delta: float) -> void:
    if not input_router:
        return

    _anim_timer += delta

    if _is_exiting:
        # Wait for exit animation to finish
        if _anim_timer >= transition_duration:
            transition_to(&"grounded")
        return

    if not _is_seated:
        # Wait for enter animation to finish
        if _anim_timer >= transition_duration:
            _is_seated = true
            request_animation(&"sit_idle", 0.1)
        return

    # Seated — check for exit triggers
    var wants_to_exit := false

    if input_router.consume_sit():
        wants_to_exit = true

    if input_router.movement_intent.length() > 0.3:
        wants_to_exit = true

    if input_router.consume_jump():
        wants_to_exit = true

    if wants_to_exit:
        _begin_exit()


func _begin_exit() -> void:
    _is_exiting = true
    _anim_timer = 0.0
    request_animation(&"sit_exit", 0.1)
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/state_machine/sit_state.gd
git commit -m "feat: add SitState for sit-anywhere player action"
```

---

### Task 3: Create DanceState

**Files:**
- Create: `addons/player_control_core/core/state_machine/dance_state.gd`

- [ ] **Step 1: Create the file**

```gdscript
class_name DanceState
extends PlayerState
## Toggle state for dancing in place.
##
## On enter: disables motor, plays dance animation (loops).
## Exit triggers: dance input again, any movement input, or jump.


var _logger := DebugLogger.new("[DanceState]")


func enter() -> void:
    _logger.debug("ENTER")

    if not motor or not controller or not controller.body:
        transition_to(&"grounded")
        return

    # Clear buffered inputs
    if input_router:
        input_router.consume_jump()
        input_router.consume_dodge()
        input_router.consume_dance()

    motor.enabled = false
    controller.body.velocity = Vector3.ZERO
    request_animation(&"dance", 0.2)


func exit() -> void:
    _logger.debug("EXIT")
    if motor:
        motor.enabled = true


func physics_update(_delta: float) -> void:
    if not input_router:
        return

    var wants_to_exit := false

    if input_router.consume_dance():
        wants_to_exit = true

    if input_router.movement_intent.length() > 0.3:
        wants_to_exit = true

    if input_router.consume_jump():
        wants_to_exit = true

    if wants_to_exit:
        request_animation(&"idle", 0.2)
        transition_to(&"grounded")
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/state_machine/dance_state.gd
git commit -m "feat: add DanceState for dance-in-place player action"
```

---

### Task 4: Create Interactable component

**Files:**
- Create: `addons/player_control_core/core/interactable.gd`

- [ ] **Step 1: Create the file**

```gdscript
class_name Interactable
extends Area3D
## Reusable world interaction component.
##
## Attach to any Node3D. When the player enters the radius and presses
## interact, plays an animation on the player and emits signals.
## Uses the same focus competition pattern as WorldItem.


## Emitted when interaction begins (player pressed interact).
signal interaction_started(player: Node)

## Emitted when interaction completes (after duration).
signal interacted(player: Node)

## Emitted if interaction is cancelled (player moved away).
signal interaction_cancelled(player: Node)


@export_group("Interaction")
## Text shown in the prompt label.
@export var prompt_text: String = "Press E to Interact"
## Animation to play on the player during interaction.
@export var animation_name: StringName = &"interact"
## How long the interaction lasts in seconds. 0 = animation plays, completes instantly.
@export_range(0.0, 30.0, 0.1) var interaction_duration: float = 0.0
## Input action to trigger interaction.
@export var interact_action: StringName = &"interact"

@export_group("Focus")
## Whether to require the player to hold the button.
@export var require_hold: bool = false
## How long to hold before interaction triggers.
@export_range(0.0, 5.0, 0.1) var hold_duration: float = 1.0

## Static focus competition — same pattern as WorldItem.
static var _focused_interactable: Interactable = null
static var _focused_distance: float = INF
static var _focus_frame: int = -1

var _prompt_label: Label3D
var _player_in_range: bool = false
var _player: Node = null


func _ready() -> void:
    _create_prompt()
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
    var frame := Engine.get_physics_frames()
    if frame != _focus_frame:
        _focus_frame = frame
        _focused_interactable = null
        _focused_distance = INF

    if _player_in_range and _player:
        var dist := global_position.distance_to(_player.global_position)
        if dist < _focused_distance:
            _focused_distance = dist
            _focused_interactable = self


func _process(_delta: float) -> void:
    var is_focused := (_focused_interactable == self)
    if _prompt_label:
        _prompt_label.visible = is_focused

    if is_focused and not require_hold and Input.is_action_just_pressed(interact_action):
        _start_interaction()


func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    _player = body
    _player_in_range = true


func _on_body_exited(body: Node3D) -> void:
    if body == _player:
        _player_in_range = false
        _player = null


func _start_interaction() -> void:
    if not _player:
        return
    interaction_started.emit(_player)

    # Find the state machine on the player and transition to interaction
    var state_machine: PlayerStateMachine = null
    for child in _player.get_children():
        if child is Node:
            for grandchild in child.get_children():
                if grandchild is PlayerStateMachine:
                    state_machine = grandchild
                    break
            if child is PlayerStateMachine:
                state_machine = child
                break

    if not state_machine:
        state_machine = _player.get_node_or_null("PlayerStateMachine") as PlayerStateMachine

    if state_machine and state_machine.has_state(&"interaction"):
        # Pass interaction data via meta
        state_machine.set_meta("interaction_data", {
            "interactable": self,
            "animation": animation_name,
            "duration": interaction_duration,
        })
        state_machine.transition_to(&"interaction")
    else:
        # No state machine — just emit the signal directly
        interacted.emit(_player)


func _create_prompt() -> void:
    _prompt_label = Label3D.new()
    _prompt_label.text = prompt_text
    _prompt_label.position = Vector3(0, 1.0, 0)
    _prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _prompt_label.font_size = 32
    _prompt_label.outline_size = 8
    _prompt_label.modulate = Color(1, 1, 1, 0.9)
    _prompt_label.visible = false
    add_child(_prompt_label)


## Get the currently focused interactable (if any). Used by InteractionState.
static func get_focused() -> Interactable:
    return _focused_interactable
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/interactable.gd
git commit -m "feat: add Interactable Area3D component for world interactions"
```

---

### Task 5: Create InteractionState

**Files:**
- Create: `addons/player_control_core/core/state_machine/interaction_state.gd`

- [ ] **Step 1: Create the file**

```gdscript
class_name InteractionState
extends PlayerState
## Active when the player is interacting with a world object.
##
## Reads interaction_data from state machine meta (set by Interactable).
## Disables motor, plays animation, waits for duration, emits signal, exits.


var _interactable: Interactable
var _duration: float = 0.0
var _timer: float = 0.0

var _logger := DebugLogger.new("[InteractionState]")


func enter() -> void:
    _logger.debug("ENTER")
    _timer = 0.0

    if not motor or not controller or not controller.body:
        transition_to(&"grounded")
        return

    # Read interaction data from state machine meta
    var data: Dictionary = state_machine.get_meta("interaction_data", {})
    if data.is_empty():
        _logger.debug("No interaction data, aborting")
        transition_to(&"grounded")
        return

    _interactable = data.get("interactable")
    var anim_name: StringName = data.get("animation", &"interact")
    _duration = data.get("duration", 0.0)

    # Clear buffered inputs
    if input_router:
        input_router.consume_jump()
        input_router.consume_dodge()

    motor.enabled = false
    controller.body.velocity = Vector3.ZERO

    # Face the interactable
    if _interactable and controller.body:
        var dir := _interactable.global_position - controller.body.global_position
        dir.y = 0
        if dir.length() > 0.1:
            controller.body.rotation.y = atan2(dir.x, dir.z)

    request_animation(anim_name, 0.15)


func exit() -> void:
    _logger.debug("EXIT")
    if motor:
        motor.enabled = true

    # Clean up meta
    if state_machine.has_meta("interaction_data"):
        state_machine.remove_meta("interaction_data")


func physics_update(delta: float) -> void:
    if not input_router:
        return

    _timer += delta

    # Allow cancellation via movement
    if input_router.movement_intent.length() > 0.3:
        if _interactable:
            _interactable.interaction_cancelled.emit(controller.body)
        request_animation(&"idle", 0.15)
        transition_to(&"grounded")
        return

    # Check if interaction is complete
    if _timer >= _duration:
        if _interactable:
            _interactable.interacted.emit(controller.body)
        request_animation(&"idle", 0.2)
        transition_to(&"grounded")
```

- [ ] **Step 2: Commit**

```bash
git add addons/player_control_core/core/state_machine/interaction_state.gd
git commit -m "feat: add InteractionState for timed world interactions"
```

---

### Task 6: Wire new states into GroundedState

**Files:**
- Modify: `addons/player_control_core/core/state_machine/grounded_state.gd`

- [ ] **Step 1: Add torch toggle flag**

After the existing `_was_moving` variable (line 28), add:

```gdscript
## Whether torch mode is active (swaps idle animation).
var _torch_active: bool = false
```

- [ ] **Step 2: Add sit/dance/torch/interact input handling**

In `physics_update()`, add after the jump handling block (after line 113) and before `_update_crouch_collision`:

```gdscript
    # Handle sit input
    if input_router.consume_sit():
        if state_machine.has_state(&"sit"):
            transition_to(&"sit")
            return

    # Handle dance input
    if input_router.consume_dance():
        if state_machine.has_state(&"dance"):
            transition_to(&"dance")
            return

    # Handle torch toggle
    if input_router.consume_torch_toggle():
        _torch_active = not _torch_active
```

- [ ] **Step 3: Update animation selection for torch**

In `_update_animation()`, change the final else block (line 179-180) from:

```gdscript
        else:
            new_animation = &"idle"
```

To:

```gdscript
        else:
            new_animation = &"torch" if _torch_active else &"idle"
```

Also update the other `&"idle"` in the stop prediction block (line 178):

```gdscript
                new_animation = &"idle"
```

To:

```gdscript
                new_animation = &"torch" if _torch_active else &"idle"
```

- [ ] **Step 4: Reset torch on enter**

In `enter()` (line 42), do NOT reset `_torch_active` — it should persist across state transitions (player keeps torch out after sitting, dodging, etc.).

- [ ] **Step 5: Commit**

```bash
git add addons/player_control_core/core/state_machine/grounded_state.gd
git commit -m "feat(grounded): handle sit, dance, torch toggle, and interact inputs"
```

---

### Task 7: Wire states into player scene

**Files:**
- Modify: `scenes/player.tscn`

- [ ] **Step 1: Add ext_resources for new scripts**

Add after the existing dodge ext_resource:

```
[ext_resource type="Script" path="res://addons/player_control_core/core/state_machine/sit_state.gd" id="37_sit"]
[ext_resource type="Script" path="res://addons/player_control_core/core/state_machine/dance_state.gd" id="38_dance"]
[ext_resource type="Script" path="res://addons/player_control_core/core/state_machine/interaction_state.gd" id="39_interaction"]
```

- [ ] **Step 2: Add state nodes to PlayerStateMachine**

Add after the ragdoll node:

```
[node name="sit" type="Node" parent="PlayerStateMachine"]
script = ExtResource("37_sit")

[node name="dance" type="Node" parent="PlayerStateMachine"]
script = ExtResource("38_dance")

[node name="interaction" type="Node" parent="PlayerStateMachine"]
script = ExtResource("39_interaction")
```

- [ ] **Step 3: Update load_steps**

Increase `load_steps` by 3 (for the 3 new ext_resources).

- [ ] **Step 4: Commit**

```bash
git add scenes/player.tscn
git commit -m "feat: add sit, dance, interaction state nodes to player scene"
```

---

### Task 8: Add animation transitions for new states

**Files:**
- Modify: `assets/characters/quaternius/player.tscn`

- [ ] **Step 1: Add transition sub-resources**

The animation states for Sitting_Enter, Sitting_Idle, Sitting_Exit, Dance, Interact, Idle_Torch, Fixing_Kneeling, and PickUp_Table already exist in the state machine (wired earlier). The transitions from Idle to these states also already exist.

Verify the following transitions exist (they were added in the animation wiring commit). If any are missing, add them:

- `Idle → Sitting_Enter` (trans_idle_sitting_enter)
- `Sitting_Enter → Sitting_Idle` (trans_sitting_enter_sitting_idle, advance_mode=2)
- `Sitting_Idle → Sitting_Exit` (trans_sitting_idle_sitting_exit)
- `Sitting_Exit → Idle` (trans_sitting_exit_idle, advance_mode=2)
- `Idle → Dance` (trans_idle_dance)
- `Dance → Idle` (trans_dance_idle)
- `Idle → Interact` (trans_idle_interact)
- `Interact → Idle` (trans_interact_idle)

Also add transitions from Walk/Sprint to these states (so the player can sit/dance/interact while moving):

Add new transition sub-resources:

```
[sub_resource type="AnimationNodeStateMachineTransition" id="trans_walk_sitting_enter"]
xfade_time = 0.15

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_sprint_sitting_enter"]
xfade_time = 0.15

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_walk_dance"]
xfade_time = 0.2

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_sprint_dance"]
xfade_time = 0.2

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_walk_interact"]
xfade_time = 0.1

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_sprint_interact"]
xfade_time = 0.1

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_idle_idle_torch"]
xfade_time = 0.2

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_idle_torch_idle"]
xfade_time = 0.2

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_idle_torch_walk"]
xfade_time = 0.1

[sub_resource type="AnimationNodeStateMachineTransition" id="trans_walk_idle_torch"]
xfade_time = 0.1
```

- [ ] **Step 2: Append transitions to the transitions array**

Add to the end of the transitions array:

```
, "Walk", "Sitting_Enter", SubResource("trans_walk_sitting_enter"), "Sprint", "Sitting_Enter", SubResource("trans_sprint_sitting_enter"), "Walk", "Dance", SubResource("trans_walk_dance"), "Sprint", "Dance", SubResource("trans_sprint_dance"), "Walk", "Interact", SubResource("trans_walk_interact"), "Sprint", "Interact", SubResource("trans_sprint_interact"), "Idle", "Idle_Torch", SubResource("trans_idle_idle_torch"), "Idle_Torch", "Idle", SubResource("trans_idle_torch_idle"), "Idle_Torch", "Walk", SubResource("trans_idle_torch_walk"), "Walk", "Idle_Torch", SubResource("trans_walk_idle_torch")
```

- [ ] **Step 3: Update load_steps**

Increase `load_steps` by the number of new sub-resources added (10).

- [ ] **Step 4: Commit**

```bash
git add assets/characters/quaternius/player.tscn
git commit -m "feat: add animation transitions for sit, dance, interact, torch states"
```

---

### Task 9: Register input actions in project settings

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Add input actions**

Add the following input actions to the project's input map (via Project Settings > Input Map, or directly in project.godot):

- `sit` — Key X
- `dance` — Key H
- `toggle_torch` — Key G

These can be added by running the game and configuring in Project Settings, or by editing project.godot directly. The format in project.godot is:

```
[input]

sit={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":88,"key_label":0,"unicode":120,"location":0,"echo":false,"script":null)
]
}
dance={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":72,"key_label":0,"unicode":104,"location":0,"echo":false,"script":null)
]
}
toggle_torch={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":71,"key_label":0,"unicode":103,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 2: Commit**

```bash
git add project.godot
git commit -m "feat: add sit, dance, toggle_torch input actions"
```

---

## Task Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Input buffering for sit/dance/torch | player_input_router_3d.gd |
| 2 | SitState | sit_state.gd (new) |
| 3 | DanceState | dance_state.gd (new) |
| 4 | Interactable component | interactable.gd (new) |
| 5 | InteractionState | interaction_state.gd (new) |
| 6 | GroundedState dispatch | grounded_state.gd |
| 7 | Wire states in player scene | scenes/player.tscn |
| 8 | Animation transitions | assets/.../player.tscn |
| 9 | Input actions in project settings | project.godot |

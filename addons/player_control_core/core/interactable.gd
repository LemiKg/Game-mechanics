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
## How long the interaction lasts in seconds. 0 = completes instantly after animation starts.
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

	# Find the state machine on the player
	var state_machine: PlayerStateMachine = _player.get_node_or_null("PlayerStateMachine") as PlayerStateMachine

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


## Get the currently focused interactable (if any).
static func get_focused() -> Interactable:
	return _focused_interactable

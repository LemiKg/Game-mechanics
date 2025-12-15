class_name AnimationController
extends Node
## Bridges player states to animation playback.
##
## Connects to PlayerState animation_requested signals and drives
## an AnimationTree or AnimationPlayer. Follows the dependency injection
## pattern with @export references.


## Emitted when an animation starts playing.
signal animation_started(animation_name: StringName)


@export_group("Dependencies")
## The state machine to listen to for animation requests.
@export var state_machine: PlayerStateMachine

## AnimationTree for state machine-based blending (preferred).
@export var animation_tree: AnimationTree

## Fallback AnimationPlayer if not using AnimationTree.
@export var animation_player: AnimationPlayer


@export_group("Settings")
## Default blend time when not specified by state.
@export_range(0.0, 1.0, 0.05) var default_blend_time: float = 0.2

## Animation state machine parameter path (for AnimationTree).
@export var state_machine_path: String = "parameters/playback"


## Currently playing animation name.
var current_animation: StringName = &""

## Reference to AnimationTree state machine playback.
var _state_playback: AnimationNodeStateMachinePlayback


func _ready() -> void:
	_validate_dependencies()
	_connect_state_signals()
	_setup_animation_tree()


func _validate_dependencies() -> void:
	if not state_machine:
		push_warning("AnimationController: 'state_machine' is not assigned")
	if not animation_tree and not animation_player:
		push_warning("AnimationController: No animation_tree or animation_player assigned")


func _connect_state_signals() -> void:
	if not state_machine:
		return
	
	# Connect to all state's animation_requested signals
	for state in state_machine.states.values():
		if state is PlayerState:
			state.animation_requested.connect(_on_animation_requested)
	
	# Also connect to state_changed for automatic state-based animations
	state_machine.state_changed.connect(_on_state_changed)


func _setup_animation_tree() -> void:
	if animation_tree and state_machine_path:
		_state_playback = animation_tree.get(state_machine_path)
		if not _state_playback:
			push_warning("AnimationController: Could not get state machine playback at '%s'" % state_machine_path)


func _on_animation_requested(animation_name: StringName, blend_time: float) -> void:
	play_animation(animation_name, blend_time)


func _on_state_changed(_old_state: PlayerState, _new_state: PlayerState) -> void:
	# Optional: auto-play animation matching state name
	# Uncomment if you want automatic state-to-animation mapping:
	# if _new_state and has_animation(_new_state.name):
	#     play_animation(_new_state.name)
	pass


## Play an animation by name. Uses AnimationTree if available, else AnimationPlayer.
func play_animation(animation_name: StringName, blend_time: float = -1.0) -> void:
	if animation_name == current_animation:
		return
	
	var actual_blend := blend_time if blend_time >= 0 else default_blend_time
	
	if animation_tree and _state_playback:
		_play_via_tree(animation_name, actual_blend)
	elif animation_player:
		_play_via_player(animation_name, actual_blend)
	else:
		return
	
	current_animation = animation_name
	animation_started.emit(animation_name)


func _play_via_tree(animation_name: StringName, _blend_time: float) -> void:
	if _state_playback.has_node(animation_name):
		_state_playback.travel(animation_name)
	else:
		push_warning("AnimationController: Animation '%s' not found in AnimationTree" % animation_name)


func _play_via_player(animation_name: StringName, blend_time: float) -> void:
	if animation_player.has_animation(animation_name):
		if blend_time > 0 and current_animation:
			animation_player.play(animation_name, blend_time)
		else:
			animation_player.play(animation_name)
	else:
		push_warning("AnimationController: Animation '%s' not found in AnimationPlayer" % animation_name)


## Check if an animation exists.
func has_animation(animation_name: StringName) -> bool:
	if animation_tree and _state_playback:
		return _state_playback.has_node(animation_name)
	elif animation_player:
		return animation_player.has_animation(animation_name)
	return false


## Stop the current animation.
func stop_animation() -> void:
	if animation_player:
		animation_player.stop()
	current_animation = &""


## Get the current playback position.
func get_playback_position() -> float:
	if animation_player and current_animation:
		return animation_player.current_animation_position
	return 0.0

class_name PlayerStateMachine
extends Node
## Manages player state transitions and delegates updates to active state.
##
## Add PlayerState children and configure initial_state in the inspector.
## States are registered by their node name (snake_case recommended).


## Emitted when state changes.
signal state_changed(old_state: PlayerState, new_state: PlayerState)

@export_group("Configuration")
## The state to start in. Must be a child PlayerState node.
@export var initial_state: PlayerState
## Reference to the player controller. Required.
@export var controller: BasePlayerController3D

## The currently active state.
var current_state: PlayerState

## Dictionary of state name → PlayerState node.
var states: Dictionary = {}

## The state that was active before entering UI state (for restoration).
var _previous_state_name: StringName = &""

## Stack for pushdown automata - stores states for temporary interrupts.
var _state_stack: Array[PlayerState] = []


func _ready() -> void:
	_validate_dependencies()
	_register_states()
	_initialize_state()


func _validate_dependencies() -> void:
	if not controller:
		push_warning("PlayerStateMachine: 'controller' is not assigned.")


func _register_states() -> void:
	for child in get_children():
		if child is PlayerState:
			var state := child as PlayerState
			state.state_machine = self
			states[child.name] = state


func _initialize_state() -> void:
	if initial_state:
		current_state = initial_state
		current_state.enter()
	elif states.size() > 0:
		# Fallback to first state if no initial specified
		current_state = states.values()[0]
		current_state.enter()
		push_warning("PlayerStateMachine: No initial_state set, using '%s'" % current_state.name)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _process(delta: float) -> void:
	if current_state:
		current_state.frame_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


## Transition to a state by name. Returns true if successful.
func transition_to(state_name: StringName) -> bool:
	if not states.has(state_name):
		push_warning("PlayerStateMachine: Unknown state '%s'" % state_name)
		return false
	
	var new_state: PlayerState = states[state_name]
	if new_state == current_state:
		return false
	
	var old_state := current_state
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter()
	
	state_changed.emit(old_state, new_state)
	return true


## Transition to UI state, remembering the previous state for restoration.
func enter_ui_state() -> void:
	if current_state and current_state.name != &"ui":
		_previous_state_name = current_state.name
	transition_to(&"ui")


## Exit UI state and return to the previous gameplay state.
func exit_ui_state() -> void:
	if _previous_state_name and states.has(_previous_state_name):
		transition_to(_previous_state_name)
	else:
		# Fallback to grounded
		transition_to(&"grounded")
	_previous_state_name = &""


## Get a state by name. Returns null if not found.
func get_state(state_name: StringName) -> PlayerState:
	return states.get(state_name)


## Check if a state exists by name.
func has_state(state_name: StringName) -> bool:
	return states.has(state_name)


## Push current state onto stack and transition to a new state.
## Use for temporary interrupts (attacks, stagger) that return to previous state.
func push_state(state_name: StringName) -> bool:
	if not states.has(state_name):
		push_warning("PlayerStateMachine: Cannot push unknown state '%s'" % state_name)
		return false
	
	if current_state:
		_state_stack.push_back(current_state)
	
	return transition_to(state_name)


## Pop the previous state from stack and transition back to it.
## Returns false if stack is empty.
func pop_state() -> bool:
	if _state_stack.is_empty():
		push_warning("PlayerStateMachine: Cannot pop, state stack is empty")
		return false
	
	var previous_state := _state_stack.pop_back()
	return transition_to(previous_state.name)


## Clear the state stack. Use when forcibly changing state context.
func clear_state_stack() -> void:
	_state_stack.clear()

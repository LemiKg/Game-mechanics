class_name InteractionState
extends PlayerState
## Active when the player is interacting with a world object.
##
## Reads interaction_data from state machine meta (set by Interactable).
## Disables motor, plays animation, waits for duration, emits signal, exits.


var _interactable: Node  # Interactable reference
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
		var dir: Vector3 = _interactable.global_position - controller.body.global_position
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
		if _interactable and _interactable.has_signal("interaction_cancelled"):
			_interactable.interaction_cancelled.emit(controller.body)
		request_animation(&"idle", 0.15)
		transition_to(&"grounded")
		return

	# Check if interaction is complete
	if _timer >= _duration:
		if _interactable and _interactable.has_signal("interacted"):
			_interactable.interacted.emit(controller.body)
		request_animation(&"idle", 0.2)
		transition_to(&"grounded")

class_name InteractionState
extends PlayerState
## Active when the player is interacting with a world object.
##
## Caller must invoke start_interaction() before transitioning to this state.
## Disables motor, plays animation, waits for duration, emits signal, exits.


var _interactable: Node  # Interactable reference
var _pending_animation: StringName = &"interact"
var _duration: float = 0.0
var _timer: float = 0.0

var _logger := DebugLogger.new("[InteractionState]")


## Set up interaction data before transitioning to this state.
## Call this BEFORE state_machine.transition_to(&"interaction").
func start_interaction(interactable: Node, animation: StringName = &"interact", duration: float = 0.0) -> void:
	_interactable = interactable
	_pending_animation = animation
	_duration = duration


func enter() -> void:
	_logger.debug("ENTER")
	_timer = 0.0

	if not motor or not controller or not controller.body:
		transition_to(&"grounded")
		return

	if not _interactable:
		_logger.debug("No interactable set, aborting")
		transition_to(&"grounded")
		return

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

	request_animation(_pending_animation, 0.15)


func exit() -> void:
	_logger.debug("EXIT")
	if motor:
		motor.enabled = true
	_interactable = null
	_pending_animation = &"interact"


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

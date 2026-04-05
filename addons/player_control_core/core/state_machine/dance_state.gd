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

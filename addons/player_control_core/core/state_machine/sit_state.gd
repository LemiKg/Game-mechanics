class_name SitState
extends PlayerState
## Toggle state for sitting down anywhere.
##
## On enter: disables motor, plays sit_enter then sit_idle.
## On exit: plays sit_exit, re-enables motor.
## Exit triggers: sit input again, any movement input, or jump.


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

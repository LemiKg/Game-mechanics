class_name UIState
extends PlayerState
## Active when gameplay is disabled (e.g., inventory open).
##
## Disables motor and input router. Blocks all gameplay input.


func enter() -> void:
	# Disable motor movement
	if motor:
		motor.enabled = false
	
	# Disable input processing
	if input_router:
		input_router.enabled = false
	
	# Disable look controller if available (FPS-specific, handled by controller)
	if controller and controller.has_method(&"_on_ui_state_entered"):
		controller._on_ui_state_entered()


func exit() -> void:
	# Re-enable motor
	if motor:
		motor.enabled = true
	
	# Re-enable input
	if input_router:
		input_router.enabled = true
	
	# Re-enable look controller if available
	if controller and controller.has_method(&"_on_ui_state_exited"):
		controller._on_ui_state_exited()


func physics_update(_delta: float) -> void:
	# No movement in UI state
	pass


func handle_input(event: InputEvent) -> bool:
	# Block all gameplay input while in UI
	return false

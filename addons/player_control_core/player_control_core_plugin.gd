@tool
class_name PlayerControlCorePlugin
extends EditorPlugin


func _enter_tree() -> void:
	# State machine
	add_custom_type(
		"PlayerStateMachine",
		"Node",
		preload("res://addons/player_control_core/core/state_machine/player_state_machine.gd"),
		preload("res://addons/player_control_core/icons/state_machine.svg")
	)
	add_custom_type(
		"PlayerState",
		"Node",
		preload("res://addons/player_control_core/core/state_machine/player_state.gd"),
		preload("res://addons/player_control_core/icons/state.svg")
	)
	add_custom_type(
		"GroundedState",
		"Node",
		preload("res://addons/player_control_core/core/state_machine/grounded_state.gd"),
		preload("res://addons/player_control_core/icons/state.svg")
	)
	add_custom_type(
		"AirborneState",
		"Node",
		preload("res://addons/player_control_core/core/state_machine/airborne_state.gd"),
		preload("res://addons/player_control_core/icons/state.svg")
	)
	add_custom_type(
		"UIState",
		"Node",
		preload("res://addons/player_control_core/core/state_machine/ui_state.gd"),
		preload("res://addons/player_control_core/icons/state.svg")
	)
	
	# Core components
	add_custom_type(
		"BasePlayerController3D",
		"Node",
		preload("res://addons/player_control_core/core/base_player_controller_3d.gd"),
		preload("res://addons/player_control_core/icons/controller.svg")
	)
	add_custom_type(
		"DualPerspectiveController3D",
		"Node",
		preload("res://addons/player_control_core/core/dual_perspective_controller_3d.gd"),
		preload("res://addons/player_control_core/icons/controller.svg")
	)
	add_custom_type(
		"PlayerMotor3D",
		"Node",
		preload("res://addons/player_control_core/core/player_motor_3d.gd"),
		preload("res://addons/player_control_core/icons/motor.svg")
	)
	add_custom_type(
		"PlayerInputRouter3D",
		"Node",
		preload("res://addons/player_control_core/core/player_input_router_3d.gd"),
		preload("res://addons/player_control_core/icons/input.svg")
	)
	
	# Resources
	add_custom_type(
		"MovementSettings3D",
		"Resource",
		preload("res://addons/player_control_core/core/movement_settings_3d.gd"),
		preload("res://addons/player_control_core/icons/settings.svg")
	)
	add_custom_type(
		"InputActions3D",
		"Resource",
		preload("res://addons/player_control_core/core/input_actions_3d.gd"),
		preload("res://addons/player_control_core/icons/input.svg")
	)


func _exit_tree() -> void:
	# State machine
	remove_custom_type("PlayerStateMachine")
	remove_custom_type("PlayerState")
	remove_custom_type("GroundedState")
	remove_custom_type("AirborneState")
	remove_custom_type("UIState")
	
	# Core components
	remove_custom_type("BasePlayerController3D")
	remove_custom_type("DualPerspectiveController3D")
	remove_custom_type("PlayerMotor3D")
	remove_custom_type("PlayerInputRouter3D")
	
	# Resources
	remove_custom_type("MovementSettings3D")
	remove_custom_type("InputActions3D")

@tool
class_name PlayerControlFPSPlugin
extends EditorPlugin
## FPS Player Control addon plugin.
##
## Depends on player_control_core addon being enabled.


const CORE_ADDON_PATH := "res://addons/player_control_core/plugin.cfg"


func _enter_tree() -> void:
	# Check if core addon exists
	if not FileAccess.file_exists(CORE_ADDON_PATH):
		push_error("Player Control FPS: Required addon 'player_control_core' not found. Please install it first.")
		return
	
	# Check if core addon is enabled (check if types are registered)
	if not _is_core_addon_enabled():
		push_warning("Player Control FPS: Addon 'player_control_core' is not enabled. Please enable it in Project Settings → Plugins.")
	
	# FPS-specific controller
	add_custom_type(
		"FPSPlayerController3D",
		"Node",
		preload("res://addons/player_control_fps/core/fps_player_controller_3d.gd"),
		preload("res://addons/player_control_fps/icons/controller.svg")
	)
	
	# FPS look controller
	add_custom_type(
		"PlayerLookController3D",
		"Node",
		preload("res://addons/player_control_fps/core/player_look_controller_3d.gd"),
		preload("res://addons/player_control_fps/icons/camera.svg")
	)
	
	# FPS-specific settings
	add_custom_type(
		"FPSLookSettings3D",
		"Resource",
		preload("res://addons/player_control_fps/core/fps_look_settings_3d.gd"),
		preload("res://addons/player_control_fps/icons/settings.svg")
	)
	
	# Keep legacy types for backwards compatibility (deprecated)
	_register_legacy_types()


func _exit_tree() -> void:
	# FPS-specific types
	remove_custom_type("FPSPlayerController3D")
	remove_custom_type("PlayerLookController3D")
	remove_custom_type("FPSLookSettings3D")
	
	# Legacy types
	remove_custom_type("PlayerController3D")
	remove_custom_type("FPSInputActions")
	remove_custom_type("FPSMovementSettings3D")


func _is_core_addon_enabled() -> bool:
	# Try to check if BasePlayerController3D class exists
	# This is a heuristic - if core addon is enabled, the class should be available
	var script := load("res://addons/player_control_core/core/base_player_controller_3d.gd")
	return script != null


func _register_legacy_types() -> void:
	# These are kept for backwards compatibility but point to core or deprecated files
	# Users should migrate to core types
	# Legacy PlayerController3D - kept for scenes that haven't migrated
	if FileAccess.file_exists("res://addons/player_control_fps/core/player_controller_3d.gd"):
		add_custom_type(
			"PlayerController3D",
			"Node",
			preload("res://addons/player_control_fps/core/player_controller_3d.gd"),
			preload("res://addons/player_control_fps/icons/controller.svg")
		)
	
	# Legacy FPSInputActions - deprecated, use InputActions3D from core
	if FileAccess.file_exists("res://addons/player_control_fps/core/fps_input_actions.gd"):
		add_custom_type(
			"FPSInputActions",
			"Resource",
			preload("res://addons/player_control_fps/core/fps_input_actions.gd"),
			preload("res://addons/player_control_fps/icons/settings.svg")
		)
	
	# Legacy FPSMovementSettings3D - deprecated, use MovementSettings3D from core
	if FileAccess.file_exists("res://addons/player_control_fps/core/fps_movement_settings_3d.gd"):
		add_custom_type(
			"FPSMovementSettings3D",
			"Resource",
			preload("res://addons/player_control_fps/core/fps_movement_settings_3d.gd"),
			preload("res://addons/player_control_fps/icons/settings.svg")
		)

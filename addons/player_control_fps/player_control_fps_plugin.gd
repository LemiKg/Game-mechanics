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


func _exit_tree() -> void:
	# FPS-specific types
	remove_custom_type("FPSPlayerController3D")
	remove_custom_type("PlayerLookController3D")
	remove_custom_type("FPSLookSettings3D")


func _is_core_addon_enabled() -> bool:
	# Try to check if BasePlayerController3D class exists
	# This is a heuristic - if core addon is enabled, the class should be available
	var script := load("res://addons/player_control_core/core/base_player_controller_3d.gd")
	return script != null

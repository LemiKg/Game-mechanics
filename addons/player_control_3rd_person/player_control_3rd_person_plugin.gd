@tool
class_name PlayerControl3rdPersonPlugin
extends EditorPlugin
## Third-Person Player Control addon plugin.
##
## Depends on player_control_core addon being enabled.


const CORE_ADDON_PATH := "res://addons/player_control_core/plugin.cfg"


func _enter_tree() -> void:
	# Check if core addon exists
	if not FileAccess.file_exists(CORE_ADDON_PATH):
		push_error("Player Control Third Person: Required addon 'player_control_core' not found. Please install it first.")
		return
	
	# Check if core addon is enabled
	if not _is_core_addon_enabled():
		push_warning("Player Control Third Person: Addon 'player_control_core' is not enabled. Please enable it in Project Settings → Plugins.")
	
	# Third-person controller
	add_custom_type(
		"ThirdPersonController3D",
		"Node",
		preload("res://addons/player_control_3rd_person/core/third_person_controller_3d.gd"),
		preload("res://addons/player_control_3rd_person/icons/controller.svg")
	)
	
	# Orbit camera controller
	add_custom_type(
		"OrbitCameraController3D",
		"Node",
		preload("res://addons/player_control_3rd_person/core/orbit_camera_controller_3d.gd"),
		preload("res://addons/player_control_3rd_person/icons/camera.svg")
	)
	
	# Orbit camera settings
	add_custom_type(
		"OrbitCameraSettings3D",
		"Resource",
		preload("res://addons/player_control_3rd_person/core/orbit_camera_settings_3d.gd"),
		preload("res://addons/player_control_3rd_person/icons/settings.svg")
	)


func _exit_tree() -> void:
	remove_custom_type("ThirdPersonController3D")
	remove_custom_type("OrbitCameraController3D")
	remove_custom_type("OrbitCameraSettings3D")


func _is_core_addon_enabled() -> bool:
	var script := load("res://addons/player_control_core/core/base_player_controller_3d.gd")
	return script != null

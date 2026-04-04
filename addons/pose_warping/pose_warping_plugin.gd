@tool
class_name PoseWarpingPlugin
extends EditorPlugin


func _enter_tree() -> void:
	# Register Resource types
	add_custom_type(
		"PoseWarpingSettings",
		"Resource",
		preload("core/pose_warping_settings.gd"),
		null
	)
	
	# Register Node types
	add_custom_type(
		"PoseWarpingController",
		"Node",
		preload("core/pose_warping_controller.gd"),
		preload("icons/pose_warping.svg")
	)
	
	# Register SkeletonModifier3D types
	add_custom_type(
		"StrideWarpingModifier",
		"SkeletonModifier3D",
		preload("core/stride_warping_modifier.gd"),
		null
	)
	add_custom_type(
		"OrientationWarpingModifier",
		"SkeletonModifier3D",
		preload("core/orientation_warping_modifier.gd"),
		null
	)
	add_custom_type(
		"SlopeWarpingModifier",
		"SkeletonModifier3D",
		preload("core/slope_warping_modifier.gd"),
		null
	)


func _exit_tree() -> void:
	remove_custom_type("PoseWarpingSettings")
	remove_custom_type("PoseWarpingController")
	remove_custom_type("StrideWarpingModifier")
	remove_custom_type("OrientationWarpingModifier")
	remove_custom_type("SlopeWarpingModifier")

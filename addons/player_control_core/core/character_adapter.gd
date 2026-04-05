class_name CharacterAdapter
extends Node3D
## Base class for swappable character models.
##
## Each character scene's root extends this and overrides the virtual methods
## to expose its skeleton, animations, and optional pose warping modifiers.
## The player queries this interface — never the character's internals.


## Override: return the display name of this character.
func get_character_name() -> String:
	return "Unknown"


## Override: return this character's Skeleton3D node.
func get_skeleton() -> Skeleton3D:
	return null


## Override: return this character's configured AnimationTree.
func get_animation_tree() -> AnimationTree:
	return null


## Override: return the animation name mapping.
## Keys are logical names (StringName), values are actual animation names.
func get_animation_map() -> Dictionary:
	return {}


## Override: return pose warping modifier nodes.
## Return { "stride": Node, "orientation": Node, "slope": Node } or {} if unsupported.
func get_pose_warping_modifiers() -> Dictionary:
	return {}


## Check if a logical animation name is supported by this character.
func is_animation_supported(logical_name: StringName) -> bool:
	return get_animation_map().has(logical_name)

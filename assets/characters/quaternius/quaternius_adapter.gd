class_name QuaterniusAdapter
extends CharacterAdapter
## Adapter for the Quaternius character model.
##
## Exposes the Quaternius skeleton, AnimationTree, animation map,
## and pose warping modifiers through the standard CharacterAdapter interface.


func get_character_name() -> String:
	return "Quaternius"


func get_skeleton() -> Skeleton3D:
	return $Rig/Skeleton3D


func get_animation_tree() -> AnimationTree:
	return $AnimationTree


func get_animation_map() -> Dictionary:
	return {
		&"idle": &"Idle",
		&"walk": &"Walk",
		&"run": &"Sprint",
		&"jog": &"Jog_Fwd",
		&"walk_formal": &"Walk_Formal",
		&"jump": &"Jump_Start",
		&"jump_loop": &"Jump",
		&"land": &"Jump_Land",
		&"crouch_idle": &"Crouch_Idle",
		&"crouch_walk": &"Crouch_Fwd",
		&"dodge": &"Roll",
		&"stop": &"Idle",
		&"interact": &"Interact",
		&"pickup": &"PickUp_Table",
		&"low_mantle": &"Interact",
		&"high_mantle": &"Jump_Land",
		&"hit_chest": &"Hit_Chest",
		&"hit_head": &"Hit_Head",
		&"death": &"Death01",
		&"punch_enter": &"Punch_Enter",
		&"punch_jab": &"Punch_Jab",
		&"punch_cross": &"Punch_Cross",
		&"sword_idle": &"Sword_Idle",
		&"sword_attack": &"Sword_Attack",
		&"pistol_idle": &"Pistol_Idle",
		&"pistol_aim": &"Pistol_Aim_Neutral",
		&"pistol_shoot": &"Pistol_Shoot",
		&"pistol_reload": &"Pistol_Reload",
		&"spell_enter": &"Spell_Simple_Enter",
		&"spell_idle": &"Spell_Simple_Idle",
		&"spell_shoot": &"Spell_Simple_Shoot",
		&"spell_exit": &"Spell_Simple_Exit",
		&"dance": &"Dance",
		&"push": &"Push",
		&"swim_idle": &"Swim_Idle",
		&"swim_fwd": &"Swim_Fwd",
		&"craft": &"Fixing_Kneeling",
		&"sit_enter": &"Sitting_Enter",
		&"sit_idle": &"Sitting_Idle",
		&"sit_exit": &"Sitting_Exit",
		&"talk": &"Idle_Talking",
		&"torch": &"Idle_Torch",
		&"drive": &"Driving",
	}


func get_pose_warping_modifiers() -> Dictionary:
	return {
		"stride": $Rig/Skeleton3D/StrideWarpingModifier,
		"orientation": $Rig/Skeleton3D/OrientationWarpingModifier,
		"slope": $Rig/Skeleton3D/SlopeWarpingModifier,
	}

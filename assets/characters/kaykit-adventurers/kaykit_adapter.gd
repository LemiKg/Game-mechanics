class_name KayKitAdapter
extends CharacterAdapter
## Adapter for KayKit character models.
##
## Merges animations from multiple Rig_Medium GLB files at _ready(),
## builds an AnimationNodeStateMachine, and remaps track paths to match
## this character's skeleton.


## The node name of the instanced character mesh (e.g., "Knight", "Barbarian").
@export var mesh_node_name: String = "Knight"

## Animation source GLB scenes to merge into a single library.
@export var animation_sources: Array[PackedScene] = []

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _animation_tree: AnimationTree = $AnimationTree

var _skeleton: Skeleton3D
var _skeleton_path: String = ""


## Animations that should loop continuously (movement, idles, holds).
const LOOPING_ANIMATIONS := [
	&"Idle_A", &"Idle_B", &"Walking_A", &"Walking_B", &"Walking_C",
	&"Running_A", &"Running_B", &"Crouching", &"Sneaking", &"Jump_Idle",
	&"Sit_Chair_Idle", &"Cheering", &"Holding_A", &"Holding_B", &"Holding_C",
	&"Melee_2H_Idle", &"Melee_Unarmed_Idle", &"Walking_Backwards",
]


const ANIMATION_MAP := {
	&"idle": &"Idle_A",
	&"walk": &"Walking_A",
	&"run": &"Running_A",
	&"jump": &"Jump_Start",
	&"jump_loop": &"Jump_Idle",
	&"land": &"Jump_Land",
	&"crouch_idle": &"Crouching",
	&"crouch_walk": &"Sneaking",
	&"dodge": &"Dodge_Forward",
	&"stop": &"Idle_A",
	&"interact": &"Interact",
	&"pickup": &"PickUp",
	&"low_mantle": &"Interact",
	&"high_mantle": &"Jump_Land",
	&"hit_chest": &"Hit_A",
	&"hit_head": &"Hit_B",
	&"death": &"Death_A",
	&"sword_idle": &"Melee_2H_Idle",
	&"sword_attack": &"Melee_1H_Attack_Slice_Horizontal",
	&"punch_enter": &"Melee_Unarmed_Idle",
	&"punch_jab": &"Melee_Unarmed_Attack_Punch_A",
	&"punch_cross": &"Melee_Unarmed_Attack_Kick",
	&"torch": &"Holding_A",
	&"sit_enter": &"Sit_Chair_Down",
	&"sit_idle": &"Sit_Chair_Idle",
	&"sit_exit": &"Sit_Chair_StandUp",
	&"dance": &"Cheering",
}


const TRANSITIONS := {
	"Start->Idle_A": { "xfade": 0.0, "advance_mode": 2 },
	"Idle_A->Walking_A": { "xfade": 0.1 },
	"Walking_A->Idle_A": { "xfade": 0.1 },
	"Walking_A->Running_A": { "xfade": 0.1 },
	"Running_A->Walking_A": { "xfade": 0.1 },
	"Running_A->Idle_A": { "xfade": 0.1 },
	"Idle_A->Running_A": { "xfade": 0.1 },
	"Idle_A->Crouching": { "xfade": 0.15 },
	"Crouching->Idle_A": { "xfade": 0.15 },
	"Crouching->Sneaking": { "xfade": 0.1 },
	"Sneaking->Crouching": { "xfade": 0.1 },
	"Sneaking->Idle_A": { "xfade": 0.15 },
	"Crouching->Walking_A": { "xfade": 0.15 },
	"Idle_A->Jump_Start": { "xfade": 0.05 },
	"Walking_A->Jump_Start": { "xfade": 0.05 },
	"Running_A->Jump_Start": { "xfade": 0.05 },
	"Crouching->Jump_Start": { "xfade": 0.1 },
	"Sneaking->Jump_Start": { "xfade": 0.1 },
	"Jump_Start->Jump_Idle": { "xfade": 0.05 },
	"Jump_Idle->Jump_Land": { "xfade": 0.05 },
	"Jump_Land->Idle_A": { "xfade": 0.1 },
	"Jump_Land->Walking_A": { "xfade": 0.1 },
	"Jump_Land->Running_A": { "xfade": 0.1 },
	"Idle_A->Dodge_Forward": { "xfade": 0.05, "switch_mode": 1 },
	"Walking_A->Dodge_Forward": { "xfade": 0.05, "switch_mode": 1 },
	"Running_A->Dodge_Forward": { "xfade": 0.05, "switch_mode": 1 },
	"Dodge_Forward->Idle_A": { "xfade": 0.35 },
	"Dodge_Forward->Walking_A": { "xfade": 0.35 },
	"Dodge_Forward->Running_A": { "xfade": 0.35 },
	"Idle_A->Sit_Chair_Down": { "xfade": 0.2 },
	"Sit_Chair_Down->Sit_Chair_Idle": { "xfade": 0.1 },
	"Sit_Chair_Idle->Sit_Chair_StandUp": { "xfade": 0.1 },
	"Sit_Chair_StandUp->Idle_A": { "xfade": 0.2 },
	"Idle_A->Cheering": { "xfade": 0.2 },
	"Cheering->Idle_A": { "xfade": 0.2 },
	"Idle_A->Interact": { "xfade": 0.15 },
	"Interact->Idle_A": { "xfade": 0.15 },
	"Idle_A->PickUp": { "xfade": 0.15 },
	"PickUp->Idle_A": { "xfade": 0.15 },
	"Idle_A->Hit_A": { "xfade": 0.05, "switch_mode": 1 },
	"Walking_A->Hit_A": { "xfade": 0.05, "switch_mode": 1 },
	"Running_A->Hit_A": { "xfade": 0.05, "switch_mode": 1 },
	"Idle_A->Hit_B": { "xfade": 0.05, "switch_mode": 1 },
	"Walking_A->Hit_B": { "xfade": 0.05, "switch_mode": 1 },
	"Running_A->Hit_B": { "xfade": 0.05, "switch_mode": 1 },
	"Hit_A->Idle_A": { "xfade": 0.1 },
	"Hit_B->Idle_A": { "xfade": 0.1 },
	"Idle_A->Death_A": { "xfade": 0.05, "switch_mode": 1 },
	"Walking_A->Death_A": { "xfade": 0.05, "switch_mode": 1 },
	"Running_A->Death_A": { "xfade": 0.05, "switch_mode": 1 },
	"Idle_A->Melee_2H_Idle": { "xfade": 0.1 },
	"Melee_2H_Idle->Idle_A": { "xfade": 0.1 },
	"Melee_2H_Idle->Melee_1H_Attack_Slice_Horizontal": { "xfade": 0.05 },
	"Melee_1H_Attack_Slice_Horizontal->Idle_A": { "xfade": 0.15 },
	"Melee_1H_Attack_Slice_Horizontal->Melee_2H_Idle": { "xfade": 0.1 },
	"Idle_A->Melee_Unarmed_Idle": { "xfade": 0.1 },
	"Melee_Unarmed_Idle->Idle_A": { "xfade": 0.1 },
	"Melee_Unarmed_Idle->Melee_Unarmed_Attack_Punch_A": { "xfade": 0.05 },
	"Melee_Unarmed_Attack_Punch_A->Melee_Unarmed_Attack_Kick": { "xfade": 0.05 },
	"Melee_Unarmed_Attack_Kick->Idle_A": { "xfade": 0.15 },
	"Melee_Unarmed_Attack_Punch_A->Idle_A": { "xfade": 0.15 },
	"Idle_A->Holding_A": { "xfade": 0.15 },
	"Holding_A->Idle_A": { "xfade": 0.15 },
	"Holding_A->Walking_A": { "xfade": 0.1 },
	"Walking_A->Holding_A": { "xfade": 0.1 },
}


func _ready() -> void:
	_resolve_skeleton()
	_merge_animations()
	_build_state_machine()
	_animation_tree.active = true


# --- CharacterAdapter interface ---

func get_character_name() -> String:
	return mesh_node_name


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_animation_tree() -> AnimationTree:
	return _animation_tree


func get_animation_map() -> Dictionary:
	return ANIMATION_MAP


func get_pose_warping_modifiers() -> Dictionary:
	return {}


# --- Internal setup ---

func _resolve_skeleton() -> void:
	var mesh_node := get_node_or_null(NodePath(mesh_node_name))
	if not mesh_node:
		push_error("KayKitAdapter: Mesh node '%s' not found" % mesh_node_name)
		return
	_skeleton = _find_node_of_type(mesh_node, "Skeleton3D") as Skeleton3D
	if _skeleton:
		# Path must be relative to AnimationPlayer's root node, not the AnimationPlayer itself
		var anim_root := _animation_player.get_node(_animation_player.root_node)
		_skeleton_path = String(anim_root.get_path_to(_skeleton))


func _merge_animations() -> void:
	if not _animation_player:
		push_error("KayKitAdapter: No AnimationPlayer found")
		return

	var default_lib: AnimationLibrary
	if _animation_player.has_animation_library(&""):
		default_lib = _animation_player.get_animation_library(&"")
	else:
		default_lib = AnimationLibrary.new()
		_animation_player.add_animation_library(&"", default_lib)

	for source_scene in animation_sources:
		if not source_scene:
			continue
		var instance := source_scene.instantiate()
		var source_player := _find_node_of_type(instance, "AnimationPlayer") as AnimationPlayer
		if not source_player:
			instance.free()
			continue

		for lib_name in source_player.get_animation_library_list():
			var lib := source_player.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				if not default_lib.has_animation(anim_name):
					var remapped := _remap_tracks(lib.get_animation(anim_name))
					default_lib.add_animation(anim_name, remapped)

		instance.free()

	# Set loop mode on animations that should loop
	for anim_name in LOOPING_ANIMATIONS:
		if default_lib.has_animation(anim_name):
			default_lib.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func _build_state_machine() -> void:
	var sm := AnimationNodeStateMachine.new()

	# Collect unique animation names
	var anim_names := {}
	for key in TRANSITIONS:
		for part in (key as String).split("->"):
			if part != "Start":
				anim_names[part] = true

	# Add animation nodes
	for anim_name in anim_names:
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = StringName(anim_name)
		sm.add_node(StringName(anim_name), anim_node)

	# Add transitions
	for key in TRANSITIONS:
		var parts := (key as String).split("->")
		var from := StringName(parts[0])
		var to := StringName(parts[1])
		var config: Dictionary = TRANSITIONS[key]

		var trans := AnimationNodeStateMachineTransition.new()

		if from == &"Start":
			if config.has("advance_mode"):
				trans.advance_mode = config["advance_mode"]
			sm.add_transition(&"Start", to, trans)
			continue

		trans.xfade_time = config.get("xfade", 0.1)
		if config.has("switch_mode"):
			trans.switch_mode = config["switch_mode"]
		sm.add_transition(from, to, trans)

	_animation_tree.tree_root = sm
	_animation_tree.anim_player = _animation_tree.get_path_to(_animation_player)


func _remap_tracks(source_anim: Animation) -> Animation:
	if _skeleton_path.is_empty():
		return source_anim
	var anim := source_anim.duplicate()
	for i in anim.get_track_count():
		var path_str := String(anim.track_get_path(i))
		var skel_idx := path_str.find("Skeleton3D")
		if skel_idx == -1:
			continue
		var new_path := _skeleton_path + path_str.substr(skel_idx + len("Skeleton3D"))
		anim.track_set_path(i, NodePath(new_path))
	return anim


func _find_node_of_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child in node.get_children():
		var result := _find_node_of_type(child, type_name)
		if result:
			return result
	return null

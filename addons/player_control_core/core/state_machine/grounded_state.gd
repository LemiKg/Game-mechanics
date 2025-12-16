class_name GroundedState
extends PlayerState
## Active when the player is on the floor.
##
## Handles walking, sprinting, crouching, and jumping.
## Transitions to Airborne when jump or falling.


## Whether currently sprinting.
var is_sprinting: bool = false

## Whether currently crouching.
var is_crouching: bool = false


## Track last animation to avoid redundant requests.
var _current_animation: StringName = &""

## Grace period after landing to ignore brief "not grounded" moments.
var _landing_grace_timer: float = 0.0

## Whether we just landed (skip immediate animation update).
var _just_landed: bool = false


func enter() -> void:
	print("[GroundedState] Frame %d: ENTER" % Engine.get_process_frames())
	is_sprinting = false
	is_crouching = false
	_current_animation = &""
	if motor:
		motor.set_walk_speed()
	
	# Check if we're landing (land animation was requested before entering)
	# Give a grace period to let Jump_Land animation play
	# Jump_Start → Jump → Jump_Land takes time in the AnimationTree
	_landing_grace_timer = 0.5 # 500ms to let landing animation play
	_just_landed = true
	print("[GroundedState] Frame %d: starting landing grace period (0.5s)" % Engine.get_process_frames())


func exit() -> void:
	is_sprinting = false
	is_crouching = false


func physics_update(delta: float) -> void:
	if not motor or not input_router:
		return
	
	# Countdown landing grace period
	if _landing_grace_timer > 0:
		_landing_grace_timer -= delta
		
		# Allow early cancel if player starts moving significantly
		var has_movement := input_router.movement_intent.length() > 0.3
		if has_movement and _landing_grace_timer < 0.35:
			# Player wants to move - end grace early (after minimum 150ms)
			print("[GroundedState] Frame %d: landing grace cancelled by movement" % Engine.get_process_frames())
			_landing_grace_timer = 0
		
		if _landing_grace_timer <= 0:
			print("[GroundedState] Frame %d: landing grace period ended" % Engine.get_process_frames())
			_just_landed = false
			# Now update animation based on current movement
			_update_animation()
	
	# Check if we fell off a ledge (skip during landing grace period)
	if not motor.is_grounded and _landing_grace_timer <= 0:
		print("[GroundedState] Frame %d: fell off ledge, transitioning to airborne" % Engine.get_process_frames())
		transition_to(&"airborne")
		return
	
	# Handle sprint/crouch modifiers
	_update_movement_modifiers()
	
	# Handle jump (consume the buffered input)
	if input_router.consume_jump():
		print("[GroundedState] Frame %d: jump consumed, trying jump" % Engine.get_process_frames())
		if motor.try_jump():
			print("[GroundedState] Frame %d: jump succeeded, requesting 'jump' anim and transitioning" % Engine.get_process_frames())
			request_animation(&"jump", 0.1)
			transition_to(&"airborne")
			return
	
	# Update animation based on movement (skip during landing grace)
	if not _just_landed:
		_update_animation()


func _update_movement_modifiers() -> void:
	if not input_router or not motor:
		return
	
	# Crouch takes priority (can't sprint while crouching)
	is_crouching = input_router.crouch_held
	is_sprinting = input_router.sprint_held and not is_crouching
	
	# Update motor speed based on modifiers
	if is_crouching:
		motor.set_crouch_speed()
	elif is_sprinting:
		motor.set_sprint_speed()
	else:
		motor.set_walk_speed()


func _update_animation() -> void:
	if not input_router:
		return
	
	var new_animation: StringName
	var has_movement := input_router.movement_intent.length() > 0.1
	
	if is_crouching:
		new_animation = &"crouch_idle" if not has_movement else &"crouch_walk"
	elif is_sprinting and has_movement:
		new_animation = &"run"
	elif has_movement:
		new_animation = &"walk"
	else:
		new_animation = &"idle"
	
	# Only request if animation changed
	if new_animation != _current_animation:
		print("[GroundedState] Frame %d: animation changed '%s' -> '%s'" % [
			Engine.get_process_frames(), _current_animation, new_animation])
		_current_animation = new_animation
		request_animation(new_animation)

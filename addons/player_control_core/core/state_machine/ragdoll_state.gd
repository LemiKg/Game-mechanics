class_name RagdollState
extends PlayerState
## Ragdoll physics state using Skeleton3D physical bone simulation.
##
## On enter: enables physical bone simulation, disables motor and collision.
## After recovery_time: plays get-up animation and transitions to grounded.
## Triggered externally via state_machine.transition_to(&"ragdoll").


@export_group("Settings")
## Time in ragdoll before recovery begins (seconds).
@export_range(0.5, 10.0, 0.1) var recovery_time: float = 2.0

## Animation to play when getting up from ragdoll.
@export var get_up_animation: StringName = &"idle"

@export_group("References")
## The Skeleton3D node for physical bone simulation.
@export var skeleton: Skeleton3D

## The collision shape to disable during ragdoll.
@export var collision_shape: CollisionShape3D


## Timer tracking time in ragdoll.
var _ragdoll_timer: float = 0.0

## Whether recovery has started (get-up animation playing).
var _recovering: bool = false

## Recovery animation duration.
var _recovery_duration: float = 0.5

## Debug logger.
var _logger := DebugLogger.new("[RagdollState]")


func enter() -> void:
	_logger.debug("ENTER")
	_ragdoll_timer = 0.0
	_recovering = false

	# Disable motor
	if motor:
		motor.enabled = false

	# Disable player collision shape (ragdoll bones handle collision)
	if collision_shape:
		collision_shape.disabled = true

	# Start physical bone simulation
	if skeleton:
		skeleton.physical_bones_start_simulation()
	else:
		push_warning("RagdollState: No skeleton assigned, cannot simulate ragdoll")


func exit() -> void:
	_logger.debug("EXIT")

	# Stop physical bone simulation
	if skeleton:
		skeleton.physical_bones_stop_simulation()

	# Re-enable collision
	if collision_shape:
		collision_shape.disabled = false

	# Re-enable motor
	if motor:
		motor.enabled = true

	# Snap body to skeleton root position (prevent teleporting back to pre-ragdoll position)
	if skeleton and controller and controller.body:
		var skeleton_global_pos := skeleton.global_position
		skeleton_global_pos.y = controller.body.global_position.y  # Keep Y from physics
		controller.body.global_position = skeleton_global_pos

	# Zero velocity
	if controller and controller.body:
		if controller.body.has_method("move_and_slide"):
			controller.body.velocity = Vector3.ZERO
		elif "linear_velocity" in controller.body:
			controller.body.linear_velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
	_ragdoll_timer += delta

	if _recovering:
		# Wait for get-up animation to finish
		_recovery_duration -= delta
		if _recovery_duration <= 0:
			transition_to(&"grounded")
		return

	# Check if recovery time reached
	if _ragdoll_timer >= recovery_time:
		_start_recovery()


func _start_recovery() -> void:
	_recovering = true
	_recovery_duration = 0.5

	# Stop ragdoll physics before playing get-up animation
	if skeleton:
		skeleton.physical_bones_stop_simulation()

	# Snap body to where the ragdoll ended up
	if skeleton and controller and controller.body:
		var final_pos := skeleton.global_position
		final_pos.y = controller.body.global_position.y
		controller.body.global_position = final_pos

	# Re-enable collision for the get-up
	if collision_shape:
		collision_shape.disabled = false

	request_animation(get_up_animation, 0.2)
	_logger.debug("starting recovery from ragdoll")

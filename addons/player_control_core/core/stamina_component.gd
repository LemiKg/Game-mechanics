class_name StaminaComponent
extends Node
## Manages stamina for sprint, dodge, and other actions.
##
## Attach to the player node. Connect to signals to update UI.
## Stamina regenerates automatically after a delay following the last drain.


## Emitted when stamina changes.
signal stamina_changed(current: float, maximum: float)

## Emitted when stamina is fully depleted.
signal stamina_depleted()

## Emitted when stamina is fully restored.
signal stamina_full()


@export_group("Stamina")
## Maximum stamina.
@export_range(1.0, 500.0, 1.0) var max_stamina: float = 100.0

## Stamina regeneration rate (per second).
@export_range(0.0, 100.0, 0.5) var regen_rate: float = 15.0

## Delay before regeneration starts after last drain (seconds).
@export_range(0.0, 5.0, 0.1) var regen_delay: float = 1.0

@export_group("Costs")
## Stamina drained per second while sprinting.
@export_range(0.0, 50.0, 0.5) var sprint_drain: float = 10.0

## Flat stamina cost for a dodge/roll.
@export_range(0.0, 100.0, 1.0) var dodge_cost: float = 25.0


## Current stamina value.
var current_stamina: float = 100.0

## Time since last stamina drain (for regen delay).
var _time_since_drain: float = 999.0

## Whether stamina was depleted (for hysteresis — don't allow sprint until partial regen).
var _is_depleted: bool = false

## Minimum stamina to exit depleted state (prevents flickering).
var _depletion_recovery_threshold: float = 20.0


func _ready() -> void:
	current_stamina = max_stamina


func _physics_process(delta: float) -> void:
	_time_since_drain += delta

	# Regenerate stamina after delay
	if _time_since_drain >= regen_delay and current_stamina < max_stamina:
		current_stamina = minf(current_stamina + regen_rate * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)

		if current_stamina >= max_stamina:
			stamina_full.emit()

		# Clear depleted state once we've recovered enough
		if _is_depleted and current_stamina >= _depletion_recovery_threshold:
			_is_depleted = false


## Drain stamina by a flat amount. Returns true if there was enough stamina.
func try_consume(amount: float) -> bool:
	if current_stamina < amount:
		return false
	current_stamina -= amount
	_time_since_drain = 0.0
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0:
		current_stamina = 0.0
		_is_depleted = true
		stamina_depleted.emit()
	return true


## Drain stamina continuously (call each physics frame). Returns true if stamina remains.
func drain(amount_per_second: float, delta: float) -> bool:
	current_stamina -= amount_per_second * delta
	_time_since_drain = 0.0
	if current_stamina <= 0.0:
		current_stamina = 0.0
		_is_depleted = true
		stamina_changed.emit(current_stamina, max_stamina)
		stamina_depleted.emit()
		return false
	stamina_changed.emit(current_stamina, max_stamina)
	return true


## Check if a dodge can be afforded.
func can_dodge() -> bool:
	return current_stamina >= dodge_cost and not _is_depleted


## Check if sprinting is allowed (has stamina and not in depleted recovery).
func can_sprint() -> bool:
	return current_stamina > 0.0 and not _is_depleted


## Reset stamina to full.
func reset() -> void:
	current_stamina = max_stamina
	_is_depleted = false
	_time_since_drain = 999.0
	stamina_changed.emit(current_stamina, max_stamina)

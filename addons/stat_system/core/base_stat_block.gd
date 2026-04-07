@tool
extends Resource
class_name BaseStatBlock
## Abstract base class for stat containers.
## Mirrors BaseInventory's role in the inventory_system addon.
## Subclass to create variants (e.g. a future DerivedStatBlock).

## Emitted whenever the final computed value of a stat changes.
signal stat_changed(id: StringName, old_value: float, new_value: float)

## Emitted when a resource stat's `current` reaches 0.
signal resource_depleted(id: StringName)

## Emitted when a resource stat's `current` becomes equal to its computed max
## (and was previously below max).
signal resource_filled(id: StringName)

## Emitted after a modifier is added.
signal modifier_added(modifier: StatModifier)

## Emitted after a modifier is removed. `reason` is a StatModifier.RemoveReason.
signal modifier_removed(modifier: StatModifier, reason: int)

## @virtual Final computed value for a flat stat, or the computed max for
## a resource stat. Returns 0.0 and pushes a warning for unknown ids.
func get_value(_id: StringName) -> float:
	push_error("BaseStatBlock.get_value() is abstract")
	return 0.0

## @virtual Convenience: same as get_value(). Provided so call sites that
## want to read "the maximum" of a resource stat read better.
func get_max(_id: StringName) -> float:
	push_error("BaseStatBlock.get_max() is abstract")
	return 0.0

## @virtual For resource stats, returns the persisted current value.
## For flat stats, returns the same as get_value().
func get_current(_id: StringName) -> float:
	push_error("BaseStatBlock.get_current() is abstract")
	return 0.0

## @virtual Adjust a resource stat's current by `delta`. Clamps to [0, max].
## Emits stat_changed and resource_depleted/resource_filled as appropriate.
func modify_resource(_id: StringName, _delta: float) -> void:
	push_error("BaseStatBlock.modify_resource() is abstract")

## @virtual Set a resource stat's current directly. Clamps to [0, max].
func set_current(_id: StringName, _value: float) -> void:
	push_error("BaseStatBlock.set_current() is abstract")

## @virtual Add a modifier. Recomputes the affected stat and emits signals.
func add_modifier(_modifier: StatModifier) -> void:
	push_error("BaseStatBlock.add_modifier() is abstract")

## @virtual Remove one specific modifier instance.
func remove_modifier(_modifier: StatModifier) -> void:
	push_error("BaseStatBlock.remove_modifier() is abstract")

## @virtual Remove all modifiers tagged with the given source_id.
## Used by EquipmentComponent on unequip.
func remove_modifiers_by_source(_source_id: StringName) -> void:
	push_error("BaseStatBlock.remove_modifiers_by_source() is abstract")

## @virtual Read-only snapshot of all active modifiers.
func get_active_modifiers() -> Array[StatModifier]:
	push_error("BaseStatBlock.get_active_modifiers() is abstract")
	return []

## @virtual Apply per-frame updates: regen for resource stats, and countdown
## for timed modifiers (removing them with reason EXPIRED on hit zero).
## Called by StatComponent._process.
func tick(_delta: float) -> void:
	push_error("BaseStatBlock.tick() is abstract")

## @virtual Save the persistent parts of the block to a Dictionary.
func serialize() -> Dictionary:
	push_error("BaseStatBlock.serialize() is abstract")
	return {}

## @virtual Restore from a Dictionary produced by serialize().
func deserialize(_data: Dictionary) -> void:
	push_error("BaseStatBlock.deserialize() is abstract")

extends RefCounted
class_name StatReader
## Read-only view of a StatBlock for UI consumers.
## Exposes only reads + signal forwarding. UI bars and buff lists should
## depend on this, not on StatComponent or StatBlock directly.
##
## Construct via StatComponent.get_reader().

signal stat_changed(id: StringName, old_value: float, new_value: float)
signal resource_depleted(id: StringName)
signal resource_filled(id: StringName)
signal modifier_added(modifier: StatModifier)
signal modifier_removed(modifier: StatModifier, reason: int)

var _block: StatBlock

func _init(block: StatBlock) -> void:
	_block = block
	if _block:
		_block.stat_changed.connect(_forward_stat_changed)
		_block.resource_depleted.connect(_forward_depleted)
		_block.resource_filled.connect(_forward_filled)
		_block.modifier_added.connect(_forward_modifier_added)
		_block.modifier_removed.connect(_forward_modifier_removed)

func get_value(id: StringName) -> float:
	return _block.get_value(id) if _block else 0.0

func get_max(id: StringName) -> float:
	return _block.get_max(id) if _block else 0.0

func get_current(id: StringName) -> float:
	return _block.get_current(id) if _block else 0.0

func get_active_modifiers() -> Array[StatModifier]:
	return _block.get_active_modifiers() if _block else []

func _forward_stat_changed(id: StringName, old_value: float, new_value: float) -> void:
	stat_changed.emit(id, old_value, new_value)

func _forward_depleted(id: StringName) -> void:
	resource_depleted.emit(id)

func _forward_filled(id: StringName) -> void:
	resource_filled.emit(id)

func _forward_modifier_added(modifier: StatModifier) -> void:
	modifier_added.emit(modifier)

func _forward_modifier_removed(modifier: StatModifier, reason: int) -> void:
	modifier_removed.emit(modifier, reason)

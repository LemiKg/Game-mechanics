@tool
extends BaseStatBlock
class_name StatBlock
## Default StatBlock implementation: holds definitions, modifiers,
## current resource values, and a swappable formula. Built up over
## plan tasks 6–10.

@export var definitions: Array[StatDefinition] = []
@export var formula: StatFormula  # set in _init if null
@export var current_resources: Dictionary = {}  # StringName -> float

# Runtime, not exported. Modifiers are recomputed at load time by the
# systems that own them (e.g. EquipmentComponent on equip).
var _modifiers: Array[StatModifier] = []

# Cache of computed values, invalidated when modifiers change.
var _value_cache: Dictionary = {}  # StringName -> float

func _init() -> void:
	if formula == null:
		formula = AdditivePercentFormula.new()

## Look up a StatDefinition by id. Returns null if not found.
## Callers are responsible for issuing warnings.
func _find_definition(id: StringName) -> StatDefinition:
	for d in definitions:
		if d != null and d.id == id:
			return d
	return null

## Invalidate the cached value for one stat, forcing recomputation on next read.
## Called by add/remove modifier paths in Task 7+.
func _invalidate(id: StringName) -> void:
	_value_cache.erase(id)

func get_value(id: StringName) -> float:
	if _value_cache.has(id):
		return _value_cache[id]
	var def := _find_definition(id)
	if def == null:
		push_warning("StatBlock: unknown stat id '%s'" % id)
		return 0.0
	var value: float = formula.compute(def, _modifiers)
	_value_cache[id] = value
	return value

func get_max(id: StringName) -> float:
	# For both flat and resource stats, get_max returns the computed value.
	return get_value(id)

func get_current(id: StringName) -> float:
	var def := _find_definition(id)
	if def == null:
		push_warning("StatBlock: unknown stat id '%s'" % id)
		return 0.0
	if not def.is_resource:
		return get_value(id)
	# Resource stat: return persisted current. If never initialized, fall
	# back to the computed max so a freshly-authored block reads as full.
	if current_resources.has(id):
		return current_resources[id]
	return get_value(id)

# Stub implementations for the rest of the abstract surface — filled in
# by Tasks 7–10. Empty bodies are correct enough that the runtime doesn't
# crash if a consumer happens to call them mid-implementation.

func modify_resource(_id: StringName, _delta: float) -> void:
	pass

func set_current(_id: StringName, _value: float) -> void:
	pass

func add_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		push_warning("StatBlock.add_modifier: null modifier")
		return
	var def := _find_definition(modifier.stat_id)
	if def == null:
		push_warning("StatBlock.add_modifier: unknown stat id '%s'" % modifier.stat_id)
		return

	var old_value := get_value(modifier.stat_id)
	_modifiers.append(modifier)
	# Initialize timed-modifier remaining counter.
	modifier.remaining = modifier.duration
	_invalidate(modifier.stat_id)
	modifier_added.emit(modifier)

	var new_value := get_value(modifier.stat_id)
	if new_value != old_value:
		stat_changed.emit(modifier.stat_id, old_value, new_value)

func remove_modifier(modifier: StatModifier) -> void:
	_remove_modifier_with_reason(modifier, StatModifier.RemoveReason.MANUAL)

func remove_modifiers_by_source(source_id: StringName) -> void:
	# Iterate over a copy because we're mutating the list.
	for m in _modifiers.duplicate():
		if m != null and m.source_id == source_id:
			_remove_modifier_with_reason(m, StatModifier.RemoveReason.SOURCE_REMOVED)

func _remove_modifier_with_reason(modifier: StatModifier, reason: int) -> void:
	if modifier == null:
		return
	var idx := _modifiers.find(modifier)
	if idx < 0:
		return
	var stat_id: StringName = modifier.stat_id
	var old_value := get_value(stat_id)
	_modifiers.remove_at(idx)
	_invalidate(stat_id)
	modifier_removed.emit(modifier, reason)

	var new_value := get_value(stat_id)
	if new_value != old_value:
		stat_changed.emit(stat_id, old_value, new_value)

func get_active_modifiers() -> Array[StatModifier]:
	return _modifiers.duplicate()

func tick(_delta: float) -> void:
	pass

func serialize() -> Dictionary:
	return {}

func deserialize(_data: Dictionary) -> void:
	pass

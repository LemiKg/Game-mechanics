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

## Look up a StatDefinition by id. Returns null and warns if not found.
func _find_definition(id: StringName) -> StatDefinition:
	for d in definitions:
		if d != null and d.id == id:
			return d
	return null

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

func add_modifier(_modifier: StatModifier) -> void:
	pass

func remove_modifier(_modifier: StatModifier) -> void:
	pass

func remove_modifiers_by_source(_source_id: StringName) -> void:
	pass

func get_active_modifiers() -> Array[StatModifier]:
	return _modifiers.duplicate()

func tick(_delta: float) -> void:
	pass

func serialize() -> Dictionary:
	return {}

func deserialize(_data: Dictionary) -> void:
	pass

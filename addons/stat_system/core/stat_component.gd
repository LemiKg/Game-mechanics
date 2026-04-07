@tool
extends Node
class_name StatComponent
## Runtime owner of a StatBlock. Hosts the per-frame tick (regen + buff
## countdown) and forwards public stat operations + signals to the block.
##
## Consumers should usually call methods on this Node rather than poking
## stat_block directly. UI consumers should call get_reader() instead.

@export var stat_block: StatBlock

# Re-emitted from the wrapped StatBlock so scene-tree consumers can connect
# without reaching into the resource.
signal stat_changed(id: StringName, old_value: float, new_value: float)
signal resource_depleted(id: StringName)
signal resource_filled(id: StringName)
signal modifier_added(modifier: StatModifier)
signal modifier_removed(modifier: StatModifier, reason: int)

func _ready() -> void:
	if stat_block == null:
		push_warning("StatComponent: no stat_block assigned to '%s'" % name)
		return
	stat_block.stat_changed.connect(_on_stat_changed)
	stat_block.resource_depleted.connect(_on_resource_depleted)
	stat_block.resource_filled.connect(_on_resource_filled)
	stat_block.modifier_added.connect(_on_modifier_added)
	stat_block.modifier_removed.connect(_on_modifier_removed)

func _process(delta: float) -> void:
	if stat_block:
		stat_block.tick(delta)

# --- Read API ---

func get_value(id: StringName) -> float:
	return stat_block.get_value(id) if stat_block else 0.0

func get_max(id: StringName) -> float:
	return stat_block.get_max(id) if stat_block else 0.0

func get_current(id: StringName) -> float:
	return stat_block.get_current(id) if stat_block else 0.0

func get_active_modifiers() -> Array[StatModifier]:
	return stat_block.get_active_modifiers() if stat_block else []

func get_reader() -> StatReader:
	return StatReader.new(stat_block)

# --- Mutation API ---

func modify_resource(id: StringName, delta: float) -> void:
	if stat_block:
		stat_block.modify_resource(id, delta)

func set_current(id: StringName, value: float) -> void:
	if stat_block:
		stat_block.set_current(id, value)

func add_modifier(modifier: StatModifier) -> void:
	if stat_block:
		stat_block.add_modifier(modifier)

func remove_modifier(modifier: StatModifier) -> void:
	if stat_block:
		stat_block.remove_modifier(modifier)

func remove_modifiers_by_source(source_id: StringName) -> void:
	if stat_block:
		stat_block.remove_modifiers_by_source(source_id)

# --- Save/load ---

func serialize() -> Dictionary:
	return stat_block.serialize() if stat_block else {}

func deserialize(data: Dictionary) -> void:
	if stat_block:
		stat_block.deserialize(data)

# --- Signal forwarders ---

func _on_stat_changed(id: StringName, old_value: float, new_value: float) -> void:
	stat_changed.emit(id, old_value, new_value)

func _on_resource_depleted(id: StringName) -> void:
	resource_depleted.emit(id)

func _on_resource_filled(id: StringName) -> void:
	resource_filled.emit(id)

func _on_modifier_added(modifier: StatModifier) -> void:
	modifier_added.emit(modifier)

func _on_modifier_removed(modifier: StatModifier, reason: int) -> void:
	modifier_removed.emit(modifier, reason)

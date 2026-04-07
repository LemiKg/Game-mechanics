@tool
extends Node
class_name EquipmentComponent

signal equipment_changed(slot_name: String, item: Resource)
signal stats_changed()

# Dictionary mapping slot names to EquipmentItem
@export var equipment_slots: Dictionary = {}

# Define available slot names
@export var defined_slots: Array[String] = []

## Optional: when set, equipped items push their stat modifiers onto this
## StatComponent and unequipping removes them by source. Requires the
## stat_system addon to be enabled.
@export var stat_component: StatComponent


func _ready():
	for slot_name in defined_slots:
		if not equipment_slots.has(slot_name):
			equipment_slots[slot_name] = null


func equip(item: Resource, slot_name: String) -> bool:
	if not item:
		return unequip(slot_name)

	if not equipment_slots.has(slot_name):
		push_warning("EquipmentComponent: Slot '%s' does not exist. Defined slots: %s" % [slot_name, defined_slots])
		return false

	if item.slot_type_name != slot_name:
		return false

	# If something is already in this slot, unequip it first so its
	# modifiers are removed before the new ones are added.
	var existing = equipment_slots[slot_name]
	if existing != null:
		_remove_stat_modifiers_for(existing)

	equipment_slots[slot_name] = item
	_apply_stat_modifiers_for(item)
	equipment_changed.emit(slot_name, item)
	stats_changed.emit()
	return true


func unequip(slot_name: String) -> bool:
	if not equipment_slots.has(slot_name):
		push_warning("EquipmentComponent: Cannot unequip — slot '%s' does not exist" % slot_name)
		return false
	var existing = equipment_slots[slot_name]
	if existing != null:
		_remove_stat_modifiers_for(existing)
	equipment_slots[slot_name] = null
	equipment_changed.emit(slot_name, null)
	stats_changed.emit()
	return true


func get_item_in_slot(slot_name: String) -> Resource:
	return equipment_slots.get(slot_name, null)


## Push an item's stat modifiers onto the connected StatComponent.
## No-op if stat_component is null or the item doesn't implement the
## StatModifierProvider contract.
func _apply_stat_modifiers_for(item: Resource) -> void:
	if stat_component == null or item == null:
		return
	if not item.has_method("get_stat_modifiers"):
		return
	var mods: Array = item.get_stat_modifiers()
	for m in mods:
		if m == null:
			continue
		# Force the source_id to the item's id so removal-by-source works
		# even if the author forgot to set it on each modifier.
		var mod_copy: StatModifier = m.duplicate()
		mod_copy.source_id = StringName(item.id)
		stat_component.add_modifier(mod_copy)


func _remove_stat_modifiers_for(item: Resource) -> void:
	if stat_component == null or item == null:
		return
	stat_component.remove_modifiers_by_source(StringName(item.id))


## Serialize equipment state for save/load.
func serialize() -> Dictionary:
	var data := {}
	for slot_name in equipment_slots:
		var item = equipment_slots[slot_name]
		if item and item is EquipmentItem:
			data[slot_name] = {"id": item.id}
		else:
			data[slot_name] = null
	return data


## Deserialize equipment from saved data.
func deserialize(data: Dictionary) -> void:
	var item_db: Node = null
	var tree := Engine.get_main_loop()
	if tree and tree is SceneTree:
		item_db = tree.root.get_node_or_null("/root/ItemDatabase")
	for slot_name in data:
		var entry = data[slot_name]
		if entry == null:
			equipment_slots[slot_name] = null
		else:
			var item_id: String = entry.get("id", "")
			var item = item_db.get_item(item_id) if item_db else null
			if item:
				equipment_slots[slot_name] = item
				_apply_stat_modifiers_for(item)
			else:
				push_warning("EquipmentComponent.deserialize: item '%s' not found" % item_id)
				equipment_slots[slot_name] = null
	stats_changed.emit()

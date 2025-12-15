@tool
extends Node
class_name EquipmentComponent

signal equipment_changed(slot_name: String, item: Resource)

# Dictionary mapping slot names to EquipmentItem
@export var equipment_slots: Dictionary = {}

# Define available slot names (e.g., ["Head", "Body", "Weapon"])
@export var defined_slots: Array[String] = []

func _ready():
	# Initialize slots
	for slot_name in defined_slots:
		if not equipment_slots.has(slot_name):
			equipment_slots[slot_name] = null

func equip(item: Resource, slot_name: String) -> bool:
	if not item:
		return unequip(slot_name)
		
	# Validate slot type
	if item.slot_type_name != slot_name:
		return false
		
	equipment_slots[slot_name] = item
	emit_signal("equipment_changed", slot_name, item)
	return true

func unequip(slot_name: String) -> bool:
	if equipment_slots.has(slot_name):
		equipment_slots[slot_name] = null
		emit_signal("equipment_changed", slot_name, null)
		return true
	return false

func get_item_in_slot(slot_name: String) -> Resource:
	return equipment_slots.get(slot_name, null)

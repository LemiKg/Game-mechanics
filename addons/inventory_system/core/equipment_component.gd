@tool
extends Node
class_name EquipmentComponent

signal equipment_changed(slot_name: String, item: Resource)
signal stats_changed()

# Dictionary mapping slot names to EquipmentItem
@export var equipment_slots: Dictionary = {}

# Define available slot names
@export var defined_slots: Array[String] = []


func _ready():
	for slot_name in defined_slots:
		if not equipment_slots.has(slot_name):
			equipment_slots[slot_name] = null


func equip(item: Resource, slot_name: String) -> bool:
	if not item:
		return unequip(slot_name)

	if item.slot_type_name != slot_name:
		return false

	equipment_slots[slot_name] = item
	equipment_changed.emit(slot_name, item)
	stats_changed.emit()
	return true


func unequip(slot_name: String) -> bool:
	if equipment_slots.has(slot_name):
		equipment_slots[slot_name] = null
		equipment_changed.emit(slot_name, null)
		stats_changed.emit()
		return true
	return false


func get_item_in_slot(slot_name: String) -> Resource:
	return equipment_slots.get(slot_name, null)


## Get the total value of a stat across all equipped items.
## Checks defense, damage, and the stats dictionary.
func get_total_stat(stat_name: String) -> float:
	var total := 0.0
	for slot_name in equipment_slots:
		var item = equipment_slots[slot_name]
		if item and item is EquipmentItem:
			if stat_name == "defense":
				total += item.defense
			elif stat_name == "damage":
				total += item.damage
			if item.stats.has(stat_name):
				total += item.stats[stat_name]
	return total


## Get all aggregated stats as a Dictionary.
func get_all_stats() -> Dictionary:
	var stats := {}
	for slot_name in equipment_slots:
		var item = equipment_slots[slot_name]
		if item and item is EquipmentItem:
			if item.defense > 0:
				stats["defense"] = stats.get("defense", 0.0) + item.defense
			if item.damage > 0:
				stats["damage"] = stats.get("damage", 0.0) + item.damage
			for key in item.stats:
				stats[key] = stats.get(key, 0.0) + item.stats[key]
	return stats


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
			else:
				push_warning("EquipmentComponent.deserialize: item '%s' not found" % item_id)
				equipment_slots[slot_name] = null
	stats_changed.emit()

extends Node
class_name InventoryInteractionHandler
## Handles all inventory interactions: item swaps, equipping, unequipping.
## This separates business logic from UI concerns (Single Responsibility Principle).
## 
## Usage: Add as a child node and connect slot signals to the appropriate handlers.

signal interaction_completed

@export var inventory_component: InventoryComponent
@export var equipment_component: EquipmentComponent
## Optional: Reference to the player/user node for item.use() calls
@export var item_user: Node

## Handle item drop from one inventory slot to another (swap or move)
func handle_inventory_drop(data: Dictionary, target_inventory: Inventory, target_index: int) -> void:
	if not inventory_component:
		push_warning("InventoryInteractionHandler: No inventory_component set")
		return
	
	var data_type = data.get("type", "")
	
	match data_type:
		"inventory_item":
			_handle_inventory_to_inventory(data, target_inventory, target_index)
		"equipment_item":
			_handle_equipment_to_inventory(data, target_inventory, target_index)
		_:
			push_warning("InventoryInteractionHandler: Unknown drop type: %s" % data_type)
	
	interaction_completed.emit()

## Handle equip request from inventory or equipment slot
func handle_equip_request(data: Dictionary, target_slot_name: String) -> void:
	if not equipment_component or not inventory_component:
		push_warning("InventoryInteractionHandler: Missing component references")
		return
	
	var data_type = data.get("type", "")
	
	match data_type:
		"inventory_item":
			_handle_inventory_to_equipment(data, target_slot_name)
		"equipment_item":
			_handle_equipment_to_equipment(data, target_slot_name)
		_:
			push_warning("InventoryInteractionHandler: Unknown equip type: %s" % data_type)
	
	interaction_completed.emit()

## Handle unequip request to a specific inventory slot
func handle_unequip_request(slot_name: String, target_inventory: Inventory, target_index: int) -> void:
	if not equipment_component:
		push_warning("InventoryInteractionHandler: No equipment_component set")
		return
	
	var item = equipment_component.get_item_in_slot(slot_name)
	if not item:
		return
	
	if not target_inventory.accepts_item(item):
		return
	
	var target_slot = target_inventory.slots[target_index]
	
	if target_slot.is_empty():
		if equipment_component.unequip(slot_name):
			target_inventory.set_item(target_index, item, 1)
	else:
		# Try to swap: put target item into equipment slot
		var target_item = target_slot.item
		if target_item and target_item.is_equippable() and target_item.slot_type_name == slot_name:
			if equipment_component.equip(target_item, slot_name):
				target_inventory.set_item(target_index, item, 1)
	
	interaction_completed.emit()

## Handle double-click activation: use consumables or equip equipment
func handle_item_activation(item: InventoryItem, source_inventory: Inventory, source_index: int) -> void:
	if not item:
		return
	
	# Handle consumables - use polymorphic method
	if item.can_use():
		item.use(item_user)
		if inventory_component:
			inventory_component.remove_item(source_inventory, source_index, 1)
		interaction_completed.emit()
		return
	
	# Handle equippables - equip and swap with currently equipped item
	if item.is_equippable() and equipment_component:
		var equip_item := item as EquipmentItem
		if equip_item:
			var slot_name: String = equip_item.slot_type_name
			var current_equipped = equipment_component.get_item_in_slot(slot_name)
			
			if equipment_component.equip(equip_item, slot_name):
				# Swap: put previously equipped item in source slot, or clear it
				if current_equipped:
					source_inventory.set_item(source_index, current_equipped, 1)
				else:
					source_inventory.set_item(source_index, null, 0)
			interaction_completed.emit()

# --- Private Implementation Methods ---

func _handle_inventory_to_inventory(data: Dictionary, target_inventory: Inventory, target_index: int) -> void:
	var source_inventory: Inventory = data["inventory"]
	var source_index: int = data["index"]
	
	inventory_component.swap_items(source_inventory, source_index, target_inventory, target_index)

func _handle_equipment_to_inventory(data: Dictionary, target_inventory: Inventory, target_index: int) -> void:
	var slot_name: String = data["slot_name"]
	var item: Resource = data["item"]
	
	if not target_inventory.accepts_item(item):
		return
	
	var target_slot = target_inventory.slots[target_index]
	
	if target_slot.is_empty():
		if equipment_component.unequip(slot_name):
			target_inventory.set_item(target_index, item, 1)
	else:
		# Try to swap with inventory item
		var target_item = target_slot.item
		if target_item and target_item.is_equippable() and target_item.slot_type_name == slot_name:
			if equipment_component.equip(target_item, slot_name):
				target_inventory.set_item(target_index, item, 1)

func _handle_inventory_to_equipment(data: Dictionary, target_slot_name: String) -> void:
	var source_inventory: Inventory = data["inventory"]
	var source_index: int = data["index"]
	var item: Resource = data["item"]
	
	if not item.is_equippable():
		return
	
	if item.slot_type_name != target_slot_name:
		return
	
	var current_equipped = equipment_component.get_item_in_slot(target_slot_name)
	
	if equipment_component.equip(item, target_slot_name):
		# Use proper API instead of direct slot manipulation
		if current_equipped:
			source_inventory.set_item(source_index, current_equipped, 1)
		else:
			source_inventory.set_item(source_index, null, 0)

func _handle_equipment_to_equipment(data: Dictionary, target_slot_name: String) -> void:
	var source_slot_name: String = data["slot_name"]
	var item: Resource = data["item"]
	
	if not item.is_equippable():
		return
	
	if item.slot_type_name != target_slot_name:
		return
	
	var target_item = equipment_component.get_item_in_slot(target_slot_name)
	
	# Swap equipment slots
	equipment_component.unequip(source_slot_name)
	equipment_component.equip(item, target_slot_name)
	
	if target_item and target_item.is_equippable():
		equipment_component.equip(target_item, source_slot_name)

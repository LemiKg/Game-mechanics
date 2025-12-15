@tool
extends Node
class_name InventoryComponent

signal inventory_changed

## The Main Inventory resource
@export var main_inventory: Inventory
## The Hotbar Inventory resource
@export var hotbar_inventory: Inventory

func _ready():
	if not main_inventory:
		var InventoryScript = preload("inventory.gd")
		main_inventory = InventoryScript.new()
		
	if not hotbar_inventory:
		var InventoryScript = preload("inventory.gd")
		hotbar_inventory = InventoryScript.new()
		hotbar_inventory.size = 6 # Default size for hotbar
	
	# Connect to internal signal to relay it
	if not main_inventory.inventory_updated.is_connected(_on_inventory_updated):
		main_inventory.inventory_updated.connect(_on_inventory_updated)
		
	if not hotbar_inventory.inventory_updated.is_connected(_on_inventory_updated):
		hotbar_inventory.inventory_updated.connect(_on_inventory_updated)

func _on_inventory_updated():
	emit_signal("inventory_changed")

func add_item(item: Resource, amount: int = 1) -> int:
	var remaining = amount
	
	# Try hotbar first if accepted
	if hotbar_inventory.accepts_item(item):
		remaining = hotbar_inventory.add_item(item, remaining)
		if remaining == 0:
			return 0
			
	# Then main inventory
	if main_inventory.accepts_item(item):
		return main_inventory.add_item(item, remaining)
		
	return remaining

func remove_item(inventory: Inventory, index: int, amount: int):
	inventory.remove_item_at_index(index, amount)

func swap_items(from_inventory: Inventory, from_index: int, to_inventory: Inventory, to_index: int) -> bool:
	var from_slot = from_inventory.slots[from_index]
	var to_slot = to_inventory.slots[to_index]
	
	# Check if target inventory accepts the item from source
	if not from_slot.is_empty():
		if not to_inventory.accepts_item(from_slot.item):
			return false
			
	# Check if source inventory accepts the item from target (if any)
	if not to_slot.is_empty():
		if not from_inventory.accepts_item(to_slot.item):
			return false
	
	# Perform swap
	var temp_item = from_slot.item
	var temp_amount = from_slot.amount
	
	from_slot.item = to_slot.item
	from_slot.amount = to_slot.amount
	
	to_slot.item = temp_item
	to_slot.amount = temp_amount
	
	from_inventory.emit_signal("inventory_updated")
	if from_inventory != to_inventory:
		to_inventory.emit_signal("inventory_updated")
		
	return true

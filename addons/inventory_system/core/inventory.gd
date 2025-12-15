@tool
extends BaseInventory
class_name Inventory
## Standard inventory implementation with stacking support.
## Extends BaseInventory for polymorphic inventory handling.

func add_item(item: InventoryItem, amount: int = 1, start_index: int = 0) -> int:
	var remaining = amount
	
	# First try to stack with existing items:
	for i in range(start_index, slots.size()):
		var slot = slots[i]
		if not slot.is_empty() and slot.item == item:
			var space = item.max_stack - slot.amount
			var to_add = min(remaining, space)
			slot.amount += to_add
			remaining -= to_add
			if remaining == 0:
				emit_signal("inventory_updated")
				return 0
	
	# Then try to find empty slots
	for i in range(start_index, slots.size()):
		var slot = slots[i]
		if slot.is_empty():
			slot.item = item
			var to_add = min(remaining, item.max_stack)
			slot.amount = to_add
			remaining -= to_add
			if remaining == 0:
				emit_signal("inventory_updated")
				return 0
				
	emit_signal("inventory_updated")
	return remaining # Return amount that couldn't be added

func remove_item_at_index(index: int, amount: int) -> InventoryItem:
	if index < 0 or index >= slots.size():
		return null
	
	var slot = slots[index]
	if slot.is_empty():
		return null
		
	var item_removed = slot.item
	slot.amount -= amount
	
	if slot.amount <= 0:
		slot.item = null
		slot.amount = 0
		
	emit_signal("inventory_updated")
	return item_removed

func set_item(index: int, item: InventoryItem, amount: int) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index].item = item
	slots[index].amount = amount
	emit_signal("inventory_updated")

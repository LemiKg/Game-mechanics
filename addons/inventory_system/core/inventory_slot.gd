@tool
extends Resource
class_name InventorySlot

## The item in this slot (InventoryItem resource)
@export var item: InventoryItem
@export var amount: int = 0

## Per-item instance data (only for non-stackable items like equipment).
## Null for stackable items.
var instance: ItemInstance

func _init(p_item: InventoryItem = null, p_amount: int = 0) -> void:
	item = p_item
	amount = p_amount

func is_empty() -> bool:
	return item == null or amount <= 0

func can_add(p_item: InventoryItem, p_amount: int) -> bool:
	if is_empty():
		return true
	if item == p_item and amount + p_amount <= item.max_stack:
		return true
	return false

## Clear the slot completely.
func clear() -> void:
	item = null
	amount = 0
	instance = null

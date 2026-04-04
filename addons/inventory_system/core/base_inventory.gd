@tool
extends Resource
class_name BaseInventory
## Abstract base class for inventory containers.
## Extend this to create specialized inventory types like WeightBasedInventory, FilteredInventory, etc.

signal inventory_updated

signal weight_changed(current: float, maximum: float)

## Array of InventorySlot resources
@export var slots: Array[InventorySlot] = []
@export var size: int = 20:
	set(value):
		if size == value:
			return
		size = value
		resize(value)

## Array of ItemCategory resources for filtering
@export var allowed_categories: Array[ItemCategory] = []

## Maximum weight capacity. 0 = unlimited (backwards compatible).
@export_range(0.0, 10000.0, 1.0) var max_weight: float = 0.0

func _init():
	resize(size)

## @virtual Returns true if the inventory accepts this item type.
## Override for custom acceptance logic (weight limits, category filters, etc.)
func accepts_item(item: InventoryItem) -> bool:
	if allowed_categories.is_empty():
		return true
	
	var item_categories = item.get_categories()
	for category in item_categories:
		if category in allowed_categories:
			return true
			
	return false

## @virtual Resize the inventory to a new size.
## Override for custom resize behavior.
func resize(new_size: int) -> void:
	if size != new_size:
		size = new_size
	
	if slots.size() < new_size:
		for i in range(new_size - slots.size()):
			slots.append(_create_slot())
	elif slots.size() > new_size:
		slots.resize(new_size)

## @virtual Create a new slot instance.
## Override to use custom slot types.
func _create_slot() -> InventorySlot:
	return InventorySlot.new()

## @virtual Add items to the inventory.
## @param item: The item to add
## @param amount: How many to add
## @param start_index: Start searching from this slot index
## @returns: The amount that couldn't be added (0 = all added successfully)
func add_item(item: InventoryItem, amount: int = 1, start_index: int = 0) -> int:
	push_error("BaseInventory.add_item() is abstract - override in subclass")
	return amount

## @virtual Remove items from a specific slot.
## @param index: The slot index to remove from
## @param amount: How many to remove
## @returns: The item that was removed, or null
func remove_item_at_index(index: int, amount: int) -> InventoryItem:
	push_error("BaseInventory.remove_item_at_index() is abstract - override in subclass")
	return null

## @virtual Set item at a specific slot.
## @param index: The slot index
## @param item: The item to set (or null to clear)
## @param amount: The stack amount
func set_item(index: int, item: InventoryItem, amount: int) -> void:
	push_error("BaseInventory.set_item() is abstract - override in subclass")

## Get the total weight of all items in the inventory.
func get_current_weight() -> float:
	var total := 0.0
	for slot in slots:
		if not slot.is_empty():
			total += slot.item.weight * slot.amount
	return total


## Check if adding this item would fit within weight limit (if set).
func can_add_weight(item: InventoryItem, amount: int = 1) -> bool:
	if max_weight <= 0.0:
		return true
	return get_current_weight() + (item.weight * amount) <= max_weight


## Get weight as a ratio (0.0 to 1.0+). Returns 0 if no weight limit.
func get_weight_ratio() -> float:
	if max_weight <= 0.0:
		return 0.0
	return get_current_weight() / max_weight


## Emit weight change. Call after any inventory modification.
func _emit_weight_changed() -> void:
	weight_changed.emit(get_current_weight(), max_weight)


## Helper to check if a slot index is valid
func is_valid_index(index: int) -> bool:
	return index >= 0 and index < slots.size()

## Helper to get slot at index safely
func get_slot(index: int) -> InventorySlot:
	if is_valid_index(index):
		return slots[index]
	return null

## Helper to get item at index safely
func get_item_at(index: int) -> InventoryItem:
	var slot = get_slot(index)
	if slot and not slot.is_empty():
		return slot.item
	return null

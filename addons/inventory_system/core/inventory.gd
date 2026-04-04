@tool
extends BaseInventory
class_name Inventory
## Standard inventory implementation with stacking support.
## Auto-creates ItemInstance for non-stackable items (equipment).


func add_item(item: InventoryItem, amount: int = 1, start_index: int = 0) -> int:
	var remaining = amount

	# First try to stack with existing items (only for stackable items)
	if item.max_stack > 1:
		for i in range(start_index, slots.size()):
			var slot = slots[i]
			if not slot.is_empty() and slot.item == item:
				var space = item.max_stack - slot.amount
				var to_add = min(remaining, space)
				slot.amount += to_add
				remaining -= to_add
				if remaining == 0:
					inventory_updated.emit()
					_emit_weight_changed()
					return 0

	# Then try to find empty slots
	for i in range(start_index, slots.size()):
		var slot = slots[i]
		if slot.is_empty():
			slot.item = item
			var to_add = min(remaining, item.max_stack)
			slot.amount = to_add
			remaining -= to_add

			# Auto-create ItemInstance for non-stackable items (equipment)
			if item.max_stack == 1:
				slot.instance = ItemInstance.new(item)

			if remaining == 0:
				inventory_updated.emit()
				_emit_weight_changed()
				return 0

	inventory_updated.emit()
	_emit_weight_changed()
	return remaining


func remove_item_at_index(index: int, amount: int) -> InventoryItem:
	if index < 0 or index >= slots.size():
		return null

	var slot = slots[index]
	if slot.is_empty():
		return null

	var item_removed = slot.item
	slot.amount -= amount

	if slot.amount <= 0:
		slot.clear()

	inventory_updated.emit()
	_emit_weight_changed()
	return item_removed


func set_item(index: int, item: InventoryItem, amount: int) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index].item = item
	slots[index].amount = amount
	if item == null:
		slots[index].instance = null
	inventory_updated.emit()
	_emit_weight_changed()


## Serialize the entire inventory to a Dictionary.
func serialize() -> Dictionary:
	var slot_data: Array[Dictionary] = []
	for slot in slots:
		if slot.is_empty():
			slot_data.append({})
		else:
			var entry := {"id": slot.item.id, "amount": slot.amount}
			if slot.instance:
				entry["instance"] = slot.instance.serialize()
			slot_data.append(entry)
	return {"slots": slot_data, "max_weight": max_weight}


## Deserialize from a Dictionary. Requires ItemDatabase autoload.
func deserialize(data: Dictionary) -> void:
	var item_db: Node = null
	var tree := Engine.get_main_loop()
	if tree and tree is SceneTree:
		item_db = tree.root.get_node_or_null("/root/ItemDatabase")

	var slot_data: Array = data.get("slots", [])
	max_weight = data.get("max_weight", max_weight)

	if slot_data.size() != slots.size():
		resize(slot_data.size())

	for i in range(slot_data.size()):
		var entry: Dictionary = slot_data[i]
		if entry.is_empty():
			slots[i].clear()
		else:
			var item_id: String = entry.get("id", "")
			var item: InventoryItem = item_db.get_item(item_id) if item_db else null
			if item:
				slots[i].item = item
				slots[i].amount = entry.get("amount", 1)
				if entry.has("instance") and item_db:
					slots[i].instance = ItemInstance.from_dict(entry["instance"], item_db)
				elif item.max_stack == 1:
					slots[i].instance = ItemInstance.new(item)
			else:
				push_warning("Inventory.deserialize: item '%s' not found" % item_id)
				slots[i].clear()

	inventory_updated.emit()
	_emit_weight_changed()

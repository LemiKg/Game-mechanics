extends BaseSlotUI
class_name SlotUI
## UI representation of a single inventory slot.
## Emits signals for drag-drop and tooltip interactions.

## Emitted when an item is dropped onto this slot
signal item_drop_requested(data: Dictionary, target_inventory: Inventory, target_index: int)
## Emitted when the slot is double-clicked (use consumable or equip equipment)
signal item_activated(item: InventoryItem, inventory: Inventory, slot_index: int)

@export var amount_label: Label

var inventory: Inventory
var slot_index: int = -1
var amount: int = 0

func set_slot(p_inventory: Inventory, p_index: int, p_slot: InventorySlot) -> void:
	inventory = p_inventory
	slot_index = p_index
	item = p_slot.item
	amount = p_slot.amount
	
	if not icon_texture or not amount_label:
		push_warning("SlotUI: Missing icon_texture or amount_label references")
		return
	
	if item:
		icon_texture.texture = item.icon
		icon_texture.visible = true
		if amount > 1:
			amount_label.text = str(amount)
			amount_label.visible = true
		else:
			amount_label.visible = false
	else:
		icon_texture.texture = null
		icon_texture.visible = false
		amount_label.visible = false

func set_selected(selected: bool):
	var border = get_node_or_null("SelectionBorder")
	if border:
		border.visible = selected

func _get_drag_data_payload() -> Dictionary:
	return {
		"type": "inventory_item",
		"inventory": inventory,
		"index": slot_index,
		"item": item,
		"amount": amount
	}

func _can_drop_data(at_position, data):
	return data is Dictionary and data.has("type") and data["type"] in ["inventory_item", "equipment_item"]

func _drop_data(at_position, data):
	# Emit signal for decoupled handling by InventoryInteractionHandler
	item_drop_requested.emit(data, inventory, slot_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			if item:
				item_activated.emit(item, inventory, slot_index)
				accept_event()

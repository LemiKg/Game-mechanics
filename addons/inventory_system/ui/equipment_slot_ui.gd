extends BaseSlotUI
class_name EquipmentSlotUI
## UI representation of an equipment slot.
## Emits signals for drag-drop and tooltip interactions.

## Emitted when an item is dropped onto this equipment slot (equip request)
signal equip_requested(data: Dictionary, target_slot_name: String)

@export var slot_name: String = ""
@export var slot_label: Label
@export var placeholder_icon: Texture2D

## Optional: Containers to set mouse_filter on. Use @export for explicit references.
@export_group("Mouse Filter Passthrough")
@export var passthrough_controls: Array[Control] = []

func _ready():
	super._ready()
	
	if placeholder_icon:
		icon_texture.texture = placeholder_icon
		icon_texture.modulate = Color(1, 1, 1, 0.5) # Dimmed
	
	if icon_texture:
		icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slot_label:
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set mouse filter on explicitly referenced controls (DIP compliant)
	for control in passthrough_controls:
		if control:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Fallback: iterate direct children by type (avoids hardcoded paths)
	_setup_mouse_passthrough_recursive(self)

func set_slot_label(label_text: String):
	if slot_label:
		slot_label.text = label_text

func set_item(p_item: Resource):
	item = p_item
	if item:
		icon_texture.texture = item.icon
		icon_texture.modulate = Color(1, 1, 1, 1)
	else:
		if placeholder_icon:
			icon_texture.texture = placeholder_icon
			icon_texture.modulate = Color(1, 1, 1, 0.5)
		else:
			icon_texture.texture = null

func _get_drag_data_payload() -> Dictionary:
	return {
		"type": "equipment_item",
		"slot_name": slot_name,
		"item": item
	}

func _can_drop_data(at_position, data) -> bool:
	if slot_name == "":
		return false
	
	if not (data is Dictionary and data.has("item")):
		return false
	
	var dragged_item = data["item"]
	if not dragged_item:
		return false
	
	# Use polymorphic method instead of duck-typing
	if dragged_item.is_equippable():
		return dragged_item.slot_type_name == slot_name
	
	return false

func _drop_data(at_position, data):
	# Emit signal for decoupled handling by InventoryInteractionHandler
	equip_requested.emit(data, slot_name)

## Recursively set mouse_filter to IGNORE on container-type children.
## This allows the root control to receive mouse events for drag-drop.
func _setup_mouse_passthrough_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Container or child is PanelContainer or child is MarginContainer:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_setup_mouse_passthrough_recursive(child)

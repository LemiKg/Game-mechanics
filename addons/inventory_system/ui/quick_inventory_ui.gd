extends BaseInventoryDisplay
class_name QuickInventoryUI
## A minimal hotbar UI for quick item access and usage.
## Uses polymorphic item.use() instead of type checking.
## Supports equipping items directly from hotbar slots.
##
## Required exports:
## - inventory_component: For accessing hotbar items
##
## Input Actions (define in Project Settings > Input Map):
## - "hotbar_slot_1" through "hotbar_slot_6": Select slot
## - "hotbar_use": Use selected item

@export var slot_scene: PackedScene
@export var container: Container
@export var slot_count: int = 6
## Optional: Reference to the player/user node for item.use() calls
@export var item_user: Node
## Optional: Tooltip controller for showing item details on hover
@export var tooltip_controller: TooltipController

@export_group("Input Actions")
## Base name for slot selection actions (will append _1, _2, etc.)
## If empty, falls back to number keys 1-6
@export var slot_action_prefix: String = "hotbar_slot"
## Action name for using the selected item. If empty, falls back to "E" key.
@export var use_action: String = "hotbar_use"

var selected_index: int = 0 # Default to first slot

func _ready():
	super._ready()

func refresh():
	for child in container.get_children():
		child.queue_free()
		
	if not inventory_component or not inventory_component.hotbar_inventory:
		return
		
	var slots = inventory_component.hotbar_inventory.slots
	# Only show up to slot_count
	var count = min(slots.size(), slot_count)
	
	for i in range(count):
		var slot_ui = slot_scene.instantiate()
		container.add_child(slot_ui)
		slot_ui.set_slot(inventory_component.hotbar_inventory, i, slots[i])
		# Connect tooltip signal via controller
		if tooltip_controller:
			tooltip_controller.connect_slot(slot_ui)
		
		# Minimalistic style: Remove background panel
		if slot_ui is PanelContainer:
			var style = StyleBoxEmpty.new()
			slot_ui.add_theme_stylebox_override("panel", style)
			
	_update_selection()

func _input(event):
	if not visible:
		return
	
	# Use Input Actions if defined, otherwise fall back to hardcoded keys
	if event.is_pressed() and not event.is_echo():
		# Check slot selection actions
		for i in range(slot_count):
			var action_name = "%s_%d" % [slot_action_prefix, i + 1]
			if _is_action_pressed(event, action_name, _get_fallback_key_for_slot(i)):
				select_slot(i)
				get_viewport().set_input_as_handled()
				return
		
		# Check use action
		if _is_action_pressed(event, use_action, KEY_E):
			use_selected_item()
			get_viewport().set_input_as_handled()

## Check if an action is pressed, with fallback to a specific key
func _is_action_pressed(event: InputEvent, action_name: String, fallback_key: int) -> bool:
	# Try action first if it exists
	if action_name and InputMap.has_action(action_name):
		return event.is_action_pressed(action_name)
	
	# Fallback to hardcoded key
	if event is InputEventKey:
		return event.keycode == fallback_key
	
	return false

## Get fallback key for slot index (KEY_1 through KEY_6)
func _get_fallback_key_for_slot(index: int) -> int:
	return KEY_1 + index

func select_slot(index: int):
	if index >= 0 and index < slot_count:
		selected_index = index
		_update_selection()

func _update_selection():
	var children = container.get_children()
	for i in range(children.size()):
		var slot_ui = children[i]
		if slot_ui.has_method("set_selected"):
			slot_ui.set_selected(i == selected_index)

func use_selected_item():
	if selected_index < 0 or not inventory_component:
		return
	
	if not inventory_component.hotbar_inventory:
		return
		
	var slots = inventory_component.hotbar_inventory.slots
	
	if selected_index < slots.size():
		var slot = slots[selected_index]
		if not slot.is_empty():
			var item = slot.item
			
			if interaction_handler:
				interaction_handler.handle_item_activation(item, inventory_component.hotbar_inventory, selected_index)
			else:
				push_warning("QuickInventoryUI: No interaction_handler assigned")

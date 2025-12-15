extends EquippableInventoryDisplay
class_name InventoryUI
## Main UI controller for displaying inventory and equipment.
## This class handles only display concerns; business logic is delegated to InventoryInteractionHandler.

@export_group("Scenes")
@export var slot_scene: PackedScene
@export var equipment_slot_scene: PackedScene

@export_group("Containers")
@export var grid_container: GridContainer
@export var hotbar_container: Container
@export var equipment_container: Control

@export_group("Tooltip")
@export var tooltip_controller: TooltipController

## Cached equipment slots for O(1) lookup instead of tree traversal
var _equipment_slot_cache: Dictionary = {} # slot_name -> EquipmentSlotUI

func _ready():
	super._ready()
	if equipment_component:
		set_equipment(equipment_component)
	_setup_interaction_handler()

func _setup_interaction_handler():
	if not interaction_handler:
		# Auto-create handler if not provided
		interaction_handler = InventoryInteractionHandler.new()
		add_child(interaction_handler)
	
	interaction_handler.inventory_component = inventory_component
	interaction_handler.equipment_component = equipment_component

func set_equipment(component: EquipmentComponent):
	if equipment_component and equipment_component.equipment_changed.is_connected(refresh_equipment_slot):
		equipment_component.equipment_changed.disconnect(refresh_equipment_slot)
		
	equipment_component = component
	if equipment_component:
		equipment_component.equipment_changed.connect(refresh_equipment_slot)
		if interaction_handler:
			interaction_handler.equipment_component = equipment_component
		init_equipment_slots()

func refresh():
	# Clear existing slots
	if not grid_container:
		push_warning("InventoryUI: No grid_container assigned")
		return
	
	for child in grid_container.get_children():
		child.queue_free()
	
	if hotbar_container:
		for child in hotbar_container.get_children():
			child.queue_free()
	
	if not inventory_component:
		return
		
	# Refresh Hotbar
	if hotbar_container and inventory_component.hotbar_inventory:
		var slots = inventory_component.hotbar_inventory.slots
		for i in range(slots.size()):
			var slot_ui = slot_scene.instantiate()
			hotbar_container.add_child(slot_ui)
			slot_ui.set_slot(inventory_component.hotbar_inventory, i, slots[i])
			_connect_slot_signals(slot_ui)
			
	# Refresh Main Inventory
	if grid_container and inventory_component.main_inventory:
		var slots = inventory_component.main_inventory.slots
		for i in range(slots.size()):
			var slot_ui = slot_scene.instantiate()
			grid_container.add_child(slot_ui)
			slot_ui.set_slot(inventory_component.main_inventory, i, slots[i])
			_connect_slot_signals(slot_ui)

func _connect_slot_signals(slot_ui: SlotUI):
	if interaction_handler:
		slot_ui.item_drop_requested.connect(interaction_handler.handle_inventory_drop)
		slot_ui.item_activated.connect(interaction_handler.handle_item_activation)
	if tooltip_controller:
		tooltip_controller.connect_slot(slot_ui)

func init_equipment_slots():
	if not equipment_container or not equipment_component:
		return
	
	if not equipment_slot_scene:
		push_warning("InventoryUI: No equipment_slot_scene assigned")
		return
	
	# Clear cache
	_equipment_slot_cache.clear()
	
	# Find existing slots in the layout and cache them
	_cache_existing_equipment_slots(equipment_container)
	
	# Hide all cached initially
	for slot_ui in _equipment_slot_cache.values():
		slot_ui.visible = false
		
	for slot_name in equipment_component.defined_slots:
		var slot_ui: EquipmentSlotUI
		
		if _equipment_slot_cache.has(slot_name):
			slot_ui = _equipment_slot_cache[slot_name]
			slot_ui.visible = true
		else:
			slot_ui = equipment_slot_scene.instantiate()
			equipment_container.add_child(slot_ui)
			slot_ui.slot_name = slot_name
			slot_ui.name = slot_name
			_equipment_slot_cache[slot_name] = slot_ui
			
		slot_ui.set_slot_label(slot_name)
		
		var item = equipment_component.get_item_in_slot(slot_name)
		slot_ui.set_item(item)
		_connect_equipment_slot_signals(slot_ui)

## Cache existing equipment slots recursively from the container
func _cache_existing_equipment_slots(node: Node) -> void:
	for child in node.get_children():
		if child is EquipmentSlotUI:
			_equipment_slot_cache[child.name] = child
		_cache_existing_equipment_slots(child)

func _connect_equipment_slot_signals(slot_ui: EquipmentSlotUI):
	if interaction_handler:
		if not slot_ui.equip_requested.is_connected(interaction_handler.handle_equip_request):
			slot_ui.equip_requested.connect(interaction_handler.handle_equip_request)
	if tooltip_controller:
		tooltip_controller.connect_slot(slot_ui)

func refresh_equipment_slot(slot_name: String, item: InventoryItem) -> void:
	# Use cached slot for O(1) lookup
	var slot_ui = _equipment_slot_cache.get(slot_name)
	if slot_ui:
		slot_ui.set_item(item)

extends Control
class_name BaseInventoryDisplay
## Abstract base class for inventory displays.
## Handles component connections and refresh lifecycle.
## For equipment support, use EquippableInventoryDisplay instead (ISP compliance).

@export var inventory_component: InventoryComponent
@export var interaction_handler: InventoryInteractionHandler

## Whether to use full refresh on inventory_changed. Subclasses that implement
## on_slot_updated() can set this to false for incremental updates.
var _use_full_refresh: bool = true

func _ready():
	if inventory_component:
		set_inventory(inventory_component)

func set_inventory(component: InventoryComponent):
	if inventory_component:
		if inventory_component.inventory_changed.is_connected(refresh):
			inventory_component.inventory_changed.disconnect(refresh)
		_disconnect_slot_signals(inventory_component)

	inventory_component = component
	if inventory_component:
		if _use_full_refresh:
			inventory_component.inventory_changed.connect(refresh)
		_connect_slot_signals(inventory_component)
		if interaction_handler:
			interaction_handler.inventory_component = inventory_component
		refresh()

## @virtual Called when a single slot changes. Override for incremental updates.
func on_slot_updated(_inventory: Inventory, _index: int) -> void:
	pass

## @virtual Method to be overridden by subclasses
func refresh():
	pass

func _connect_slot_signals(component: InventoryComponent) -> void:
	if component.main_inventory:
		if not component.main_inventory.slot_updated.is_connected(_on_main_slot_updated):
			component.main_inventory.slot_updated.connect(_on_main_slot_updated)
	if component.hotbar_inventory:
		if not component.hotbar_inventory.slot_updated.is_connected(_on_hotbar_slot_updated):
			component.hotbar_inventory.slot_updated.connect(_on_hotbar_slot_updated)

func _disconnect_slot_signals(component: InventoryComponent) -> void:
	if component.main_inventory and component.main_inventory.slot_updated.is_connected(_on_main_slot_updated):
		component.main_inventory.slot_updated.disconnect(_on_main_slot_updated)
	if component.hotbar_inventory and component.hotbar_inventory.slot_updated.is_connected(_on_hotbar_slot_updated):
		component.hotbar_inventory.slot_updated.disconnect(_on_hotbar_slot_updated)

func _on_main_slot_updated(index: int) -> void:
	if inventory_component:
		on_slot_updated(inventory_component.main_inventory, index)

func _on_hotbar_slot_updated(index: int) -> void:
	if inventory_component:
		on_slot_updated(inventory_component.hotbar_inventory, index)

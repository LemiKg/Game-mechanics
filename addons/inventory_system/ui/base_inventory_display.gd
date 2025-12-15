extends Control
class_name BaseInventoryDisplay
## Abstract base class for inventory displays.
## Handles component connections and refresh lifecycle.
## For equipment support, use EquippableInventoryDisplay instead (ISP compliance).

@export var inventory_component: InventoryComponent
@export var interaction_handler: InventoryInteractionHandler

func _ready():
	if inventory_component:
		set_inventory(inventory_component)

func set_inventory(component: InventoryComponent):
	if inventory_component and inventory_component.inventory_changed.is_connected(refresh):
		inventory_component.inventory_changed.disconnect(refresh)
	
	inventory_component = component
	if inventory_component:
		inventory_component.inventory_changed.connect(refresh)
		if interaction_handler:
			interaction_handler.inventory_component = inventory_component
		refresh()

## @virtual Method to be overridden by subclasses
func refresh():
	pass

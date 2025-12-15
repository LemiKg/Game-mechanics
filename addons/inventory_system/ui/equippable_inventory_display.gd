extends BaseInventoryDisplay
class_name EquippableInventoryDisplay
## Abstract base class for inventory displays that also handle equipment.
## Extends BaseInventoryDisplay with equipment component support (ISP compliance).

@export var equipment_component: EquipmentComponent

func _ready():
	super._ready()
	if equipment_component:
		_setup_equipment_connection()

func _setup_equipment_connection():
	if interaction_handler:
		interaction_handler.equipment_component = equipment_component

## @virtual Set the equipment component and connect signals.
## Override to add custom equipment initialization.
func set_equipment(component: EquipmentComponent):
	equipment_component = component
	if equipment_component and interaction_handler:
		interaction_handler.equipment_component = equipment_component

## @virtual Initialize equipment slot UI elements.
## Override in subclasses to create/configure equipment slots.
func init_equipment_slots():
	pass

## @virtual Refresh a specific equipment slot.
## @param slot_name: The name of the slot to refresh
## @param item: The item now in the slot (or null if empty)
func refresh_equipment_slot(slot_name: String, item: InventoryItem) -> void:
	pass

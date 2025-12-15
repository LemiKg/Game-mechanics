@tool
extends InventoryItem
class_name EquipmentItem
## Equipment item that can be equipped to a slot.
## Uses polymorphic methods for slot compatibility checking.

## The name of the slot this item can equip to (e.g., "Head", "MainHand", "Chest")
@export var slot_type_name: String = ""
@export var defense: int = 0
@export var damage: int = 0
## Flexible stats dictionary for custom attributes
@export var stats: Dictionary = {}

func is_equippable() -> bool:
	return slot_type_name != ""

func get_tooltip_text() -> String:
	var text = super.get_tooltip_text()
	text += _format_section_header(slot_type_name if slot_type_name else "Equipment", "yellow")
	
	if defense > 0:
		text += _format_stat_line("Defense", defense, "steelblue", "+")
	if damage > 0:
		text += _format_stat_line("Damage", damage, "orange", "+")
	
	for stat_name in stats:
		text += _format_stat_line(stat_name, stats[stat_name])
	
	return text

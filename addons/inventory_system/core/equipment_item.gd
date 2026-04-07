@tool
extends InventoryItem
class_name EquipmentItem
## Equipment item that can be equipped to a slot.
## Stat bonuses are expressed as StatModifier resources, applied via
## EquipmentComponent's optional StatComponent injection.

## The name of the slot this item can equip to (e.g. "Head", "MainHand", "Chest").
@export var slot_type_name: String = ""

## Stat modifiers contributed by this item while equipped. Each modifier's
## source_id should be set to this item's id so unequip removes them cleanly.
@export var stat_modifiers: Array[StatModifier] = []

## Maximum durability for this equipment. 0 = no durability tracking.
@export_range(0, 1000, 1) var max_durability: int = 0

func is_equippable() -> bool:
	return slot_type_name != ""

## Returns the stat modifiers this item contributes. Implements the
## StatModifierProvider duck-typed contract used by EquipmentComponent.
func get_stat_modifiers() -> Array[StatModifier]:
	return stat_modifiers

func get_tooltip_text() -> String:
	var text := super.get_tooltip_text()
	text += _format_section_header(slot_type_name if slot_type_name else "Equipment", "yellow")

	for m in stat_modifiers:
		if m == null:
			continue
		var sign := "+" if m.value >= 0.0 else ""
		var unit := "%" if m.op == StatModifier.Op.PERCENT else ""
		var stat_label := String(m.stat_id).capitalize()
		text += "\n[color=lightblue]%s%g%s %s[/color]" % [sign, m.value, unit, stat_label]

	return text

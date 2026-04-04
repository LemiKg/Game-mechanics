@tool
extends Resource
class_name InventoryItem

## Item rarity tier, affects tooltip color and slot border.
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

## Rarity color mapping for UI display.
const RARITY_COLORS := {
	Rarity.COMMON: Color.WHITE,
	Rarity.UNCOMMON: Color(0.3, 0.8, 0.3),
	Rarity.RARE: Color(0.4, 0.6, 1.0),
	Rarity.EPIC: Color(0.7, 0.4, 0.9),
	Rarity.LEGENDARY: Color(1.0, 0.6, 0.2),
}

const RARITY_NAMES := {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Epic",
	Rarity.LEGENDARY: "Legendary",
}

## Base class for all inventory items.
## Extend this to create specialized item types like ConsumableItem, EquipmentItem, etc.

@export var name: String = "New Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 1
@export var weight: float = 0.0
@export var value: int = 0
## Array of ItemCategory resources
@export var categories: Array[ItemCategory] = []

# Unique ID for save/load systems (set manually or via code)
@export var id: String = ""

## Item rarity tier.
@export var rarity: Rarity = Rarity.COMMON

#region Virtual Methods

## @virtual Returns true if this item can be used (consumed, activated, etc.)
## Override in subclasses like ConsumableItem
func can_use() -> bool:
	return false

## @virtual Use the item. Override in subclasses to implement specific behavior.
## @param user: The node using the item (typically the player)
func use(user: Node) -> void:
	pass

## @virtual Returns true if this item can be equipped to an equipment slot.
## Override in EquipmentItem to return true.
func is_equippable() -> bool:
	return false

## @virtual Returns the categories this item belongs to.
## Override for custom categorization logic.
func get_categories() -> Array[ItemCategory]:
	return categories

## @virtual Returns formatted tooltip text (BBCode) for UI display.
## Override in subclasses to add type-specific information.
func get_tooltip_text() -> String:
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var color_hex: String = rarity_color.to_html(false)
	var text = "[b][color=#%s]%s[/color][/b]" % [color_hex, name]
	if rarity != Rarity.COMMON:
		text += "\n[color=#%s]%s[/color]" % [color_hex, RARITY_NAMES.get(rarity, "")]
	if description:
		text += "\n%s" % description
	if value > 0:
		text += _format_stat_line("Value", value, "gold")
	if weight > 0:
		text += _format_stat_line("Weight", "%.1f" % weight, "gray")
	return text

#endregion

#region Tooltip Formatting Helpers

## Format a section header for tooltip display.
## @param title: The section title
## @param color: BBCode color name or hex
## @returns: Formatted BBCode string
func _format_section_header(title: String, color: String = "white") -> String:
	return "\n[color=%s]--- %s ---[/color]" % [color, title]

## Format a stat line for tooltip display.
## @param label: The stat label
## @param stat_value: The value to display (any type, will be converted to string)
## @param color: BBCode color name or hex
## @param prefix: Optional prefix like "+" before the value
## @returns: Formatted BBCode string
func _format_stat_line(label: String, stat_value, color: String = "white", prefix: String = "") -> String:
	return "\n[color=%s]%s: %s%s[/color]" % [color, label, prefix, str(stat_value)]

## Format an effect line for tooltip display (no label, just value).
## @param text: The effect text
## @param color: BBCode color name or hex
## @returns: Formatted BBCode string
func _format_effect_line(text: String, color: String = "white") -> String:
	return "\n[color=%s]%s[/color]" % [color, text]

#endregion

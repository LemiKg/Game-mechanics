@tool
extends InventoryItem
class_name ConsumableItem
## Consumable item that applies effects when used.
## Uses the ItemEffect system for OCP-compliant extensibility.

## Array of effects to apply when this item is consumed.
## Add HealEffect, ManaEffect, or custom effects here.
@export var effects: Array[ItemEffect] = []

func can_use() -> bool:
	return true

## Apply all effects to the user.
func use(user: Node) -> void:
	if not user:
		push_warning("ConsumableItem: No user provided for item use")
		return

	for effect in effects:
		if effect and effect.can_apply(user):
			effect.apply(user)

func get_tooltip_text() -> String:
	var text = super.get_tooltip_text()
	text += _format_section_header("Consumable", "lime")

	for effect in effects:
		if effect:
			var effect_text = effect.get_tooltip_text()
			if effect_text:
				text += "\n" + effect_text

	return text

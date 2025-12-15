@tool
extends Resource
class_name ItemEffect
## Abstract base class for item effects.
## Extend this to create new effect types like HealEffect, ManaEffect, DamageEffect, etc.
## Using Resources allows effects to be created and configured in the Inspector.

@export var effect_name: String = "Effect"
@export var value: float = 0.0

## @virtual Apply this effect to the user.
## @param user: The node using the item (typically the player)
## @returns: True if the effect was successfully applied
func apply(user: Node) -> bool:
	push_error("ItemEffect.apply() is abstract - override in subclass")
	return false

## @virtual Get formatted text for tooltip display.
## @returns: BBCode formatted string describing this effect
func get_tooltip_text() -> String:
	return ""

## @virtual Check if this effect can be applied to the user.
## @param user: The target node
## @returns: True if the effect can be applied
func can_apply(user: Node) -> bool:
	return user != null

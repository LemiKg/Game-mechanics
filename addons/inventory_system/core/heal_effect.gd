@tool
extends ItemEffect
class_name HealEffect
## Restores health to the user.
## Requires user to have a heal(amount: int) method.

func _init():
	effect_name = "Heal"

func apply(user: Node) -> bool:
	if not can_apply(user):
		return false
	
	if user.has_method("heal"):
		user.heal(int(value))
		return true
	
	push_warning("HealEffect: User %s does not have heal() method" % user.name)
	return false

func can_apply(user: Node) -> bool:
	return user != null and user.has_method("heal")

func get_tooltip_text() -> String:
	if value > 0:
		return "[color=red]+%d Health[/color]" % int(value)
	return ""

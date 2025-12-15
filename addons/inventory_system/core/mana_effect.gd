@tool
extends ItemEffect
class_name ManaEffect
## Restores mana to the user.
## Requires user to have a restore_mana(amount: int) method.

func _init():
	effect_name = "Mana"

func apply(user: Node) -> bool:
	if not can_apply(user):
		return false
	
	if user.has_method("restore_mana"):
		user.restore_mana(int(value))
		return true
	
	push_warning("ManaEffect: User %s does not have restore_mana() method" % user.name)
	return false

func can_apply(user: Node) -> bool:
	return user != null and user.has_method("restore_mana")

func get_tooltip_text() -> String:
	if value > 0:
		return "[color=cyan]+%d Mana[/color]" % int(value)
	return ""

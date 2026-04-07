@tool
extends ItemEffect
class_name ApplyModifierEffect
## Pushes a (typically timed) StatModifier onto the user's StatComponent.
## Powers buff potions: e.g. "+5 attack for 60s".
##
## The modifier resource should have duration > 0 for a temporary buff.

@export var modifier: StatModifier

func _init() -> void:
	effect_name = "Apply Modifier"

func apply(user: Node) -> bool:
	if not can_apply(user):
		return false
	if modifier == null:
		push_warning("ApplyModifierEffect: no modifier configured")
		return false
	var sc := _find_stat_component(user)
	if sc == null:
		push_warning("ApplyModifierEffect: no StatComponent on '%s'" % user.name)
		return false
	# Duplicate so multiple uses don't share the same `remaining` counter.
	var mod_copy: StatModifier = modifier.duplicate()
	sc.add_modifier(mod_copy)
	return true

func can_apply(user: Node) -> bool:
	return user != null and modifier != null and _find_stat_component(user) != null

func _find_stat_component(user: Node) -> StatComponent:
	var direct := user.get_node_or_null("StatComponent") as StatComponent
	if direct:
		return direct
	for child in user.get_children():
		if child is StatComponent:
			return child
	return null

func get_tooltip_text() -> String:
	if modifier == null:
		return ""
	var op_label := "+" if modifier.value >= 0.0 else ""
	var unit := "%" if modifier.op == StatModifier.Op.PERCENT else ""
	var stat_label := String(modifier.stat_id).capitalize()
	var line := "[color=cyan]%s%d%s %s[/color]" % [op_label, int(modifier.value), unit, stat_label]
	if modifier.duration > 0.0:
		line += " [color=gray](%.0fs)[/color]" % modifier.duration
	return line

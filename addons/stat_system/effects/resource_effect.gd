@tool
extends ItemEffect
class_name ResourceEffect
## Generic resource effect — applies a delta to one resource stat on the
## user's StatComponent. Replaces HealEffect and ManaEffect with a single
## data-driven effect.
##
## Authoring: target_stat = "health"/"mana"/"stamina", delta = +50, etc.
## Negative delta damages, positive heals/restores.

@export var target_stat: StringName = &""
@export var delta: float = 0.0

func _init() -> void:
	effect_name = "Resource"

func apply(user: Node) -> bool:
	if not can_apply(user):
		return false
	var sc := _find_stat_component(user)
	if sc == null:
		push_warning("ResourceEffect: no StatComponent on '%s'" % user.name)
		return false
	sc.modify_resource(target_stat, delta)
	return true

func can_apply(user: Node) -> bool:
	return user != null and _find_stat_component(user) != null

func _find_stat_component(user: Node) -> StatComponent:
	# Common patterns: a child named "StatComponent", or any descendant.
	var direct := user.get_node_or_null("StatComponent") as StatComponent
	if direct:
		return direct
	for child in user.get_children():
		if child is StatComponent:
			return child
	return null

func get_tooltip_text() -> String:
	if delta == 0.0 or target_stat == &"":
		return ""
	var sign := "+" if delta > 0.0 else ""
	var color := "lime" if delta > 0.0 else "red"
	return "[color=%s]%s%d %s[/color]" % [color, sign, int(delta), String(target_stat).capitalize()]

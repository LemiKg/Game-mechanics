@tool
extends InventoryItem
class_name ConsumableItem
## Consumable item that applies effects when used.
## Uses the ItemEffect system for OCP-compliant extensibility.

## Array of effects to apply when this item is consumed.
## Add HealEffect, ManaEffect, or custom effects here.
@export var effects: Array[ItemEffect] = []

## Legacy properties for backwards compatibility - prefer using effects array
@export_group("Legacy (Deprecated)")
@export var health_restore: int = 0:
	set(v):
		health_restore = v
		_sync_legacy_effects()
@export var mana_restore: int = 0:
	set(v):
		mana_restore = v
		_sync_legacy_effects()

func can_use() -> bool:
	return true

## Apply all effects to the user.
## @param user: The node using the item (should have appropriate methods for each effect)
func use(user: Node) -> void:
	if not user:
		push_warning("ConsumableItem: No user provided for item use")
		return
	
	# Apply each effect in order
	for effect in effects:
		if effect and effect.can_apply(user):
			effect.apply(user)
	
	# Legacy support - if no effects but legacy values set
	if effects.is_empty():
		if health_restore > 0 and user.has_method("heal"):
			user.heal(health_restore)
		if mana_restore > 0 and user.has_method("restore_mana"):
			user.restore_mana(mana_restore)

func get_tooltip_text() -> String:
	var text = super.get_tooltip_text()
	text += _format_section_header("Consumable", "lime")
	
	# Show effect tooltips
	for effect in effects:
		if effect:
			var effect_text = effect.get_tooltip_text()
			if effect_text:
				text += "\n" + effect_text
	
	# Legacy support
	if effects.is_empty():
		if health_restore > 0:
			text += _format_effect_line("+%d Health" % health_restore, "red")
		if mana_restore > 0:
			text += _format_effect_line("+%d Mana" % mana_restore, "cyan")
	
	return text

## Sync legacy properties to effects array (editor helper)
func _sync_legacy_effects() -> void:
	# Only sync if effects array is empty (don't override manually added effects)
	if not effects.is_empty():
		return
	# This is for editor convenience - actual migration should be done manually

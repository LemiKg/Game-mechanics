@tool
extends EditorPlugin
## Stat System editor plugin. Registers core types, then conditionally
## registers effects (which extend ItemEffect from inventory_system) only
## when the inventory_system addon is enabled.

func _enter_tree() -> void:
	# Core data resources.
	add_custom_type("StatDefinition", "Resource", preload("core/stat_definition.gd"), null)
	add_custom_type("StatModifier", "Resource", preload("core/stat_modifier.gd"), null)
	add_custom_type("StatFormula", "Resource", preload("core/stat_formula.gd"), null)
	add_custom_type("AdditivePercentFormula", "Resource", preload("core/additive_percent_formula.gd"), null)
	add_custom_type("BaseStatBlock", "Resource", preload("core/base_stat_block.gd"), null)
	add_custom_type("StatBlock", "Resource", preload("core/stat_block.gd"), null)

	# Runtime node.
	add_custom_type("StatComponent", "Node", preload("core/stat_component.gd"), null)

	# UI widgets.
	add_custom_type("StatBarUI", "Control", preload("ui/stat_bar_ui.gd"), null)
	add_custom_type("BuffBarUI", "Control", preload("ui/buff_bar_ui.gd"), null)

	# Conditional effect registration: gated by Task 14.
	_register_effects_if_inventory_enabled()

func _exit_tree() -> void:
	remove_custom_type("StatDefinition")
	remove_custom_type("StatModifier")
	remove_custom_type("StatFormula")
	remove_custom_type("AdditivePercentFormula")
	remove_custom_type("BaseStatBlock")
	remove_custom_type("StatBlock")
	remove_custom_type("StatComponent")
	remove_custom_type("StatBarUI")
	remove_custom_type("BuffBarUI")
	_unregister_effects_if_inventory_enabled()

func _register_effects_if_inventory_enabled() -> void:
	if not _inventory_addon_enabled():
		return
	add_custom_type("ResourceEffect", "Resource", preload("effects/resource_effect.gd"), null)
	add_custom_type("ApplyModifierEffect", "Resource", preload("effects/apply_modifier_effect.gd"), null)

func _unregister_effects_if_inventory_enabled() -> void:
	if not _inventory_addon_enabled():
		return
	remove_custom_type("ResourceEffect")
	remove_custom_type("ApplyModifierEffect")

func _inventory_addon_enabled() -> bool:
	# Detect by looking for the ItemEffect class. ClassDB.class_exists checks
	# core engine classes only, so use a path probe instead.
	return ResourceLoader.exists("res://addons/inventory_system/core/item_effect.gd")

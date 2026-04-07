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
	_unregister_effects_if_inventory_enabled()

# Filled in by Task 14.
func _register_effects_if_inventory_enabled() -> void:
	pass

func _unregister_effects_if_inventory_enabled() -> void:
	pass

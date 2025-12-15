@tool
extends EditorPlugin

func _enter_tree():
	# Core Abstract Base Classes
	add_custom_type("BaseInventory", "Resource", preload("core/base_inventory.gd"), preload("icons/inventory.svg"))
	add_custom_type("ItemEffect", "Resource", preload("core/item_effect.gd"), preload("icons/item.svg"))
	
	# Core Resources
	add_custom_type("InventoryItem", "Resource", preload("core/inventory_item.gd"), preload("icons/item.svg"))
	add_custom_type("EquipmentItem", "Resource", preload("core/equipment_item.gd"), preload("icons/item.svg"))
	add_custom_type("ConsumableItem", "Resource", preload("core/consumable_item.gd"), preload("icons/item.svg"))
	add_custom_type("ItemCategory", "Resource", preload("core/item_category.gd"), preload("icons/item.svg"))
	add_custom_type("Inventory", "Resource", preload("core/inventory.gd"), preload("icons/inventory.svg"))
	
	# Item Effects
	add_custom_type("HealEffect", "Resource", preload("core/heal_effect.gd"), preload("icons/item.svg"))
	add_custom_type("ManaEffect", "Resource", preload("core/mana_effect.gd"), preload("icons/item.svg"))
	
	# Core Nodes
	add_custom_type("InventoryComponent", "Node", preload("core/inventory_component.gd"), preload("icons/inventory.svg"))
	add_custom_type("EquipmentComponent", "Node", preload("core/equipment_component.gd"), preload("icons/inventory.svg"))
	add_custom_type("InventoryInteractionHandler", "Node", preload("core/inventory_interaction_handler.gd"), preload("icons/inventory.svg"))
	
	# UI Base Classes
	add_custom_type("BaseSlotUI", "Control", preload("ui/base_slot_ui.gd"), preload("icons/inventory.svg"))
	add_custom_type("BaseInventoryDisplay", "Control", preload("ui/base_inventory_display.gd"), preload("icons/inventory.svg"))
	add_custom_type("EquippableInventoryDisplay", "Control", preload("ui/equippable_inventory_display.gd"), preload("icons/inventory.svg"))

func _exit_tree():
	# Core Abstract Base Classes
	remove_custom_type("BaseInventory")
	remove_custom_type("ItemEffect")
	
	# Core Resources
	remove_custom_type("InventoryItem")
	remove_custom_type("EquipmentItem")
	remove_custom_type("ConsumableItem")
	remove_custom_type("ItemCategory")
	remove_custom_type("Inventory")
	
	# Item Effects
	remove_custom_type("HealEffect")
	remove_custom_type("ManaEffect")
	
	# Core Nodes
	remove_custom_type("InventoryComponent")
	remove_custom_type("EquipmentComponent")
	remove_custom_type("InventoryInteractionHandler")
	
	# UI Base Classes
	remove_custom_type("BaseSlotUI")
	remove_custom_type("BaseInventoryDisplay")
	remove_custom_type("EquippableInventoryDisplay")

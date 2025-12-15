extends Node3D

@onready var inventory_component = $InventoryComponent
@onready var equipment_component = $EquipmentComponent
@onready var inventory_ui = $CanvasLayer/InventoryUI
@onready var quick_inventory_ui = $CanvasLayer/QuickInventoryUI
@onready var instructions_label = $CanvasLayer/Instructions

func _ready():
	# Start with inventory hidden
	inventory_ui.visible = false
	
	# Add some starting items for testing
	call_deferred("_add_test_items")
	
	# Sync initial state
	instructions_label.visible = inventory_ui.visible
	quick_inventory_ui.visible = not inventory_ui.visible

func _add_test_items():
	# Configure inventory component hotbar size if needed
	if inventory_component.hotbar_inventory:
		inventory_component.hotbar_inventory.size = 6
	
	# Load items
	var health_potion = preload("res://items/health_potion.tres")
	var mana_potion = preload("res://items/mana_potion.tres")
	var gold_coin = preload("res://items/gold_coin.tres")
	var iron_helmet = preload("res://items/iron_helmet.tres")
	var iron_chestplate = preload("res://items/iron_chestplate.tres")
	var steel_sword = preload("res://items/steel_sword.tres")
	var leather_boots = preload("res://items/leather_boots.tres")
	
	# Add items to inventory
	inventory_component.add_item(health_potion, 5)
	inventory_component.add_item(mana_potion, 3)
	inventory_component.add_item(gold_coin, 50)
	inventory_component.add_item(iron_helmet, 1)
	inventory_component.add_item(iron_chestplate, 1)
	inventory_component.add_item(steel_sword, 1)
	inventory_component.add_item(leather_boots, 1)
	
	# Manually trigger UI refresh
	inventory_ui.refresh()
	inventory_ui.init_equipment_slots()
	
	print("Test items added to inventory!")

func _input(event):
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_I and not event.echo):
		inventory_ui.visible = not inventory_ui.visible
		instructions_label.visible = inventory_ui.visible
		quick_inventory_ui.visible = not inventory_ui.visible
		
		if inventory_ui.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			# If you have a player controller that captures mouse, you might want to capture it back
			# For this test scene, we'll just leave it visible or set to captured if needed
			# Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			pass

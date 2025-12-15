extends Node3D

@onready var inventory_component: Node = $InventoryComponent
@onready var equipment_component: Node = $EquipmentComponent
@onready var inventory_ui: Control = $CanvasLayer/InventoryUI

func _ready():
	# Connect UI to components
	inventory_ui.set_inventory(inventory_component)
	inventory_ui.set_equipment(equipment_component)
	
	# Add some starting items for testing
	_add_test_items()
	
	# Hide UI initially
	inventory_ui.visible = false

func _add_test_items():
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

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		inventory_ui.visible = not inventory_ui.visible
		
		# Toggle mouse capture for 3D games
		if inventory_ui.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

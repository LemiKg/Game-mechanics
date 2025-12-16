extends CharacterBody3D
## FPS test player script demonstrating FPSPlayerController3D integration with inventory UI.


@onready var player_controller: FPSPlayerController3D = $FPSPlayerController3D
@onready var inventory_component = $InventoryComponent
@onready var equipment_component = $EquipmentComponent
@onready var inventory_ui = $CanvasLayer/InventoryUI
@onready var quick_inventory_ui = $CanvasLayer/QuickInventoryUI
@onready var instructions_label = $CanvasLayer/Instructions


func _ready() -> void:
	# Start with gameplay enabled and inventory hidden
	inventory_ui.visible = false
	quick_inventory_ui.visible = true
	instructions_label.visible = false
	
	# Connect to mouse capture signal (let controller request, we apply)
	player_controller.mouse_capture_requested.connect(_on_mouse_capture_requested)
	
	# Start with mouse captured
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Add test items
	call_deferred("_add_test_items")


func _add_test_items() -> void:
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
	
	# Refresh UI
	inventory_ui.refresh()
	inventory_ui.init_equipment_slots()
	
	print("FPS Test: Items added to inventory!")


func _input(event: InputEvent) -> void:
	# Toggle inventory with I or Escape
	if event.is_action_pressed("ui_cancel") or _is_inventory_toggle(event):
		_toggle_inventory()


func _is_inventory_toggle(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and event.keycode == KEY_I and not event.echo


func _toggle_inventory() -> void:
	var opening: bool = not inventory_ui.visible
	
	inventory_ui.visible = opening
	instructions_label.visible = opening
	quick_inventory_ui.visible = not opening
	
	# Disable/enable gameplay through the controller
	player_controller.set_gameplay_enabled(not opening)


func _on_mouse_capture_requested(mode: Input.MouseMode) -> void:
	Input.set_mouse_mode(mode)

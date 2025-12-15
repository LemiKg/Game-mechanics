extends CharacterBody3D
## Dual perspective test player - can toggle between FPS and third-person.


@onready var player_controller: DualPerspectiveController3D = $DualPerspectiveController3D
@onready var inventory_component = $InventoryComponent
@onready var equipment_component = $EquipmentComponent
@onready var inventory_ui = $CanvasLayer/InventoryUI
@onready var quick_inventory_ui = $CanvasLayer/QuickInventoryUI
@onready var instructions_label = $CanvasLayer/Instructions
@onready var perspective_label = $CanvasLayer/PerspectiveLabel
@onready var hud_label = $CanvasLayer/HUD


func _ready() -> void:
	# Start with gameplay enabled and inventory hidden
	inventory_ui.visible = false
	quick_inventory_ui.visible = true
	instructions_label.visible = false
	
	# Connect to signals
	player_controller.mouse_capture_requested.connect(_on_mouse_capture_requested)
	player_controller.perspective_changed.connect(_on_perspective_changed)
	
	# Start with mouse captured
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Update perspective label
	_update_perspective_label()
	
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
	
	print("Dual Perspective Test: Items added to inventory!")


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
	
	# Hide HUD tips when inventory is open
	if hud_label:
		hud_label.visible = not opening
	if perspective_label:
		perspective_label.visible = not opening
	
	# Disable/enable gameplay through the controller
	player_controller.set_gameplay_enabled(not opening)


func _on_mouse_capture_requested(mode: Input.MouseMode) -> void:
	Input.set_mouse_mode(mode)


func _on_perspective_changed(is_first_person: bool) -> void:
	_update_perspective_label()


func _update_perspective_label() -> void:
	if perspective_label:
		var mode := "First Person" if player_controller.is_first_person() else "Third Person"
		perspective_label.text = "Perspective: %s (V to toggle)" % mode

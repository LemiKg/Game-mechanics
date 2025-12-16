extends CharacterBody3D
class_name ReusablePlayer
## Reusable player with dual perspective controls and inventory system.
## Drop this scene into any level to have a fully functional player.

## Emitted when the player's perspective changes
signal perspective_changed(is_first_person: bool)

## Emitted when inventory visibility changes
signal inventory_toggled(is_open: bool)

@onready var dual_controller: DualPerspectiveController3D = $DualPerspectiveController3D
@onready var inventory_component: InventoryComponent = $InventoryComponent
@onready var equipment_component: EquipmentComponent = $EquipmentComponent
@onready var inventory_ui = $CanvasLayer/InventoryUI
@onready var quick_inventory_ui = $CanvasLayer/QuickInventoryUI
@onready var perspective_label: Label = $CanvasLayer/PerspectiveLabel
@onready var hud_label: Label = $CanvasLayer/HUD

## Whether to add test items on ready (for debugging)
@export var add_test_items: bool = false

## Whether to show HUD labels
@export var show_hud: bool = true


func _ready() -> void:
	# Start with gameplay enabled and inventory hidden
	inventory_ui.visible = false
	quick_inventory_ui.visible = true
	
	# Apply HUD visibility setting
	if hud_label:
		hud_label.visible = show_hud
	if perspective_label:
		perspective_label.visible = show_hud
	
	# Connect to signals
	dual_controller.mouse_capture_requested.connect(_on_mouse_capture_requested)
	dual_controller.perspective_changed.connect(_on_perspective_changed)
	
	# Start with mouse captured
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Update perspective label
	_update_perspective_label()
	
	# Optionally add test items
	if add_test_items:
		call_deferred("_add_test_items")


func _add_test_items() -> void:
	# Load items if they exist
	var items_to_add := [
		["res://items/health_potion.tres", 5],
		["res://items/mana_potion.tres", 3],
		["res://items/gold_coin.tres", 50],
		["res://items/iron_helmet.tres", 1],
		["res://items/iron_chestplate.tres", 1],
		["res://items/steel_sword.tres", 1],
		["res://items/leather_boots.tres", 1],
	]
	
	for item_data in items_to_add:
		var path: String = item_data[0]
		var count: int = item_data[1]
		if ResourceLoader.exists(path):
			var item = load(path)
			inventory_component.add_item(item, count)
	
	# Refresh UI
	inventory_ui.refresh()
	inventory_ui.init_equipment_slots()
	
	print("Player: Test items added to inventory")


func _input(event: InputEvent) -> void:
	# Toggle inventory with I or Escape
	if event.is_action_pressed("ui_cancel") or _is_inventory_toggle(event):
		toggle_inventory()


func _is_inventory_toggle(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and event.keycode == KEY_I and not event.echo


## Toggles the inventory UI visibility
func toggle_inventory() -> void:
	var opening: bool = not inventory_ui.visible
	set_inventory_open(opening)


## Sets the inventory open state
func set_inventory_open(open: bool) -> void:
	inventory_ui.visible = open
	quick_inventory_ui.visible = not open
	
	# Hide HUD when inventory is open
	if hud_label:
		hud_label.visible = show_hud and not open
	if perspective_label:
		perspective_label.visible = show_hud and not open
	
	# Disable/enable gameplay through the controller
	dual_controller.set_gameplay_enabled(not open)
	
	inventory_toggled.emit(open)


## Returns whether the inventory is currently open
func is_inventory_open() -> bool:
	return inventory_ui.visible


## Returns whether the player is in first person mode
func is_first_person() -> bool:
	return dual_controller.is_first_person()


## Switches to first person perspective
func switch_to_first_person() -> void:
	dual_controller.switch_to_first_person()


## Switches to third person perspective
func switch_to_third_person() -> void:
	dual_controller.switch_to_third_person()


func _on_mouse_capture_requested(mode: Input.MouseMode) -> void:
	Input.set_mouse_mode(mode)


func _on_perspective_changed(is_first_person: bool) -> void:
	_update_perspective_label()
	perspective_changed.emit(is_first_person)


func _update_perspective_label() -> void:
	if perspective_label:
		var mode := "First Person" if dual_controller.is_first_person() else "Third Person"
		perspective_label.text = "Perspective: %s" % mode

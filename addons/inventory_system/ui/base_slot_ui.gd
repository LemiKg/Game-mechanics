extends Control
class_name BaseSlotUI
## Abstract base class for slot UIs.
## Handles common logic like drag preview generation and tooltip signals.

## Emitted when mouse enters/exits to show/hide tooltip
signal tooltip_requested(item: InventoryItem, show: bool)

@export var icon_texture: TextureRect

var item: Resource = null

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	if item:
		tooltip_requested.emit(item, true)

func _on_mouse_exited():
	tooltip_requested.emit(null, false)

func _get_drag_data(at_position):
	if not item:
		return null
		
	var preview = TextureRect.new()
	preview.texture = item.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(40, 40)
	set_drag_preview(preview)
	
	return _get_drag_data_payload()

## Virtual method to be overridden by subclasses
func _get_drag_data_payload() -> Dictionary:
	return {}

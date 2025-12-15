extends PanelContainer
class_name ItemTooltipUI
## Custom tooltip panel that displays item details using BBCode.
## Follows the mouse cursor when visible.

@export var label: RichTextLabel
@export var offset: Vector2 = Vector2(16, 16)

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ensure tooltip renders on top
	z_index = 100

func _process(_delta):
	if visible:
		_follow_mouse()

func _follow_mouse():
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport_rect().size
	var tooltip_size = size
	
	# Position tooltip near cursor, keeping within viewport bounds
	var pos = mouse_pos + offset
	
	# Flip horizontally if would go off right edge
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tooltip_size.x - offset.x
	
	# Flip vertically if would go off bottom edge
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tooltip_size.y - offset.y
	
	# Clamp to viewport
	pos.x = clamp(pos.x, 0, viewport_size.x - tooltip_size.x)
	pos.y = clamp(pos.y, 0, viewport_size.y - tooltip_size.y)
	
	global_position = pos

## Show tooltip with the given item's information
func show_item(item: InventoryItem) -> void:
	if item:
		label.text = item.get_tooltip_text()
		# Reset size to fit content
		reset_size()
		visible = true
	else:
		hide_tooltip()

## Hide the tooltip
func hide_tooltip() -> void:
	visible = false

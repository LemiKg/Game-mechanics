extends Node
class_name TooltipController
## Reusable controller for managing item tooltips.
## Add as child to any UI that needs tooltip functionality.
## Call connect_slot() when creating slot UIs to wire up signals.

@export var tooltip_ui: ItemTooltipUI

## Connect a SlotUI or EquipmentSlotUI to this tooltip controller
func connect_slot(slot: Control) -> void:
	if slot.has_signal("tooltip_requested"):
		if not slot.tooltip_requested.is_connected(_on_tooltip_requested):
			slot.tooltip_requested.connect(_on_tooltip_requested)

## Disconnect a slot (useful when slots are being freed)
func disconnect_slot(slot: Control) -> void:
	if slot.has_signal("tooltip_requested"):
		if slot.tooltip_requested.is_connected(_on_tooltip_requested):
			slot.tooltip_requested.disconnect(_on_tooltip_requested)

## Show tooltip for an item
func show_tooltip(item: InventoryItem) -> void:
	if tooltip_ui and item:
		tooltip_ui.show_item(item)

## Hide the tooltip
func hide_tooltip() -> void:
	if tooltip_ui:
		tooltip_ui.hide_tooltip()

func _on_tooltip_requested(item: InventoryItem, show: bool) -> void:
	if show and item:
		show_tooltip(item)
	else:
		hide_tooltip()

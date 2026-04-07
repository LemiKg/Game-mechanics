extends Control
class_name BuffBarUI
## Displays the active timed modifiers as a horizontal row of icon + countdown.
## Permanent modifiers (duration < 0) are filtered out — equipment bonuses
## don't belong in a buff bar.
##
## Bind by setting `stat_component`. The widget connects to the StatReader's
## modifier_added / modifier_removed signals.

@export var stat_component: StatComponent
@export var icon_size: int = 32
@export var spacing: int = 4
@export var show_countdown_label: bool = true

# Looked up in _ready. Tests can inject directly.
var _row: HBoxContainer

var _reader: StatReader
var _slots: Dictionary = {}              # StatModifier -> child PanelContainer
var _running: Array[StatModifier] = []   # mirrors _slots keys for tick

func _ready() -> void:
	_row = get_node_or_null("HBoxContainer") as HBoxContainer
	if _row == null:
		push_warning("BuffBarUI: no HBoxContainer child found on '%s'" % name)
		return
	_row.add_theme_constant_override("separation", spacing)
	_bind()

## Public setter so consumers can swap the data source at runtime.
func set_stat_component(c: StatComponent) -> void:
	stat_component = c
	if is_inside_tree():
		_bind()

func _bind() -> void:
	if not stat_component:
		return
	# Disconnect old reader if any.
	if _reader:
		if _reader.modifier_added.is_connected(_on_modifier_added):
			_reader.modifier_added.disconnect(_on_modifier_added)
		if _reader.modifier_removed.is_connected(_on_modifier_removed):
			_reader.modifier_removed.disconnect(_on_modifier_removed)
	_reader = stat_component.get_reader()
	_reader.modifier_added.connect(_on_modifier_added)
	_reader.modifier_removed.connect(_on_modifier_removed)
	_refresh_all()

func _refresh_all() -> void:
	if _row == null:
		return
	for child in _row.get_children():
		child.queue_free()
	_slots.clear()
	_running.clear()
	for m in _reader.get_active_modifiers():
		if m == null or m.duration < 0.0:
			continue
		_add_slot(m)

func _on_modifier_added(m: StatModifier) -> void:
	if m == null or m.duration < 0.0:
		return
	_add_slot(m)

func _on_modifier_removed(m: StatModifier, _reason: int) -> void:
	if m == null:
		return
	var node = _slots.get(m)
	if node:
		node.queue_free()
		_slots.erase(m)
		_running.erase(m)

func _process(_delta: float) -> void:
	if not show_countdown_label:
		return
	# Cheap re-render of countdown labels. We do not need a per-frame signal —
	# remaining is updated by StatBlock.tick() and we just read it.
	# Iterate a snapshot in case a modifier expires mid-frame and triggers
	# _on_modifier_removed (which mutates _running).
	for m in _running.duplicate():
		var node = _slots.get(m)
		if node:
			var label: Label = node.get_node_or_null("Label")
			if label:
				label.text = "%ds" % int(ceil(m.remaining))

func _add_slot(m: StatModifier) -> void:
	if _row == null:
		return
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(icon_size, icon_size)
	var icon := TextureRect.new()
	icon.texture = m.icon
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)
	if show_countdown_label:
		var label := Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		# Use remaining (not duration) so a modifier added mid-life shows
		# the correct countdown immediately rather than flickering on next frame.
		label.text = "%ds" % int(ceil(m.remaining))
		slot.add_child(label)
	_row.add_child(slot)
	_slots[m] = slot
	_running.append(m)

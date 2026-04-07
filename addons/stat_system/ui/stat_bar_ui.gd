extends Control
class_name StatBarUI
## Displays one resource stat as a filled bar with optional overlay text.
## Binds to a StatComponent + stat_id; refreshes via the StatReader's
## stat_changed signal.
##
## The scene file `stat_bar_ui.tscn` provides a default ProgressBar + Label
## hierarchy. Authors can replace either child node in their own scene as
## long as the names "ProgressBar" and "Label" are preserved (the script
## looks them up by name in `_ready`). Missing children produce a warning
## and a no-op render rather than a crash.

@export var stat_component: StatComponent
@export var stat_id: StringName = &"health"
@export var show_label: bool = true
@export var label_format: String = "%d / %d"

# These are looked up in _ready. Tests can inject them directly.
var _bar: ProgressBar
var _label: Label

var _reader: StatReader

func _ready() -> void:
	_bar = get_node_or_null("ProgressBar") as ProgressBar
	_label = get_node_or_null("Label") as Label
	if _bar == null:
		push_warning("StatBarUI: no ProgressBar child found on '%s'" % name)
	if _label == null:
		push_warning("StatBarUI: no Label child found on '%s'" % name)
	else:
		_label.visible = show_label
	_bind()

## Public setter so consumers can swap the data source at runtime.
func set_stat_component(c: StatComponent) -> void:
	stat_component = c
	if is_inside_tree():
		_bind()

func _bind() -> void:
	if not stat_component:
		return
	# Disconnect from any previous reader.
	if _reader and _reader.stat_changed.is_connected(_on_stat_changed):
		_reader.stat_changed.disconnect(_on_stat_changed)
	_reader = stat_component.get_reader()
	_reader.stat_changed.connect(_on_stat_changed)

	# Validate that the bound stat is a resource. Flat stats render as empty
	# and emit a warning so authoring mistakes surface immediately.
	var def := _find_definition()
	if def == null:
		push_warning("StatBarUI: stat_id '%s' not found in stat block" % stat_id)
	elif not def.is_resource:
		push_warning("StatBarUI: stat_id '%s' is a flat stat, not a resource — bar will read 0" % stat_id)
	elif def.color != Color.WHITE and _bar != null:
		_bar.modulate = def.color

	_refresh()

func _find_definition() -> StatDefinition:
	if not stat_component or not stat_component.stat_block:
		return null
	for d in stat_component.stat_block.definitions:
		if d != null and d.id == stat_id:
			return d
	return null

func _on_stat_changed(id: StringName, _old: float, _new: float) -> void:
	if id == stat_id:
		_refresh()

func _refresh() -> void:
	if not _reader or _bar == null:
		return
	var def := _find_definition()
	# Flat stat or unknown stat — render empty.
	if def == null or not def.is_resource:
		_bar.value = 0.0
		if show_label and _label != null:
			_label.text = label_format % [0, 0]
		return

	var current := _reader.get_current(stat_id)
	var max_v := _reader.get_max(stat_id)
	if max_v <= 0.0:
		_bar.value = 0.0
	else:
		_bar.value = current / max_v
	if show_label and _label != null:
		_label.text = label_format % [int(current), int(max_v)]

@tool
extends CanvasLayer
class_name DebugOverlayUI
## Debug overlay showing FPS, chunk statistics, and other performance info.
## Toggle visibility with F3 (configurable via toggle_action).

## The ChunkManager to read stats from
@export var chunk_manager: ChunkManager

## Input action name for toggling visibility (default: F3 key)
@export var toggle_action: String = ""

## Update interval in seconds (lower = more CPU usage)
@export var update_interval: float = 0.25

## Show memory usage (can be slow on some systems)
@export var show_memory: bool = true

## Text color for the overlay
@export var text_color: Color = Color.WHITE

## Background color for readability
@export var background_color: Color = Color(0, 0, 0, 0.6)

var _label: Label
var _panel: Panel
var _time_since_update: float = 0.0
var _frame_count: int = 0
var _fps_accumulator: float = 0.0
var _visible: bool = true


func _ready() -> void:
	layer = 100 # Render on top of everything
	_setup_ui()
	
	# Only respond to input at runtime
	if Engine.is_editor_hint():
		visible = false


func _setup_ui() -> void:
	# Create background panel
	_panel = Panel.new()
	_panel.name = "Panel"
	
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	
	add_child(_panel)
	
	# Create label
	_label = Label.new()
	_label.name = "StatsLabel"
	_label.add_theme_color_override("font_color", text_color)
	_label.text = "FPS: --"
	_label.position = Vector2(8, 4)
	
	_panel.add_child(_label)
	
	# Position in top-left corner
	_panel.position = Vector2(10, 10)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Handle toggle input
	_handle_input()
	
	if not _visible:
		return
	
	# Accumulate frame timing
	_frame_count += 1
	_fps_accumulator += delta
	_time_since_update += delta
	
	if _time_since_update >= update_interval:
		_update_stats()
		_time_since_update = 0.0


func _handle_input() -> void:
	# Check custom action or default F3
	var toggle_pressed := false
	
	if toggle_action != "" and InputMap.has_action(toggle_action):
		toggle_pressed = Input.is_action_just_pressed(toggle_action)
	else:
		toggle_pressed = Input.is_key_pressed(KEY_F3) and _is_key_just_pressed(KEY_F3)
	
	if toggle_pressed:
		_visible = not _visible
		_panel.visible = _visible


var _f3_was_pressed: bool = false

func _is_key_just_pressed(key: Key) -> bool:
	var pressed := Input.is_key_pressed(key)
	var just_pressed := pressed and not _f3_was_pressed
	_f3_was_pressed = pressed
	return just_pressed


func _update_stats() -> void:
	var lines: PackedStringArray = []
	
	# FPS
	var avg_fps: float = 0.0
	if _fps_accumulator > 0:
		avg_fps = float(_frame_count) / _fps_accumulator
	lines.append("FPS: %d" % int(avg_fps))
	
	# Frame time
	var frame_time_ms: float = 1000.0 / max(avg_fps, 1.0)
	lines.append("Frame: %.2f ms" % frame_time_ms)
	
	# Reset accumulators
	_frame_count = 0
	_fps_accumulator = 0.0
	
	# Chunk stats
	if chunk_manager:
		lines.append("")
		lines.append("Chunks: %d active" % chunk_manager.get_active_chunk_count())
		lines.append("Pool: %d cached" % chunk_manager.get_pool_size())
		
		var collision_count := chunk_manager.get_collision_chunk_count()
		if collision_count > 0:
			lines.append("Collision: %d chunks" % collision_count)
	
	# Memory (optional, can be slow)
	if show_memory:
		lines.append("")
		var mem_static := Performance.get_monitor(Performance.MEMORY_STATIC)
		var mem_static_mb := mem_static / 1048576.0
		lines.append("Memory: %.1f MB" % mem_static_mb)
		
		var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
		lines.append("Objects: %d" % int(objects))
	
	# Renderer stats
	lines.append("")
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	lines.append("Draw calls: %d" % int(draw_calls))
	lines.append("Triangles: %dk" % int(primitives / 1000))
	
	_label.text = "\n".join(lines)
	
	# Resize panel to fit content
	_panel.size = _label.size + Vector2(16, 8)

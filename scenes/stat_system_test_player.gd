extends Node3D
## Manual test player for the stat system. Bound keys:
##   1 = damage 10 health
##   2 = spend 15 mana
##   3 = spend 25 stamina
##   4 = apply 5-second +5 attack buff
##   5 = apply 10-second -3 defense debuff
##   R = reset all resources to full
##
## Uses raw KEY_* checks via _input — no project input map setup required.

@export var stat_component: StatComponent

func _ready() -> void:
	# Auto-bind to a child StatComponent if not explicitly set in the editor.
	if stat_component == null:
		stat_component = get_node_or_null("StatComponent") as StatComponent
	# Auto-bind every StatBarUI/BuffBarUI in the scene's HUD to this component.
	# Walks the root scene for any widget that needs a binding.
	var root := get_tree().current_scene
	if root:
		_auto_bind_widgets(root)

func _auto_bind_widgets(node: Node) -> void:
	if node is StatBarUI and (node as StatBarUI).stat_component == null:
		(node as StatBarUI).set_stat_component(stat_component)
	elif node is BuffBarUI and (node as BuffBarUI).stat_component == null:
		(node as BuffBarUI).set_stat_component(stat_component)
	for child in node.get_children():
		_auto_bind_widgets(child)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not stat_component:
		return

	match event.keycode:
		KEY_1:
			stat_component.modify_resource(&"health", -10.0)
		KEY_2:
			stat_component.modify_resource(&"mana", -15.0)
		KEY_3:
			stat_component.modify_resource(&"stamina", -25.0)
		KEY_4:
			_apply_buff(&"attack", 5.0, 5.0)
		KEY_5:
			_apply_buff(&"defense", -3.0, 10.0)
		KEY_R:
			_reset_all()

func _apply_buff(stat_id: StringName, value: float, duration: float) -> void:
	var m := StatModifier.new()
	m.stat_id = stat_id
	m.op = StatModifier.Op.FLAT
	m.value = value
	m.duration = duration
	m.source_id = StringName("test_buff_%d" % Time.get_ticks_msec())
	stat_component.add_modifier(m)

func _reset_all() -> void:
	for def in stat_component.stat_block.definitions:
		if def != null and def.is_resource:
			stat_component.set_current(def.id, stat_component.get_max(def.id))

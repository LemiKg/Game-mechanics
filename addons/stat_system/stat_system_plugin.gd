@tool
extends EditorPlugin
## Stat System editor plugin. Registers core types in _enter_tree.
## Effects in addons/stat_system/effects/ are gated to load only when
## the inventory_system addon is enabled (they extend ItemEffect).

func _enter_tree() -> void:
	# Custom-type registration is filled in by Task 13 (core) and Task 14 (effects).
	pass

func _exit_tree() -> void:
	pass

@tool
extends EditorPlugin
## EditorPlugin for the Procedural World addon.
## Registers all custom types for use in the editor.


func _enter_tree() -> void:
	# Configuration Resources
	add_custom_type(
		"WorldConfig",
		"Resource",
		preload("core/world_config.gd"),
		preload("icons/world.svg")
	)
	add_custom_type(
		"ChunkData",
		"Resource",
		preload("core/chunk_data.gd"),
		preload("icons/chunk.svg")
	)
	
	# Runtime Nodes
	add_custom_type(
		"ChunkManager",
		"Node",
		preload("core/chunk_manager.gd"),
		preload("icons/world.svg")
	)
	add_custom_type(
		"TerrainChunk",
		"Node3D",
		preload("core/terrain_chunk.gd"),
		preload("icons/chunk.svg")
	)
	
	# UI Components
	add_custom_type(
		"DebugOverlayUI",
		"CanvasLayer",
		preload("ui/debug_overlay_ui.gd"),
		preload("icons/world.svg")
	)


func _exit_tree() -> void:
	# Remove in reverse order
	remove_custom_type("DebugOverlayUI")
	remove_custom_type("TerrainChunk")
	remove_custom_type("ChunkManager")
	remove_custom_type("ChunkData")
	remove_custom_type("WorldConfig")

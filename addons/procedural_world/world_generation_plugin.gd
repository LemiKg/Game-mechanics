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
	
	# Biome Resources
	add_custom_type(
		"BiomeData",
		"Resource",
		preload("core/biome_data.gd"),
		preload("icons/biome.svg")
	)
	add_custom_type(
		"BiomeMap",
		"Resource",
		preload("core/biome_map.gd"),
		preload("icons/biome.svg")
	)
	add_custom_type(
		"PlainsBiome",
		"Resource",
		preload("core/biomes/plains_biome.gd"),
		preload("icons/biome.svg")
	)
	add_custom_type(
		"ForestBiome",
		"Resource",
		preload("core/biomes/forest_biome.gd"),
		preload("icons/biome.svg")
	)
	add_custom_type(
		"MountainBiome",
		"Resource",
		preload("core/biomes/mountain_biome.gd"),
		preload("icons/biome.svg")
	)
	add_custom_type(
		"DesertBiome",
		"Resource",
		preload("core/biomes/desert_biome.gd"),
		preload("icons/biome.svg")
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
	
	# Decoration/Vegetation System (Phase 4)
	add_custom_type(
		"DecorationDefinition",
		"Resource",
		preload("core/decoration_definition.gd"),
		preload("icons/biome.svg")
	)
	add_custom_type(
		"DecorationMeshBuilder",
		"RefCounted",
		preload("core/decoration_mesh_builder.gd"),
		preload("icons/chunk.svg")
	)
	add_custom_type(
		"AsyncGenerationHandler",
		"Node",
		preload("core/async_generation_handler.gd"),
		preload("icons/world.svg")
	)
	add_custom_type(
		"VegetationSpawner",
		"Node",
		preload("core/vegetation_spawner.gd"),
		preload("icons/biome.svg")
	)


func _exit_tree() -> void:
	# Remove in reverse order
	remove_custom_type("VegetationSpawner")
	remove_custom_type("AsyncGenerationHandler")
	remove_custom_type("DecorationMeshBuilder")
	remove_custom_type("DecorationDefinition")
	remove_custom_type("DebugOverlayUI")
	remove_custom_type("TerrainChunk")
	remove_custom_type("ChunkManager")
	remove_custom_type("DesertBiome")
	remove_custom_type("MountainBiome")
	remove_custom_type("ForestBiome")
	remove_custom_type("PlainsBiome")
	remove_custom_type("BiomeMap")
	remove_custom_type("BiomeData")
	remove_custom_type("ChunkData")
	remove_custom_type("WorldConfig")

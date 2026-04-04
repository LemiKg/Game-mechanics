class_name WorldItemSpawner
extends Node3D
## Spawns WorldItem pickups in the world for testing/gameplay.
##
## Place in a scene and configure items to spawn. Items are placed
## at random positions within spawn_radius of this node.


@export_group("Spawning")
## Items to spawn with quantities.
@export var spawn_entries: Array[SpawnEntry] = []

## Radius around this node to scatter items.
@export_range(1.0, 50.0, 0.5) var spawn_radius: float = 10.0

## Whether to spawn on _ready.
@export var spawn_on_ready: bool = true

## Collision shape radius for pickup detection.
@export_range(0.5, 5.0, 0.1) var pickup_radius: float = 1.5

## Collision layer for the pickup area (must match player's mask).
@export_flags_3d_physics var collision_layer: int = 1

## Collision mask to detect player.
@export_flags_3d_physics var collision_mask: int = 1


func _ready() -> void:
	if spawn_on_ready:
		# Defer to let terrain generate first
		get_tree().create_timer(2.0).timeout.connect(spawn_all)


## Spawn all configured items.
func spawn_all() -> void:
	for entry in spawn_entries:
		if entry and entry.item:
			for i in range(entry.count):
				spawn_item(entry.item, entry.amount_per_pickup, entry.auto_pickup)


## Spawn a single WorldItem at a random position within radius.
func spawn_item(item: InventoryItem, amount: int = 1, auto_pickup: bool = false) -> WorldItem:
	var world_item := WorldItem.new()
	world_item.item = item
	world_item.amount = amount
	world_item.auto_pickup = auto_pickup

	# Random position within radius, raycast down to find terrain
	var angle := randf() * TAU
	var dist := randf() * spawn_radius
	var world_x := global_position.x + cos(angle) * dist
	var world_z := global_position.z + sin(angle) * dist
	var ray_origin := Vector3(world_x, global_position.y + 50.0, world_z)
	var ground_y := global_position.y

	# Raycast to find terrain surface
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(
			ray_origin, ray_origin + Vector3.DOWN * 200.0
		)
		var result := space_state.intersect_ray(query)
		if result:
			ground_y = result.position.y

	# Add collision shape for pickup detection
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	collision.shape = sphere
	world_item.add_child(collision)

	world_item.collision_layer = collision_layer
	world_item.collision_mask = collision_mask
	world_item.monitorable = false
	world_item.monitoring = true

	add_child(world_item)
	world_item.global_position = Vector3(world_x, ground_y + 0.5, world_z)
	return world_item


## Spawn a single item at a specific position.
func spawn_item_at(item: InventoryItem, pos: Vector3, amount: int = 1) -> WorldItem:
	var world_item := spawn_item(item, amount)
	world_item.position = pos - global_position
	return world_item

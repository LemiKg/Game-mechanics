@tool
class_name SpawnEntry
extends Resource
## Configuration for a single item type to spawn in the world.


## The item to spawn.
@export var item: InventoryItem

## How many pickups of this item to scatter.
@export_range(1, 50, 1) var count: int = 1

## Amount per pickup (stack size).
@export_range(1, 99, 1) var amount_per_pickup: int = 1

## Auto-pickup when player walks over.
@export var auto_pickup: bool = false

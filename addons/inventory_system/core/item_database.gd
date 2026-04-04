extends Node
## Autoload singleton that maps item IDs to InventoryItem Resources.
##
## Scans the items directory on startup and registers all .tres files.
## Used by the save/load system to look up items by ID.


## Directory to scan for item .tres files.
@export var items_directory: String = "res://items/"

## Registered items: id → InventoryItem
var _items: Dictionary = {}


func _ready() -> void:
	_scan_items(items_directory)


## Get an item by its ID. Returns null if not found.
func get_item(id: String) -> InventoryItem:
	return _items.get(id)


## Register an item manually (for runtime-created items).
func register_item(item: InventoryItem) -> void:
	if item.id == "":
		push_warning("ItemDatabase: Cannot register item with empty ID")
		return
	_items[item.id] = item


## Check if an item ID exists.
func has_item(id: String) -> bool:
	return _items.has(id)


## Get all registered item IDs.
func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _items.keys():
		ids.append(key as String)
	return ids


## Scan a directory recursively for .tres files containing InventoryItem resources.
func _scan_items(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_warning("ItemDatabase: Could not open directory '%s'" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_items(full_path)
		elif file_name.ends_with(".tres"):
			var resource := ResourceLoader.load(full_path)
			if resource is InventoryItem:
				if resource.id != "":
					_items[resource.id] = resource
				else:
					push_warning("ItemDatabase: Item at '%s' has no ID set" % full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

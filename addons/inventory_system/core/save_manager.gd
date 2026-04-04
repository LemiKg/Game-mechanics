class_name SaveManager
extends RefCounted
## Static utility for saving and loading inventory state to JSON files.


## Save inventory and equipment state to a JSON file.
static func save_inventory(path: String, inventory_comp: InventoryComponent, equipment_comp: EquipmentComponent) -> bool:
	var data := {}

	if inventory_comp:
		data["main_inventory"] = inventory_comp.main_inventory.serialize() if inventory_comp.main_inventory else {}
		data["hotbar_inventory"] = inventory_comp.hotbar_inventory.serialize() if inventory_comp.hotbar_inventory else {}

	if equipment_comp:
		data["equipment"] = equipment_comp.serialize()

	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Could not open '%s' for writing" % path)
		return false

	file.store_string(json_string)
	file.close()
	return true


## Load inventory and equipment state from a JSON file.
static func load_inventory(path: String, inventory_comp: InventoryComponent, equipment_comp: EquipmentComponent) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: File '%s' not found" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SaveManager: Could not open '%s' for reading" % path)
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("SaveManager: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var data: Dictionary = json.data

	if inventory_comp:
		if data.has("main_inventory") and inventory_comp.main_inventory:
			inventory_comp.main_inventory.deserialize(data["main_inventory"])
		if data.has("hotbar_inventory") and inventory_comp.hotbar_inventory:
			inventory_comp.hotbar_inventory.deserialize(data["hotbar_inventory"])

	if equipment_comp:
		if data.has("equipment"):
			equipment_comp.deserialize(data["equipment"])

	return true

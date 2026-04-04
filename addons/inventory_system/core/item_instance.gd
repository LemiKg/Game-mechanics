class_name ItemInstance
extends RefCounted
## Per-item mutable state for non-stackable items (equipment).
##
## Wraps an InventoryItem definition with instance-specific data like
## durability, upgrade level, and (future) random affixes.
## Only created for items with max_stack == 1.


## The shared item definition this instance is based on.
var definition: InventoryItem

## Current durability. -1 means no durability system.
var durability: float = -1.0

## Maximum durability (copied from definition on creation).
var max_durability: float = -1.0

## Random stat modifiers (populated by loot generation in Phase 2).
var affixes: Array[Resource] = []

## Upgrade level (+0, +1, +2, etc.).
var upgrade_level: int = 0

## Custom display name (empty = use definition.name).
var custom_name: String = ""

## Unique instance ID for save/load (auto-generated).
var instance_id: String = ""


func _init(p_definition: InventoryItem = null) -> void:
	definition = p_definition
	instance_id = _generate_id()
	if definition and "max_durability" in definition and definition.max_durability > 0:
		max_durability = definition.max_durability
		durability = max_durability


## Get the display name (custom name or definition name with upgrade level).
func get_display_name() -> String:
	var base_name := custom_name if custom_name != "" else (definition.name if definition else "Unknown")
	if upgrade_level > 0:
		return "%s +%d" % [base_name, upgrade_level]
	return base_name


## Get durability as a ratio (0.0 to 1.0). Returns 1.0 if no durability.
func get_durability_ratio() -> float:
	if max_durability <= 0:
		return 1.0
	return clampf(durability / max_durability, 0.0, 1.0)


## Whether this item has durability tracking.
func has_durability() -> bool:
	return max_durability > 0


## Reduce durability by amount. Returns true if item broke (durability <= 0).
func degrade(amount: float = 1.0) -> bool:
	if not has_durability():
		return false
	durability = maxf(0.0, durability - amount)
	return durability <= 0.0


## Repair to full durability.
func repair() -> void:
	if has_durability():
		durability = max_durability


## Serialize to Dictionary for save/load.
func serialize() -> Dictionary:
	var data := {
		"instance_id": instance_id,
		"item_id": definition.id if definition else "",
		"upgrade_level": upgrade_level,
	}
	if has_durability():
		data["durability"] = durability
		data["max_durability"] = max_durability
	if custom_name != "":
		data["custom_name"] = custom_name
	return data


## Deserialize from Dictionary. Requires ItemDatabase for definition lookup.
static func from_dict(data: Dictionary, item_db: Node) -> ItemInstance:
	var def: InventoryItem = null
	if item_db and item_db.has_method("get_item"):
		def = item_db.get_item(data.get("item_id", ""))
	var inst := ItemInstance.new(def)
	inst.instance_id = data.get("instance_id", inst.instance_id)
	inst.upgrade_level = data.get("upgrade_level", 0)
	inst.custom_name = data.get("custom_name", "")
	if data.has("durability"):
		inst.durability = data["durability"]
		inst.max_durability = data.get("max_durability", inst.max_durability)
	return inst


func _generate_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi()]

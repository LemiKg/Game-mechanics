# Inventory Overhaul Phase 1: Core Architecture

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ItemInstance layer, rarity system, stat aggregation, weight tracking, and save/load serialization to the inventory system.

**Architecture:** ItemInstance (RefCounted) wraps per-item mutable state for equipment. Rarity enum on InventoryItem with color-coded tooltips/borders. EquipmentComponent aggregates stats. BaseInventory tracks weight. ItemDatabase autoload maps IDs to Resources for serialization.

**Tech Stack:** GDScript, Godot 4.5

**Spec:** `docs/superpowers/specs/2026-04-04-inventory-overhaul-phase1-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `addons/inventory_system/core/item_instance.gd` | Create | Per-item mutable state (durability, upgrades) |
| `addons/inventory_system/core/item_database.gd` | Create | Autoload: ID → InventoryItem lookup |
| `addons/inventory_system/core/save_manager.gd` | Create | Static serialize/deserialize utilities |
| `addons/inventory_system/core/inventory_item.gd` | Modify | Rarity enum, color constants, tooltip coloring |
| `addons/inventory_system/core/equipment_item.gd` | Modify | max_durability export |
| `addons/inventory_system/core/inventory_slot.gd` | Modify | Optional instance field |
| `addons/inventory_system/core/base_inventory.gd` | Modify | Weight tracking |
| `addons/inventory_system/core/inventory.gd` | Modify | Auto-create instances, weight emit, serialize/deserialize |
| `addons/inventory_system/core/equipment_component.gd` | Modify | Stat aggregation, serialize/deserialize |
| `addons/inventory_system/ui/slot_ui.gd` | Modify | Rarity border tint |
| `addons/inventory_system/inventory_plugin.gd` | Modify | Register new types |
| `project.godot` | Modify | ItemDatabase autoload |

---

### Task 1: Create ItemInstance

**Files:**
- Create: `addons/inventory_system/core/item_instance.gd`

- [ ] **Step 1: Create the ItemInstance file**

```gdscript
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
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/item_instance.gd
git commit -m "feat: add ItemInstance for per-item mutable state (durability, upgrades)"
```

---

### Task 2: Add Rarity to InventoryItem

**Files:**
- Modify: `addons/inventory_system/core/inventory_item.gd`

- [ ] **Step 1: Read the file and add rarity enum, export, colors, and tooltip coloring**

Read `addons/inventory_system/core/inventory_item.gd`. Add the rarity system.

After `class_name InventoryItem` (line 3), add the enum and color constants:

```gdscript

## Item rarity tier, affects tooltip color and slot border.
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

## Rarity color mapping for UI display.
const RARITY_COLORS := {
	Rarity.COMMON: Color.WHITE,
	Rarity.UNCOMMON: Color(0.3, 0.8, 0.3),
	Rarity.RARE: Color(0.4, 0.6, 1.0),
	Rarity.EPIC: Color(0.7, 0.4, 0.9),
	Rarity.LEGENDARY: Color(1.0, 0.6, 0.2),
}

const RARITY_NAMES := {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Epic",
	Rarity.LEGENDARY: "Legendary",
}
```

After the `id` export (line 17), add:

```gdscript

## Item rarity tier.
@export var rarity: Rarity = Rarity.COMMON
```

In `get_tooltip_text()`, replace the first line `var text = "[b]%s[/b]" % name` with:

```gdscript
	var rarity_color := RARITY_COLORS.get(rarity, Color.WHITE)
	var color_hex := rarity_color.to_html(false)
	var text = "[b][color=#%s]%s[/color][/b]" % [color_hex, name]
	if rarity != Rarity.COMMON:
		text += "\n[color=#%s]%s[/color]" % [color_hex, RARITY_NAMES.get(rarity, "")]
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/inventory_item.gd
git commit -m "feat: add rarity system to InventoryItem with color-coded tooltips"
```

---

### Task 3: Add max_durability to EquipmentItem

**Files:**
- Modify: `addons/inventory_system/core/equipment_item.gd`

- [ ] **Step 1: Read and add max_durability export**

Read `addons/inventory_system/core/equipment_item.gd`. After `@export var stats: Dictionary = {}` (line 12), add:

```gdscript

## Maximum durability for this equipment. 0 = no durability tracking.
@export_range(0, 1000, 1) var max_durability: int = 0
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/equipment_item.gd
git commit -m "feat: add max_durability export to EquipmentItem"
```

---

### Task 4: Add instance field to InventorySlot

**Files:**
- Modify: `addons/inventory_system/core/inventory_slot.gd`

- [ ] **Step 1: Read and add instance field**

Read `addons/inventory_system/core/inventory_slot.gd`. Replace the entire file with:

```gdscript
@tool
extends Resource
class_name InventorySlot

## The item in this slot (InventoryItem resource)
@export var item: InventoryItem
@export var amount: int = 0

## Per-item instance data (only for non-stackable items like equipment).
## Null for stackable items.
var instance: ItemInstance

func _init(p_item: InventoryItem = null, p_amount: int = 0) -> void:
	item = p_item
	amount = p_amount

func is_empty() -> bool:
	return item == null or amount <= 0

func can_add(p_item: InventoryItem, p_amount: int) -> bool:
	if is_empty():
		return true
	if item == p_item and amount + p_amount <= item.max_stack:
		return true
	return false

## Clear the slot completely.
func clear() -> void:
	item = null
	amount = 0
	instance = null
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/inventory_slot.gd
git commit -m "feat: add optional ItemInstance field to InventorySlot"
```

---

### Task 5: Add Weight Tracking to BaseInventory

**Files:**
- Modify: `addons/inventory_system/core/base_inventory.gd`

- [ ] **Step 1: Read and add weight tracking**

Read `addons/inventory_system/core/base_inventory.gd`. Add after the `inventory_updated` signal:

```gdscript

signal weight_changed(current: float, maximum: float)
```

Add after `allowed_categories` export:

```gdscript

## Maximum weight capacity. 0 = unlimited (backwards compatible).
@export_range(0.0, 10000.0, 1.0) var max_weight: float = 0.0
```

Add these methods before `is_valid_index()`:

```gdscript

## Get the total weight of all items in the inventory.
func get_current_weight() -> float:
	var total := 0.0
	for slot in slots:
		if not slot.is_empty():
			total += slot.item.weight * slot.amount
	return total


## Check if adding this item would fit within weight limit (if set).
func can_add_weight(item: InventoryItem, amount: int = 1) -> bool:
	if max_weight <= 0.0:
		return true  # Unlimited
	return get_current_weight() + (item.weight * amount) <= max_weight


## Get weight as a ratio (0.0 to 1.0+). Returns 0 if no weight limit.
func get_weight_ratio() -> float:
	if max_weight <= 0.0:
		return 0.0
	return get_current_weight() / max_weight


## Emit weight change. Call after any inventory modification.
func _emit_weight_changed() -> void:
	weight_changed.emit(get_current_weight(), max_weight)
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/base_inventory.gd
git commit -m "feat: add weight tracking to BaseInventory"
```

---

### Task 6: Update Inventory with Instance Creation, Weight Emit, Serialization

**Files:**
- Modify: `addons/inventory_system/core/inventory.gd`

- [ ] **Step 1: Read and replace the entire file**

Read `addons/inventory_system/core/inventory.gd`. Replace with:

```gdscript
@tool
extends BaseInventory
class_name Inventory
## Standard inventory implementation with stacking support.
## Auto-creates ItemInstance for non-stackable items (equipment).


func add_item(item: InventoryItem, amount: int = 1, start_index: int = 0) -> int:
	var remaining = amount

	# First try to stack with existing items (only for stackable items)
	if item.max_stack > 1:
		for i in range(start_index, slots.size()):
			var slot = slots[i]
			if not slot.is_empty() and slot.item == item:
				var space = item.max_stack - slot.amount
				var to_add = min(remaining, space)
				slot.amount += to_add
				remaining -= to_add
				if remaining == 0:
					inventory_updated.emit()
					_emit_weight_changed()
					return 0

	# Then try to find empty slots
	for i in range(start_index, slots.size()):
		var slot = slots[i]
		if slot.is_empty():
			slot.item = item
			var to_add = min(remaining, item.max_stack)
			slot.amount = to_add
			remaining -= to_add

			# Auto-create ItemInstance for non-stackable items (equipment)
			if item.max_stack == 1:
				slot.instance = ItemInstance.new(item)

			if remaining == 0:
				inventory_updated.emit()
				_emit_weight_changed()
				return 0

	inventory_updated.emit()
	_emit_weight_changed()
	return remaining


func remove_item_at_index(index: int, amount: int) -> InventoryItem:
	if index < 0 or index >= slots.size():
		return null

	var slot = slots[index]
	if slot.is_empty():
		return null

	var item_removed = slot.item
	slot.amount -= amount

	if slot.amount <= 0:
		slot.clear()

	inventory_updated.emit()
	_emit_weight_changed()
	return item_removed


func set_item(index: int, item: InventoryItem, amount: int) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index].item = item
	slots[index].amount = amount
	if item == null:
		slots[index].instance = null
	inventory_updated.emit()
	_emit_weight_changed()


## Serialize the entire inventory to a Dictionary.
func serialize() -> Dictionary:
	var slot_data: Array[Dictionary] = []
	for slot in slots:
		if slot.is_empty():
			slot_data.append({})
		else:
			var entry := {"id": slot.item.id, "amount": slot.amount}
			if slot.instance:
				entry["instance"] = slot.instance.serialize()
			slot_data.append(entry)
	return {"slots": slot_data, "max_weight": max_weight}


## Deserialize from a Dictionary. Requires ItemDatabase autoload.
func deserialize(data: Dictionary) -> void:
	var item_db := Engine.get_singleton("ItemDatabase") if Engine.has_singleton("ItemDatabase") else null
	if not item_db:
		# Try as autoload
		item_db = Engine.get_main_loop().root.get_node_or_null("/root/ItemDatabase")

	var slot_data: Array = data.get("slots", [])
	max_weight = data.get("max_weight", max_weight)

	# Resize if needed
	if slot_data.size() != slots.size():
		resize(slot_data.size())

	for i in range(slot_data.size()):
		var entry: Dictionary = slot_data[i]
		if entry.is_empty():
			slots[i].clear()
		else:
			var item_id: String = entry.get("id", "")
			var item: InventoryItem = item_db.get_item(item_id) if item_db else null
			if item:
				slots[i].item = item
				slots[i].amount = entry.get("amount", 1)
				if entry.has("instance") and item_db:
					slots[i].instance = ItemInstance.from_dict(entry["instance"], item_db)
				elif item.max_stack == 1:
					slots[i].instance = ItemInstance.new(item)
			else:
				push_warning("Inventory.deserialize: item '%s' not found" % item_id)
				slots[i].clear()

	inventory_updated.emit()
	_emit_weight_changed()
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/inventory.gd
git commit -m "feat: auto-create ItemInstance, emit weight, add serialize/deserialize to Inventory"
```

---

### Task 7: Add Stat Aggregation and Serialization to EquipmentComponent

**Files:**
- Modify: `addons/inventory_system/core/equipment_component.gd`

- [ ] **Step 1: Read and replace the file**

Read `addons/inventory_system/core/equipment_component.gd`. Replace with:

```gdscript
@tool
extends Node
class_name EquipmentComponent

signal equipment_changed(slot_name: String, item: Resource)
signal stats_changed()

# Dictionary mapping slot names to EquipmentItem
@export var equipment_slots: Dictionary = {}

# Define available slot names
@export var defined_slots: Array[String] = []


func _ready():
	for slot_name in defined_slots:
		if not equipment_slots.has(slot_name):
			equipment_slots[slot_name] = null


func equip(item: Resource, slot_name: String) -> bool:
	if not item:
		return unequip(slot_name)

	if item.slot_type_name != slot_name:
		return false

	equipment_slots[slot_name] = item
	equipment_changed.emit(slot_name, item)
	stats_changed.emit()
	return true


func unequip(slot_name: String) -> bool:
	if equipment_slots.has(slot_name):
		equipment_slots[slot_name] = null
		equipment_changed.emit(slot_name, null)
		stats_changed.emit()
		return true
	return false


func get_item_in_slot(slot_name: String) -> Resource:
	return equipment_slots.get(slot_name, null)


## Get the total value of a stat across all equipped items.
## Checks defense, damage, and the stats dictionary.
func get_total_stat(stat_name: String) -> float:
	var total := 0.0
	for slot_name in equipment_slots:
		var item = equipment_slots[slot_name]
		if item and item is EquipmentItem:
			if stat_name == "defense":
				total += item.defense
			elif stat_name == "damage":
				total += item.damage
			if item.stats.has(stat_name):
				total += item.stats[stat_name]
	return total


## Get all aggregated stats as a Dictionary.
func get_all_stats() -> Dictionary:
	var stats := {}
	for slot_name in equipment_slots:
		var item = equipment_slots[slot_name]
		if item and item is EquipmentItem:
			if item.defense > 0:
				stats["defense"] = stats.get("defense", 0.0) + item.defense
			if item.damage > 0:
				stats["damage"] = stats.get("damage", 0.0) + item.damage
			for key in item.stats:
				stats[key] = stats.get(key, 0.0) + item.stats[key]
	return stats


## Serialize equipment state for save/load.
func serialize() -> Dictionary:
	var data := {}
	for slot_name in equipment_slots:
		var item = equipment_slots[slot_name]
		if item and item is EquipmentItem:
			data[slot_name] = {"id": item.id}
		else:
			data[slot_name] = null
	return data


## Deserialize equipment from saved data.
func deserialize(data: Dictionary) -> void:
	var item_db = Engine.get_main_loop().root.get_node_or_null("/root/ItemDatabase")
	for slot_name in data:
		var entry = data[slot_name]
		if entry == null:
			equipment_slots[slot_name] = null
		else:
			var item_id: String = entry.get("id", "")
			var item = item_db.get_item(item_id) if item_db else null
			if item:
				equipment_slots[slot_name] = item
			else:
				push_warning("EquipmentComponent.deserialize: item '%s' not found" % item_id)
				equipment_slots[slot_name] = null
	stats_changed.emit()
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/equipment_component.gd
git commit -m "feat: add stat aggregation and serialize/deserialize to EquipmentComponent"
```

---

### Task 8: Create ItemDatabase Autoload

**Files:**
- Create: `addons/inventory_system/core/item_database.gd`

- [ ] **Step 1: Create the ItemDatabase file**

```gdscript
extends Node
class_name ItemDatabase
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
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/item_database.gd
git commit -m "feat: add ItemDatabase autoload for item ID lookups"
```

---

### Task 9: Create SaveManager

**Files:**
- Create: `addons/inventory_system/core/save_manager.gd`

- [ ] **Step 1: Create the SaveManager file**

```gdscript
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
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/save_manager.gd
git commit -m "feat: add SaveManager for JSON-based inventory persistence"
```

---

### Task 10: Add Rarity Border Tint to SlotUI

**Files:**
- Modify: `addons/inventory_system/ui/slot_ui.gd`

- [ ] **Step 1: Read the file and add rarity tinting**

Read `addons/inventory_system/ui/slot_ui.gd`. Find the `set_slot()` method. After the icon and amount are set, add rarity border tinting.

Find where the icon is set (around line 28: `icon_texture.texture = item.icon`). After the amount label visibility logic, add:

```gdscript
		# Tint slot border by rarity
		if item.rarity != InventoryItem.Rarity.COMMON:
			var rarity_color := InventoryItem.RARITY_COLORS.get(item.rarity, Color.WHITE)
			self_modulate = rarity_color.lerp(Color.WHITE, 0.5)  # Subtle tint
		else:
			self_modulate = Color.WHITE
```

Also in the `else` branch (empty slot), add `self_modulate = Color.WHITE` to reset.

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/ui/slot_ui.gd
git commit -m "feat: add rarity-based border tint to SlotUI"
```

---

### Task 11: Register Types and Add Autoload

**Files:**
- Modify: `addons/inventory_system/inventory_plugin.gd`
- Modify: `project.godot`

- [ ] **Step 1: Add ItemInstance and ItemDatabase to plugin**

Read `addons/inventory_system/inventory_plugin.gd`. In `_enter_tree()`, add after the ManaEffect registration:

```gdscript
	add_custom_type("ItemInstance", "RefCounted", preload("core/item_instance.gd"), preload("icons/item.svg"))
	add_custom_type("ItemDatabase", "Node", preload("core/item_database.gd"), preload("icons/inventory.svg"))
```

In `_exit_tree()`, add after `remove_custom_type("ManaEffect")`:

```gdscript
	remove_custom_type("ItemInstance")
	remove_custom_type("ItemDatabase")
```

- [ ] **Step 2: Add ItemDatabase as autoload in project.godot**

Read `project.godot`. Add an `[autoload]` section (if it doesn't exist) after `[editor_plugins]`:

```
[autoload]

ItemDatabase="*res://addons/inventory_system/core/item_database.gd"
```

If `[autoload]` already exists, just add the ItemDatabase line.

- [ ] **Step 3: Commit**

```bash
git add addons/inventory_system/inventory_plugin.gd project.godot
git commit -m "feat: register ItemInstance, ItemDatabase in plugin and add autoload"
```

---

### Task 12: Fix Compile Errors

**Files:**
- Potentially any file referencing modified APIs

- [ ] **Step 1: Search for breaking references**

The changes are additive — no methods were removed. But verify:
- `InventorySlot.clear()` is new — check that no code already defines it
- `slot.instance` is new — check no conflicts
- `EquipmentComponent.stats_changed` is new — no existing code listens to it yet
- `BaseInventory.weight_changed` is new signal
- `Inventory.serialize()`/`deserialize()` are new methods

Search for any code that might conflict. The main risk is the `InventorySlot` change — if any code sets `slot.item = null; slot.amount = 0` directly instead of using `clear()`, the instance won't be cleared. Search for patterns like `slot.item = null` or `slot.amount = 0` outside of InventorySlot itself and update to use `slot.clear()`.

- [ ] **Step 2: Fix any issues found and commit**

```bash
git add -A
git commit -m "fix: update slot clearing to use slot.clear() for instance cleanup"
```

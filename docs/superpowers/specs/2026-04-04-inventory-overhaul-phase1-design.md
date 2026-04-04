# Inventory Overhaul Phase 1: Core Architecture - Design Spec

## Summary

Add ItemInstance layer for per-item mutable state (durability, upgrades), rarity system with color-coded display, stat aggregation on EquipmentComponent, weight tracking with soft cap, and save/load serialization via ItemDatabase.

## 1. ItemInstance Layer

### Problem
All items of the same type share a Resource reference. Can't have per-item durability, random affixes, or upgrade levels.

### Solution
New `ItemInstance` (RefCounted) wraps per-item mutable state. Only created for non-stackable items (equipment). Stackables continue using shared Resource references unchanged.

```
ItemInstance (RefCounted):
  definition: InventoryItem     # shared Resource template
  durability: float             # current durability (-1 = no durability)
  max_durability: float         # from definition
  affixes: Array[Resource]      # random stat modifiers (populated in Phase 2)
  upgrade_level: int = 0        # +0, +1, +2, etc.
  custom_name: String = ""      # player-given or affix-generated name
  instance_id: String           # unique ID for save/load (auto-generated)
```

### Integration
- `InventorySlot` gets optional `instance: ItemInstance` field
- For stackables: `instance` is null, `item` is shared Resource (unchanged)
- For equipment: `instance` created when item enters inventory via `add_item()`
- All existing `slot.item` reads continue working
- `instance` provides additional data layer on top

### When Instances Are Created
- `Inventory.add_item()` — if `item.max_stack == 1`, auto-create ItemInstance
- `EquipmentComponent.equip()` — create if missing
- Explicit creation for crafted/looted items with custom stats

## 2. Rarity System

### Enum on InventoryItem
```
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var rarity: Rarity = Rarity.COMMON
```

### Color Constants
```
COMMON:    Color.WHITE
UNCOMMON:  Color(0.3, 0.8, 0.3)    # green
RARE:      Color(0.4, 0.6, 1.0)    # blue
EPIC:      Color(0.7, 0.4, 0.9)    # purple
LEGENDARY: Color(1.0, 0.6, 0.2)    # orange
```

### Visual Display
- Tooltip: item name colored by rarity via BBCode
- SlotUI: border tint based on rarity color (subtle modulate on the slot panel)
- Sort priority: legendary first when sorting is added in Phase 3

## 3. Stat Aggregation on EquipmentComponent

### New Methods
```
get_total_stat(stat_name: String) -> float
  Sums stat across all equipped EquipmentItems.
  Sources: item.defense, item.damage, item.stats dictionary.

get_all_stats() -> Dictionary
  Returns aggregated stats, e.g. {"defense": 19, "damage": 15, "strength": 5}
```

### New Signal
```
signal stats_changed()
```
Emitted whenever `equipment_changed` fires. Downstream systems (combat, UI) listen.

### Extensibility
`get_total_stat()` is the single aggregation point. Phase 2 adds affix stats and set bonuses here.

## 4. Weight Enforcement (Soft Cap)

### On BaseInventory
```
@export var max_weight: float = 0.0  # 0 = unlimited (backwards compatible)

func get_current_weight() -> float
func can_add_weight(item, amount) -> bool
func get_weight_ratio() -> float  # 0.0 to 1.0+ (can exceed 1.0)

signal weight_changed(current: float, maximum: float)
```

### Soft Cap Behavior (external to inventory)
- Under 100%: normal movement
- 100-150%: movement speed reduced proportionally
- Over 150%: can't sprint
- Inventory always accepts items — penalty, not block

### Weight Tracking
- `add_item()` and `remove_item_at_index()` emit `weight_changed` after modification
- `get_current_weight()` iterates slots, sums `item.weight * amount`

## 5. Save/Load System

### ItemDatabase (Autoload)
```
func _ready(): _scan_items("res://items/")
func get_item(id: String) -> InventoryItem
func register_item(item: InventoryItem)
```
Scans `.tres` files in items directory, maps `id` field to Resource path.

### Serialization on Inventory
```
func serialize() -> Dictionary
  Returns: {"slots": [{id: "health_potion", amount: 5}, ...]}
  Equipment includes: {id: "steel_sword", amount: 1, instance: {durability: 85, upgrade_level: 2}}

func deserialize(data: Dictionary)
  Looks up items via ItemDatabase.get_item(id)
  Recreates ItemInstance for equipment
```

### Serialization on EquipmentComponent
```
func serialize() -> Dictionary
  Returns: {"Head": {id: "iron_helmet", instance: {...}}, "Chest": null, ...}

func deserialize(data: Dictionary)
```

### SaveManager (Static Utility)
```
static func save_inventory(path: String, inventory_comp, equipment_comp)
static func load_inventory(path: String, inventory_comp, equipment_comp)
```
Uses JSON via FileAccess. Game code decides when to call.

## 6. File Changes

### New Files
| File | Type | Purpose |
|------|------|---------|
| `core/item_instance.gd` | RefCounted | Per-item mutable state |
| `core/item_database.gd` | Node (Autoload) | ID → InventoryItem lookup |
| `core/save_manager.gd` | RefCounted | Static serialize/deserialize |

### Modified Files
| File | Changes |
|------|---------|
| `core/inventory_item.gd` | Rarity enum, rarity export, color constants, tooltip rarity coloring |
| `core/inventory_slot.gd` | Optional `instance: ItemInstance` field |
| `core/base_inventory.gd` | max_weight, get_current_weight(), weight_changed signal |
| `core/inventory.gd` | Auto-create ItemInstance for non-stackables, weight emit, serialize/deserialize |
| `core/equipment_item.gd` | max_durability export |
| `core/equipment_component.gd` | get_total_stat(), get_all_stats(), stats_changed signal, serialize/deserialize |
| `ui/slot_ui.gd` | Rarity border tint |
| `inventory_plugin.gd` | Register ItemInstance, ItemDatabase |
| `project.godot` | ItemDatabase autoload |

### Unchanged
- All existing item .tres files continue working (rarity defaults to COMMON)
- All UI scenes unchanged (SlotUI gets runtime tint, not scene changes)
- InventoryInteractionHandler unchanged
- ConsumableItem, ItemEffect hierarchy unchanged

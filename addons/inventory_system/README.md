# Modular Inventory System

A modular, SOLID-compliant inventory system addon for Godot 4 with equipment support, extensible effects, and drag-and-drop UI.

## Features

- **Resource-based Items**: Define items as Resources with inheritance (`InventoryItem` → `EquipmentItem`, `ConsumableItem`)
- **Abstract Base Classes**: Extend `BaseInventory`, `ItemEffect`, `BaseSlotUI` for custom implementations
- **Extensible Effect System**: Add custom effects to consumables without modifying core code (OCP)
- **Component-based Logic**: Add `InventoryComponent` and `EquipmentComponent` to any node
- **Drag and Drop UI**: Ready-to-use UI with drag-and-drop support
- **Equipment System**: Define custom slots (Head, Body, Weapon, etc.)
- **Category Filtering**: Filter inventories by item categories
- **Tooltip System**: Reusable `TooltipController` for any slot-based UI

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        CORE LAYER                          │
├─────────────────────────────────────────────────────────────┤
│  Resources (Data)           │  Components (Logic)          │
│  ─────────────────────────  │  ──────────────────────────  │
│  BaseInventory              │  InventoryComponent          │
│  └─ Inventory               │  EquipmentComponent          │
│  InventoryItem              │  InventoryInteractionHandler │
│  ├─ ConsumableItem          │                              │
│  └─ EquipmentItem           │                              │
│  ItemEffect                 │                              │
│  ├─ HealEffect              │                              │
│  └─ ManaEffect              │                              │
│  ItemCategory               │                              │
│  InventorySlot              │                              │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                         UI LAYER                           │
├─────────────────────────────────────────────────────────────┤
│  Base Classes               │  Implementations             │
│  ─────────────────────────  │  ──────────────────────────  │
│  BaseSlotUI                 │  SlotUI                      │
│  BaseInventoryDisplay       │  InventoryUI                 │
│  └─ EquippableInventoryDisplay │  QuickInventoryUI         │
│  TooltipController          │  EquipmentSlotUI             │
│                             │  ItemTooltipUI               │
└─────────────────────────────────────────────────────────────┘
```

## Installation

1. Copy `addons/inventory_system/` to your project's `addons/` folder
2. Go to **Project Settings → Plugins** and enable "Inventory System"

## Quick Start

### 1. Create Items

**Equipment Item:**
```
Right-click FileSystem → Create New → Resource → EquipmentItem
Set: name, icon, slot_type_name (e.g., "Head", "Chest", "MainHand")
```

**Consumable Item:**
```
Right-click FileSystem → Create New → Resource → ConsumableItem
Add effects: effects array → Add Element → New HealEffect (set value)
```

### 2. Setup Player Node

```gdscript
# Attach to your player scene
extends CharacterBody2D

@onready var inventory_component: InventoryComponent = $InventoryComponent
@onready var equipment_component: EquipmentComponent = $EquipmentComponent

func heal(amount: int) -> void:
    health = min(health + amount, max_health)

func restore_mana(amount: int) -> void:
    mana = min(mana + amount, max_mana)
```

Add child nodes:
- `InventoryComponent` — Manages main inventory and hotbar
- `EquipmentComponent` — Set `defined_slots` to `["Head", "Chest", "MainHand", "OffHand", "Feet"]`

### 3. Setup UI

Instance `addons/inventory_system/ui/inventory_ui.tscn` and assign:
- `inventory_component` → Your player's InventoryComponent
- `equipment_component` → Your player's EquipmentComponent
- `slot_scene` → `slot_ui.tscn`
- `equipment_slot_scene` → `equipment_slot_ui.tscn`

## Extending the System

### Custom Item Type

```gdscript
@tool
extends InventoryItem
class_name QuestItem

@export var quest_id: String = ""
@export var is_key_item: bool = false

func can_use() -> bool:
    return false  # Quest items cannot be "used"

func get_tooltip_text() -> String:
    var text = super.get_tooltip_text()
    text += _format_section_header("Quest Item", "purple")
    if is_key_item:
        text += _format_effect_line("Key Item - Cannot be discarded", "yellow")
    return text
```

### Custom Effect

```gdscript
@tool
extends ItemEffect
class_name DamageEffect

func _init():
    effect_name = "Damage"

func apply(user: Node) -> bool:
    if user.has_method("take_damage"):
        user.take_damage(int(value))
        return true
    return false

func get_tooltip_text() -> String:
    return "[color=red]Deals %d damage[/color]" % int(value)
```

### Custom Inventory (Weight-based)

```gdscript
@tool
extends BaseInventory
class_name WeightBasedInventory

@export var max_weight: float = 100.0
var current_weight: float = 0.0

func accepts_item(item: InventoryItem) -> bool:
    if not super.accepts_item(item):
        return false
    return current_weight + item.weight <= max_weight

func add_item(item: InventoryItem, amount: int = 1, start_index: int = 0) -> int:
    # Custom implementation with weight tracking
    pass
```

## Signals

### InventoryComponent
- `inventory_changed` — Emitted when any inventory changes

### EquipmentComponent  
- `equipment_changed(slot_name: String, item: InventoryItem)` — Emitted when equipment changes

### SlotUI / EquipmentSlotUI
- `item_drop_requested(item, source_inventory, source_index)` — Drag-drop event
- `item_activated(item, inventory, index)` — Double-click/use event
- `tooltip_requested(item, show: bool)` — Hover event
- `equip_requested(data, target_slot_name)` — Equipment drop event

## Design Principles

This addon follows **SOLID** principles:

| Principle | Implementation |
|-----------|----------------|
| **SRP** | Data (Resources), Logic (Components), Display (UI) are separate |
| **OCP** | Add new effects/items by extending, not modifying |
| **LSP** | All item subclasses honor `InventoryItem` contract |
| **ISP** | `BaseInventoryDisplay` vs `EquippableInventoryDisplay` |
| **DIP** | Components use `@export` injection, not tree traversal |

## License

MIT License - See LICENSE file

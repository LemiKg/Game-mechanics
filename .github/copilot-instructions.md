# Godot Modular Addon Framework - Copilot Instructions

## Project Philosophy

This project follows a **modular addon architecture** where each distinct feature is implemented as a self-contained Godot addon. The goal is maximum reusability, testability, and adherence to SOLID principles.

---

## Addon Structure Guidelines

### Each Addon Must Have

```
addons/
  addon_name/
    plugin.cfg          # Addon metadata
    addon_plugin.gd     # EditorPlugin for registration
    README.md           # Documentation
    core/               # Data models and business logic
    ui/                 # UI scenes and scripts
    icons/              # Editor icons (optional)
```

### Layer Separation

| Layer | Location | Responsibility |
|-------|----------|----------------|
| **Data** | `core/*.gd` (Resources) | Pure data containers, no logic beyond validation |
| **Logic** | `core/*_handler.gd`, `*_controller.gd` | Business rules, algorithms, state management |
| **UI** | `ui/*.gd` + `*.tscn` | Display and input only, delegates to logic layer |

---

## SOLID Principles in GDScript

### Single Responsibility Principle (SRP)

Each class should have one reason to change.

```gdscript
# ❌ BAD: UI class handles business logic
class_name InventoryUI
func _on_slot_clicked(slot):
    if inventory.get_item(slot).is_equippable():
        equipment.equip(inventory.remove_item(slot))  # Business logic in UI!

# ✅ GOOD: UI delegates to handler
class_name InventoryUI
@export var interaction_handler: InventoryInteractionHandler

func _on_slot_clicked(slot):
    interaction_handler.handle_slot_click(slot)
```

### Open/Closed Principle (OCP)

Classes should be open for extension, closed for modification. Use polymorphic methods.

```gdscript
# ❌ BAD: Switch statement that grows with each item type
func use_item(item):
    match item.type:
        "potion": heal(item.value)
        "scroll": cast_spell(item.spell_id)
        # Must modify this every time we add item types!

# ✅ GOOD: Polymorphic method on base class
class_name InventoryItem extends Resource
func use(user: Node) -> void:
    pass  # Override in subclasses

class_name ConsumableItem extends InventoryItem
func use(user: Node) -> void:
    if user.has_method("heal"):
        user.heal(heal_amount)
```

### Liskov Substitution Principle (LSP)

Subclasses must be substitutable for their base classes.

```gdscript
# Base class contract
class_name InventoryItem
func can_use() -> bool:
    return false

func get_tooltip_text() -> String:
    return "[b]%s[/b]\n%s" % [item_name, description]

# Subclass honors the contract
class_name EquipmentItem extends InventoryItem
func can_use() -> bool:
    return true  # Equipment can be "used" (equipped)

func get_tooltip_text() -> String:
    var base = super.get_tooltip_text()
    return base + "\n[color=gray]Slot: %s[/color]" % slot_type
```

### Interface Segregation Principle (ISP)

Prefer small, focused interfaces. In GDScript, use signals and duck typing.

```gdscript
# ❌ BAD: Fat interface forcing unused implementations
class_name IInventoryHandler
func handle_pickup(): pass
func handle_drop(): pass
func handle_equip(): pass
func handle_craft(): pass  # Not every handler needs crafting!

# ✅ GOOD: Separate signals for each concern
signal item_dropped(item, slot_index)
signal equip_requested(item)
signal craft_requested(recipe)
```

### Dependency Inversion Principle (DIP)

Depend on abstractions (exported references), not concrete implementations (tree traversal).

```gdscript
# ❌ BAD: Tree traversal creates tight coupling
func _ready():
    var inventory_ui = find_parent("InventoryUI")  # Fragile!
    inventory_ui.on_item_used.connect(_handle_use)

# ✅ GOOD: Dependency injection via @export
@export var inventory: Inventory
@export var equipment_component: EquipmentComponent
@export var tooltip_controller: TooltipController

func _ready():
    if inventory:
        inventory.inventory_changed.connect(_on_inventory_changed)
```

---

## Clean Code Standards

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Classes | PascalCase | `InventoryItem`, `TooltipController` |
| Functions | snake_case | `get_tooltip_text()`, `handle_drop()` |
| Signals | past_tense_event | `item_dropped`, `equip_requested` |
| Constants | SCREAMING_SNAKE | `MAX_STACK_SIZE`, `DEFAULT_SLOT_COUNT` |
| Private | leading underscore | `_internal_state`, `_on_button_pressed()` |

### Signal Design

```gdscript
# Signals should be declarative, not imperative
signal tooltip_requested(item: InventoryItem, global_position: Vector2)  # ✅
signal show_tooltip(item)  # ❌ Imperative name

# Include enough context for handlers
signal item_drop_requested(item: InventoryItem, source_slot: int)  # ✅
signal dropped(slot)  # ❌ Missing context
```

### Type Safety

```gdscript
# Always use type hints
@export var inventory: Inventory  # ✅
@export var inventory: Node  # ❌ Too generic

func get_item(index: int) -> InventoryItem:  # ✅
func get_item(index):  # ❌ No return type
```

### Null Safety

```gdscript
# Always guard external dependencies
func _on_slot_clicked(slot_index: int) -> void:
    if not inventory:
        push_warning("InventoryUI: No inventory assigned")
        return
    
    var item = inventory.get_item(slot_index)
    if item:
        item_selected.emit(item)
```

---

## Scalability Guidelines

### Controller Pattern for Reusable Behavior

When the same logic appears in multiple places, extract to a controller:

```gdscript
# TooltipController - reusable across any UI with slots
class_name TooltipController extends Node

@export var tooltip_ui: ItemTooltipUI

func connect_slot(slot: Control) -> void:
    if slot.has_signal("tooltip_requested"):
        slot.tooltip_requested.connect(_on_tooltip_requested)

func _on_tooltip_requested(item: InventoryItem, global_pos: Vector2) -> void:
    if tooltip_ui and item:
        tooltip_ui.show_item(item)
```

### Resource-Based Data

Use Godot Resources for data that needs to be saved/loaded or shared:

```gdscript
class_name InventoryItem extends Resource

@export var item_name: String
@export var icon: Texture2D
@export var max_stack_size: int = 1
@export var description: String
```

### Signal-Based Communication

Addons communicate via signals, never direct method calls across addon boundaries:

```gdscript
# In inventory addon
signal item_consumed(item: InventoryItem)

# In stats addon - connects externally
func _ready():
    var inventory_ui = get_node_or_null("../InventoryUI")
    if inventory_ui:
        inventory_ui.item_consumed.connect(_on_item_consumed)
```

---

## Inter-Addon Communication

### Allowed Patterns

1. **Signal connections** at runtime (parent wires children)
2. **Resource sharing** (common data types)
3. **Duck typing** with `has_method()` checks

### Forbidden Patterns

1. ❌ Direct `get_node()` calls into other addons
2. ❌ Hardcoded paths to other addon scenes
3. ❌ Circular dependencies between addons
4. ❌ Tree traversal with `find_parent()` or `get_tree().get_nodes_in_group()`

---

## Testing Checklist

Before completing any feature:

- [ ] Each new class has a single responsibility
- [ ] No `find_parent()` or tree traversal for dependencies
- [ ] All external dependencies use `@export`
- [ ] Signals include sufficient context for handlers
- [ ] Type hints on all function parameters and returns
- [ ] Null guards on all `@export` dependencies
- [ ] Polymorphic methods preferred over type checking
- [ ] New types registered in `plugin.gd` if needed

---

## File Naming

| Type | Pattern | Example |
|------|---------|---------|
| Resource scripts | `noun.gd` | `inventory_item.gd` |
| Component scripts | `noun_component.gd` | `equipment_component.gd` |
| Handler scripts | `noun_handler.gd` | `inventory_interaction_handler.gd` |
| Controller scripts | `noun_controller.gd` | `tooltip_controller.gd` |
| UI scripts | `noun_ui.gd` | `slot_ui.gd`, `inventory_ui.gd` |
| UI scenes | `noun_ui.tscn` | `slot_ui.tscn` |

---

## Quick Reference

### Adding a New Feature

1. Identify which addon owns this feature
2. Create data model in `core/` if needed (extends Resource)
3. Create handler/controller in `core/` for business logic
4. Create UI in `ui/` that delegates to handler
5. Add signals for cross-cutting concerns
6. Register new types in `plugin.gd`
7. Document in addon's README.md

### Adding a New Item Type

1. Create new class extending `InventoryItem` in `core/`
2. Override polymorphic methods: `can_use()`, `use()`, `is_equippable()`, `get_tooltip_text()`
3. Register in `plugin.gd`
4. Create `.tres` files in `items/` folder

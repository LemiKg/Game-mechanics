# Stat System Design

**Date:** 2026-04-07
**Status:** Approved for implementation planning
**Addon:** `addons/stat_system/`

## Goal

Add a reusable, SOLID-compliant Stat System addon to the game-mechanics library. It provides:

- **Resource stats** with current/max + regen (HP, MP, stamina)
- **Flat stats** with modifier stacks (attack, defense, crit_chance, anything)
- **Modifiers** that are flat or percent, source-tracked for clean removal, optionally timed for buffs/debuffs
- **Clean integration** with the existing `inventory_system` addon, replacing the duck-typed `heal()`/`restore_mana()` paths and per-item `defense`/`damage` fields

The system replaces ad-hoc stat handling that currently lives across `EquipmentItem`, `EquipmentComponent.get_total_stat()`, `HealEffect`, and `ManaEffect`.

## Non-Goals

- Primary → derived stat formulas (STR → HP, DEX → crit). Out of scope for v1; the `StatFormula` strategy leaves the door open for a `DerivedStatFormula` later.
- Multi-tier multiplicative stacking (PoE-style). Same — extension via a new `StatFormula` resource.
- A built-in UI. UI bars/buff lists are project-layer concerns; the addon ships only `StatReader` for narrow read-access.

## Architecture

Three-layer convention matching the rest of the project:

```
┌─────────────────────────────────────────┐
│  UI Layer (project-side, not addon)     │
│   StatBarUI, BuffBarUI                  │
├─────────────────────────────────────────┤
│  Logic Layer                            │
│   StatComponent (Node)                  │
│     - owns a StatBlock                  │
│     - _process: regen + buff timers     │
│     - emits signals                     │
│   StatReader (RefCounted, narrow view)  │
├─────────────────────────────────────────┤
│  Data Layer                             │
│   BaseStatBlock (abstract Resource)     │
│   StatBlock (default Resource)          │
│   StatDefinition (Resource)             │
│   StatModifier (Resource)               │
│   StatFormula (abstract Resource)       │
│   AdditivePercentFormula (default)      │
└─────────────────────────────────────────┘
```

### Dependency direction

`stat_system` is **standalone**. It has zero `class_name` references to `inventory_system`.

`inventory_system` gains an **optional** `@export var stat_component: StatComponent` on `EquipmentComponent`. The field is strictly typed; the inventory_system README documents that this field requires the `stat_system` addon to be enabled. If the project doesn't enable stat_system, leave the field null and equipment behaves exactly as it does today.

The player scene (project layer, not addon layer) is the only place that wires both addons together.

## Data Model

### StatDefinition (Resource)

Authored once per stat type as a `.tres` file. Schema:

```gdscript
class_name StatDefinition extends Resource
@export var id: StringName              # "health", "mana", "attack", "defense"
@export var display_name: String        # "Health"
@export var base_value: float = 0.0     # default before modifiers
@export var min_value: float = 0.0
@export var max_value: float = 0.0      # 0 = unbounded
@export var is_resource: bool = false   # true = has current/max + regen (HP/MP/stamina)
@export var regen_per_second: float = 0.0
@export var icon: Texture2D
@export var color: Color = Color.WHITE  # for UI bars
```

The `is_resource` flag distinguishes:
- **Resource stat** (HP/MP/stamina): tracks `current` separately from computed `max`. Supports regen and depletion signals.
- **Flat stat** (attack, defense, crit_chance): a single value computed from `base + modifiers`.

### StatModifier (Resource)

One bonus from one source.

```gdscript
class_name StatModifier extends Resource
enum Op { FLAT, PERCENT }
@export var stat_id: StringName         # which stat it targets
@export var op: Op = Op.FLAT
@export var value: float = 0.0
@export var source_id: StringName       # "iron_helmet", "haste_buff" — for removal
@export var duration: float = -1.0      # -1 = permanent, >0 = ticks down each frame
@export var display_name: String        # for buff bar UI
@export var icon: Texture2D
var remaining: float = -1.0             # runtime, set on add
```

### StatFormula (abstract Resource) + AdditivePercentFormula (default)

Extracted as a strategy resource so future formulas don't require modifying `StatBlock` (OCP).

```gdscript
class_name StatFormula extends Resource
## @virtual Compute the final value of one stat from its definition + active modifiers.
func compute(definition: StatDefinition, modifiers: Array[StatModifier]) -> float:
    push_error("StatFormula.compute() is abstract")
    return 0.0
```

`AdditivePercentFormula` (default, ships with the addon) implements:

```
final = (base + sum_flat) × (1 + sum_percent / 100)
```

…clamped to `[min_value, max_value]` if `max_value > 0`.

Future formulas (`MultiplicativeTierFormula`, `DerivedStatFormula`, etc.) become **new resources**, not edits to `StatBlock`.

### BaseStatBlock (abstract) + StatBlock (default)

`BaseStatBlock` mirrors `BaseInventory`: an abstract container so future variants can subclass without breaking consumers.

```gdscript
class_name StatBlock extends BaseStatBlock
@export var definitions: Array[StatDefinition] = []
@export var formula: StatFormula                                # set in _init if null
@export var current_resources: Dictionary = {}                  # StringName -> float, is_resource stats only
var _modifiers: Array[StatModifier] = []                        # runtime, not serialized

func _init() -> void:
    if formula == null:
        formula = AdditivePercentFormula.new()
```

(Godot 4 doesn't allow constructing a Resource as a default value on `@export`, so the default is assigned in `_init`. Authors can still override the formula in the inspector by assigning a different `StatFormula` `.tres`.)

Public methods (called by `StatComponent` and consumers):

| Method | Returns | Purpose |
|---|---|---|
| `get_value(id)` | `float` | Final computed value (flat stat or resource max) |
| `get_max(id)` | `float` | Same as `get_value` for resource stats; the computed cap |
| `get_current(id)` | `float` | Current value for resource stats; equal to `get_value` for flat stats |
| `modify_resource(id, delta)` | `void` | Add/subtract from `current` for a resource stat; emits signals |
| `set_current(id, value)` | `void` | Direct set; clamped to `[0, max]` |
| `add_modifier(m)` | `void` | Append a modifier; recompute affected stat; emit signals |
| `remove_modifier(m)` | `void` | Remove specific instance |
| `remove_modifiers_by_source(source_id)` | `void` | Remove all modifiers tagged with that source (equip/unequip path) |
| `get_active_modifiers()` | `Array[StatModifier]` | Read-only snapshot |
| `tick(delta)` | `void` | Apply regen + count down timed modifiers; called by `StatComponent._process` |
| `serialize()` | `Dictionary` | For save/load |
| `deserialize(data)` | `void` | For save/load |

### Why current_resources is persisted but _modifiers is not

`current` is real player state (you saved at 47/100 HP). `_modifiers` are recomputed from world state on load: `EquipmentComponent` re-applies its modifiers when equipment is loaded, and timed buffs naturally don't survive a save/load cycle. Keeping modifiers out of save data:

1. Eliminates a forward-compatibility hazard (modifier schema changes don't break old saves)
2. Makes save files smaller and human-readable
3. Forces the equipment-stat round-trip to be tested (because it has to work on every load)

## Runtime: StatComponent

```gdscript
class_name StatComponent extends Node
@export var stat_block: StatBlock
signal stat_changed(id: StringName, old_value: float, new_value: float)
signal resource_depleted(id: StringName)
signal resource_filled(id: StringName)
signal modifier_added(modifier: StatModifier)
signal modifier_removed(modifier: StatModifier, reason: int)  # SOURCE_REMOVED, EXPIRED, MANUAL

func _ready() -> void:
    if not stat_block:
        push_warning("StatComponent: no stat_block assigned to '%s'" % name)

func _process(delta: float) -> void:
    if stat_block:
        stat_block.tick(delta)
```

The Node intentionally does only what the Resource cannot: per-frame ticking, signal emission to scene-tree consumers, save/load coordination. **All math and state lives in `StatBlock`.** This is the same SRP split as `InventoryComponent` + `Inventory`.

`StatBlock.tick(delta)` is responsible for:
1. Applying `regen_per_second` to each resource stat where `current < max`
2. Decrementing `remaining` on each timed modifier; removing on ≤ 0 with reason `EXPIRED`
3. Emitting `stat_changed`, `resource_depleted`, `resource_filled`, `modifier_removed` via a callback the Component installs

The Component exposes a `get_reader() -> StatReader` for UI consumers.

### StatReader (read-only view, ISP)

```gdscript
class_name StatReader extends RefCounted
# Wraps a StatBlock; exposes ONLY get_value, get_max, get_current,
# get_active_modifiers, and forwards stat_changed/resource_depleted signals.
```

UI bars and buff lists depend on `StatReader`, not `StatComponent`. They cannot accidentally call `add_modifier()` because that method isn't in the reader's surface. GDScript doesn't enforce interfaces at the type level, so this is convention-based ISP — but it still narrows the dependency surface visible at the call site, which is the actual goal of ISP.

## Integration with inventory_system

### EquipmentComponent gains injection point

```gdscript
# addons/inventory_system/core/equipment_component.gd
@export var stat_component: StatComponent  # optional; null = old behavior
```

In `equip(item, slot_name)`:

```gdscript
if stat_component and item.has_method("get_stat_modifiers"):
    var mods: Array[StatModifier] = item.get_stat_modifiers()
    for m in mods:
        stat_component.add_modifier(m)
```

In `unequip(slot_name)`:

```gdscript
if stat_component and item and item.has_method("get_stat_modifiers"):
    stat_component.remove_modifiers_by_source(item.id)  # uses item id as source_id
```

**DIP:** `EquipmentComponent` depends on the `StatComponent` *abstraction* via `@export`, not on hardcoded paths or concrete subclasses. If `stat_component` is null, equipment still works — it just doesn't push modifiers. **Zero hard dependency from inventory_system → stat_system.**

### StatModifierProvider duck-typed contract (ISP)

Rather than coupling `EquipmentComponent` to `EquipmentItem` specifically, we define a tiny duck-typed contract: any item that implements

```gdscript
func get_stat_modifiers() -> Array[StatModifier]
```

can feed the stat system. `EquipmentItem` implements it. Future `EnchantmentItem`, `SetBonusItem`, consumable buff items — all can implement it without `EquipmentComponent` knowing they exist. This is true ISP: the consumer asks for the smallest possible contract.

### EquipmentItem migration

`EquipmentItem`'s legacy fields (`defense: int`, `damage: int`, `stats: Dictionary`) are removed. Replaced with:

```gdscript
@export var stat_modifiers: Array[StatModifier] = []

func get_stat_modifiers() -> Array[StatModifier]:
    return stat_modifiers
```

Existing `.tres` equipment files in `items/` (`iron_chestplate.tres`, `iron_helmet.tres`, `leather_boots.tres`, `steel_sword.tres`) need migration to use `stat_modifiers` instead of `defense`/`damage`. The migration is mechanical and one-shot — Godot will silently ignore the old fields on load, so the migration is forward-only with no breakage of save files.

`EquipmentComponent.get_total_stat()` and `get_all_stats()` methods are removed. Consumers asking for "total defense across equipment" should now query `stat_component.get_value("defense")` directly, which is the whole point of having a stat system.

### Effects migration

`HealEffect` and `ManaEffect` are deleted. Replaced with one generic effect:

```gdscript
class_name ResourceEffect extends ItemEffect
@export var target_stat: StringName  # "health", "mana", "stamina", anything
@export var delta: float = 0.0

func apply(user: Node) -> bool:
    var sc := user.get_node_or_null("StatComponent") as StatComponent
    if not sc:
        push_warning("ResourceEffect: no StatComponent on '%s'" % user.name)
        return false
    sc.stat_block.modify_resource(target_stat, delta)
    return true
```

A second effect powers timed buffs:

```gdscript
class_name ApplyModifierEffect extends ItemEffect
@export var modifier: StatModifier  # the modifier to push (with duration > 0)
```

This is what enables "Potion of Strength: +5 attack for 60s" without writing a new effect class per buff.

`health_potion.tres` and `mana_potion.tres` need migration to use `ResourceEffect` instead of `HealEffect`/`ManaEffect`.

### Optional-effect loading at the plugin layer

The `effects/` folder ships sample effects whose scripts `extends ItemEffect`. If the user doesn't enable `inventory_system`, the `ItemEffect` class isn't available and those scripts would fail to parse. The `stat_system_plugin.gd` script gates loading: it checks for `ClassDB.class_exists("ItemEffect")` (or equivalent) at `_enter_tree()` and only registers the effect classes if the inventory addon is enabled. The core stat_system addon loads either way.

## SOLID compliance audit

| Class | Single responsibility | OCP / extension story |
|---|---|---|
| `StatDefinition` | Static stat schema (data only) | Add fields (icon, category) without changing consumers |
| `StatModifier` | One bonus + lifecycle metadata | New `Op` values would require code change — kept to two intentionally |
| `StatFormula` (abstract) | Compute final value from definition + mods | New formula = new subclass, no edit to `StatBlock` |
| `AdditivePercentFormula` | Default flat+percent math | Substitutable for any other `StatFormula` (LSP) |
| `BaseStatBlock` (abstract) | Container contract | New container variants (DerivedStatBlock?) extend without breaking |
| `StatBlock` | State + modifier list | Substitutable for `BaseStatBlock` (LSP) |
| `StatComponent` | Runtime loop + signal pump | Pure delegation; no math here |
| `StatReader` | Read-only view for UI (ISP) | Hands UI a narrow surface |
| `ResourceEffect` | Apply a delta to one resource stat | Substitutable for `ItemEffect` (LSP) |
| `ApplyModifierEffect` | Push a timed modifier | Substitutable for `ItemEffect` (LSP) |

**DIP highlights:**
- `EquipmentComponent` → `StatComponent` via `@export` (injection, not lookup)
- `StatBlock` → `StatFormula` via `@export` (formula is swappable data, not hardcoded)
- `StatComponent` → `StatBlock` via `@export` (data swappable per entity)

## Error handling

Following the inventory addon's conventions:

- **Validation, not exceptions.** Public methods return `bool`/`Variant` and `push_warning()` on misuse. Never crash.
- **Defensive on boundaries:**
  - `StatBlock.get_value(unknown_id)` → `0.0` + warning
  - `add_modifier(null)` → no-op + warning
  - `add_modifier(mod_with_unknown_stat_id)` → rejected + warning
  - `modify_resource(non_resource_stat, delta)` → rejected + warning
  - `StatComponent` with no `stat_block` → warning in `_ready()`, all reads return safe defaults
- **No internal validation between trusted calls.** `StatBlock._recompute(id)` does not re-check arguments — only public API validates. Trust internal callers.
- **Signal storms avoided.** `stat_changed` is only emitted when the computed final value actually changes — modifier add/remove that nets to the same value emits nothing.

## Testing strategy

The project will check for an existing test framework before plan-writing. Current pattern is headless test scenes with `assert()` calls; if `gdunit4` or `GUT` is later adopted, tests can be ported.

### Unit tests (pure resources, no scene)

| Suite | Coverage |
|---|---|
| `test_stat_block.gd` | get/set base, modifier add/remove, source-based removal, formula application, min/max clamping, resource current vs. computed max, depletion at 0 |
| `test_stat_modifier.gd` | flat vs. percent operations, duration handling via direct `tick()` calls |
| `test_additive_percent_formula.gd` | empty modifiers, single flat, single percent, mixed, large modifier counts, edge case `1 + (-100/100) = 0` |
| `test_stat_block_serialization.gd` | round-trip serialize/deserialize, current_resources persistence, modifiers intentionally NOT persisted |

### Integration tests (Node-level, scene-required)

| Suite | Coverage |
|---|---|
| `test_stat_component.gd` | regen ticks, buff timer expiry, signal emission counts and ordering |
| `test_equipment_stat_integration.gd` | equip → stat increases, unequip → stat returns, swap → no leaks, no `stat_component` → no crash |
| `test_resource_effect.gd` | applying a `ResourceEffect` → `modify_resource` called → signal fires |

### Manual test scene

`scenes/stat_system_test_scene.tscn` — a player with HP/MP/stamina, equippable items in the world, buff potions on the hotbar. Mirrors the existing `test_scene.tscn` style. Used for visual validation of regen, buff bars, and equip-on-stat changes.

### Coverage targets

- 100% on the math (`StatFormula` subclasses) and serialization
- Best-effort on the runtime loop (timing-dependent code is checked via direct `tick()` calls, not real `_process`)

## File layout

```
addons/stat_system/
├── plugin.cfg
├── stat_system_plugin.gd
├── README.md
├── core/
│   ├── base_stat_block.gd          # abstract
│   ├── stat_block.gd               # default impl
│   ├── stat_definition.gd          # Resource
│   ├── stat_modifier.gd            # Resource
│   ├── stat_component.gd           # Node
│   ├── stat_reader.gd              # read-only view
│   └── formulas/
│       ├── stat_formula.gd                 # abstract
│       └── additive_percent_formula.gd     # default
├── effects/
│   ├── resource_effect.gd          # extends ItemEffect (gated by plugin)
│   └── apply_modifier_effect.gd
└── examples/
    ├── stats/
    │   ├── health.tres
    │   ├── mana.tres
    │   ├── stamina.tres
    │   ├── attack.tres
    │   └── defense.tres
    └── example_stat_block.tres
```

## Public API surface

Eight methods + five signals on `StatComponent`. That is the entire contract consumers should depend on.

```gdscript
# StatComponent
get_value(id) -> float
get_max(id) -> float
get_current(id) -> float
modify_resource(id, delta) -> void
add_modifier(modifier) -> void
remove_modifiers_by_source(source_id) -> void
get_active_modifiers() -> Array[StatModifier]
get_reader() -> StatReader
serialize() -> Dictionary
deserialize(data) -> void
# Signals: stat_changed, resource_depleted, resource_filled, modifier_added, modifier_removed
```

## Migration impact on existing code

Files that will be modified or deleted as part of implementation:

| File | Change |
|---|---|
| `addons/inventory_system/core/equipment_item.gd` | Remove `defense`, `damage`, `stats` fields. Add `stat_modifiers: Array[StatModifier]` and `get_stat_modifiers()`. Update tooltip generation. |
| `addons/inventory_system/core/equipment_component.gd` | Add `@export var stat_component`. Remove `get_total_stat()`, `get_all_stats()`. Push/remove modifiers in `equip`/`unequip`. |
| `addons/inventory_system/core/heal_effect.gd` | **Delete** — replaced by `ResourceEffect` |
| `addons/inventory_system/core/mana_effect.gd` | **Delete** — replaced by `ResourceEffect` |
| `items/iron_chestplate.tres` | Migrate to `stat_modifiers` |
| `items/iron_helmet.tres` | Migrate to `stat_modifiers` |
| `items/leather_boots.tres` | Migrate to `stat_modifiers` |
| `items/steel_sword.tres` | Migrate to `stat_modifiers` |
| `items/health_potion.tres` | Migrate to `ResourceEffect` |
| `items/mana_potion.tres` | Migrate to `ResourceEffect` |
| `addons/inventory_system/README.md` | Document optional `stat_system` integration |
| `README.md` (project root) | Move Stat System from "Planned" to "Available" |

No existing test player implements `heal()` / `restore_mana()` directly (verified — only `inventory_system/README.md` references those method names). So the migration burden on scene-side code is **zero**: no player scripts need editing. The implementation plan only needs to add a `StatComponent` child node to whichever test scene is chosen for the new manual test scene.

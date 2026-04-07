# Stat System

Reusable Godot 4 addon for resource stats (HP/MP/stamina), flat stats with
flat+percent modifier stacks, and timed buffs/debuffs.

- **Standalone.** Zero hard dependency on other addons.
- **SOLID.** Strategy-based formula, abstract base block, ISP read view.
- **Save/load ready.** Resource currents are persisted; modifiers are
  re-pushed by their owners (equipment, buffs) on load.
- **Optional inventory integration.** When `inventory_system` is enabled,
  two effects (`ResourceEffect`, `ApplyModifierEffect`) and an `EquipmentItem`
  hook (`stat_modifiers` array) become available.

## Quick start

1. Enable the plugin in **Project Settings → Plugins**.
2. Author a `StatDefinition` `.tres` for each stat your game needs (see
   `examples/stats/` for `health`, `mana`, `stamina`, `attack`, `defense`).
3. Author a `StatBlock` `.tres` referencing those definitions.
4. Add a `StatComponent` Node to your player/NPC scene and assign the block.
5. Read values via `stat_component.get_value("attack")` and adjust resources
   via `stat_component.modify_resource("health", -10)`.

## Concepts

### Stats come in two flavors

- **Resource stats** (`is_resource = true`): HP, MP, stamina. Track
  `current` separately from computed `max`. Support per-second regen and
  fire `resource_depleted` / `resource_filled` signals.
- **Flat stats** (`is_resource = false`): attack, defense, crit_chance.
  A single value computed from `base + modifiers`.

### Modifier formula

Default formula (`AdditivePercentFormula`):

```
final = (base + sum_flat) × (1 + sum_percent / 100)
```

Result is clamped to `[min_value, max_value]` (treating `max_value == 0`
as unbounded). Replace by assigning a different `StatFormula` subclass
to `StatBlock.formula`.

### Modifiers carry a source

Every `StatModifier` has a `source_id` (e.g. `"iron_helmet"`,
`"haste_buff"`). `remove_modifiers_by_source(source_id)` removes every
modifier from that source in one call — that's how equip/unequip works
without leaks.

### Timed buffs

Set `StatModifier.duration > 0` to make a modifier expire after that many
seconds. The `StatComponent`'s `_process` ticks the countdown and removes
expired modifiers with reason `EXPIRED`. Permanent modifiers use
`duration = -1`.

## Public API

`StatComponent` exposes the entire contract consumers should depend on:

| Method | Purpose |
|---|---|
| `get_value(id)` | Final computed value (flat or resource max) |
| `get_max(id)` | Same as get_value; reads better for resource stats |
| `get_current(id)` | Persisted current for resource stats; equal to get_value for flat stats |
| `modify_resource(id, delta)` | Adjust a resource's current; clamps to `[0, max]` |
| `set_current(id, value)` | Direct set; clamps |
| `add_modifier(m)` | Add a modifier; recomputes and emits signals |
| `remove_modifier(m)` | Remove specific instance |
| `remove_modifiers_by_source(source_id)` | Remove all modifiers from one source |
| `get_active_modifiers()` | Read-only snapshot |
| `get_reader()` | Narrow read-only `StatReader` for UI consumers |
| `serialize()` / `deserialize(data)` | Save/load |

Signals: `stat_changed(id, old, new)`, `resource_depleted(id)`,
`resource_filled(id)`, `modifier_added(m)`, `modifier_removed(m, reason)`.

## Inventory integration (optional)

If `inventory_system` is enabled, two effects ship in `effects/`:

- **`ResourceEffect`** — replaces `HealEffect` and `ManaEffect`. Authoring:
  `target_stat = "health"`, `delta = +50`. Use as a child of a
  `ConsumableItem.effects` array.
- **`ApplyModifierEffect`** — pushes a (typically timed) modifier onto the
  user's `StatComponent`. Powers buff potions.

`EquipmentItem` gains a `stat_modifiers: Array[StatModifier]` field. Set
the `source_id` of each modifier to the item's id (e.g. `"iron_helmet"`).
When the item is equipped, `EquipmentComponent` (with its
`stat_component` export wired) auto-pushes those modifiers; on unequip,
it auto-removes them by source.

## Tests

Run the headless test suite from the repo root:

```bash
godot --headless --quit --script "addons/stat_system/tests/run_tests.gd"
```

Exit code is non-zero on failure. The runner discovers any
`addons/stat_system/tests/test_*.gd` script automatically.

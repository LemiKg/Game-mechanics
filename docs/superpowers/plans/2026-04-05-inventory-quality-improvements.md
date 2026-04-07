# Inventory Quality Improvements Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the inventory system with granular UI refresh, cleanup of legacy code, better validation, and sort/filter capabilities.

**Architecture:** Add `slot_updated(index)` signal to `Inventory` for O(1) UI refresh. Remove deprecated ConsumableItem fields. Replace WorldItem tree traversal with explicit export. Add validation guards and sort methods. Fix ThemeManager toast anchoring.

**Tech Stack:** GDScript, Godot 4.6

---

### Task 1: Add granular `slot_updated` signal to Inventory

**Files:**
- Modify: `addons/inventory_system/core/base_inventory.gd:3` (add signal)
- Modify: `addons/inventory_system/core/inventory.gd` (emit slot_updated in add/remove/set)
- Modify: `addons/inventory_system/core/inventory_component.gd:50-81` (emit slot_updated on swap)

- [ ] **Step 1: Add `slot_updated` signal to BaseInventory**

In `addons/inventory_system/core/base_inventory.gd`, add after line 3 (`signal inventory_updated`):

```gdscript
signal slot_updated(index: int)
```

- [ ] **Step 2: Emit `slot_updated` in `Inventory.add_item()`**

In `addons/inventory_system/core/inventory.gd`, replace the `add_item` method:

```gdscript
func add_item(item: InventoryItem, amount: int = 1, start_index: int = 0) -> int:
	var remaining = amount
	var changed_indices: Array[int] = []

	# First try to stack with existing items (only for stackable items)
	if item.max_stack > 1:
		for i in range(start_index, slots.size()):
			var slot = slots[i]
			if not slot.is_empty() and slot.item == item:
				var space = item.max_stack - slot.amount
				var to_add = min(remaining, space)
				slot.amount += to_add
				remaining -= to_add
				changed_indices.append(i)
				if remaining == 0:
					_emit_changes(changed_indices)
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

			changed_indices.append(i)
			if remaining == 0:
				_emit_changes(changed_indices)
				return 0

	_emit_changes(changed_indices)
	return remaining
```

- [ ] **Step 3: Emit `slot_updated` in `Inventory.remove_item_at_index()`**

Replace the method:

```gdscript
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

	_emit_changes([index])
	return item_removed
```

- [ ] **Step 4: Emit `slot_updated` in `Inventory.set_item()`**

Replace the method:

```gdscript
func set_item(index: int, item: InventoryItem, amount: int) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index].item = item
	slots[index].amount = amount
	if item == null:
		slots[index].instance = null
	_emit_changes([index])
```

- [ ] **Step 5: Add `_emit_changes` helper to Inventory**

Add at the bottom of `addons/inventory_system/core/inventory.gd`, before `serialize()`:

```gdscript
## Emit both granular slot_updated and bulk inventory_updated signals.
func _emit_changes(changed_indices: Array[int]) -> void:
	for i in changed_indices:
		slot_updated.emit(i)
	inventory_updated.emit()
	_emit_weight_changed()
```

- [ ] **Step 6: Emit `slot_updated` on swap in InventoryComponent**

In `addons/inventory_system/core/inventory_component.gd`, replace the swap logic (lines 64-79):

```gdscript
	# Perform swap (preserve instance data)
	var temp_item = from_slot.item
	var temp_amount = from_slot.amount
	var temp_instance = from_slot.instance

	from_slot.item = to_slot.item
	from_slot.amount = to_slot.amount
	from_slot.instance = to_slot.instance

	to_slot.item = temp_item
	to_slot.amount = temp_amount
	to_slot.instance = temp_instance
	
	from_inventory.slot_updated.emit(from_index)
	from_inventory.inventory_updated.emit()
	if from_inventory != to_inventory:
		to_inventory.slot_updated.emit(to_index)
		to_inventory.inventory_updated.emit()
	else:
		from_inventory.slot_updated.emit(to_index)
```

- [ ] **Step 7: Commit**

```bash
git add addons/inventory_system/core/base_inventory.gd addons/inventory_system/core/inventory.gd addons/inventory_system/core/inventory_component.gd
git commit -m "feat(inventory): add granular slot_updated signal for O(1) UI refresh"
```

---

### Task 2: Incremental slot refresh in InventoryUI

**Files:**
- Modify: `addons/inventory_system/ui/inventory_ui.gd` (add `_refresh_single_slot`, connect `slot_updated`)
- Modify: `addons/inventory_system/ui/base_inventory_display.gd` (connect `slot_updated` signals)

- [ ] **Step 1: Connect `slot_updated` in BaseInventoryDisplay**

In `addons/inventory_system/ui/base_inventory_display.gd`, replace `set_inventory`:

```gdscript
func set_inventory(component: InventoryComponent):
	if inventory_component:
		if inventory_component.inventory_changed.is_connected(refresh):
			inventory_component.inventory_changed.disconnect(refresh)
		_disconnect_slot_signals(inventory_component)
	
	inventory_component = component
	if inventory_component:
		inventory_component.inventory_changed.connect(refresh)
		_connect_slot_signals(inventory_component)
		if interaction_handler:
			interaction_handler.inventory_component = inventory_component
		refresh()

## @virtual Called when a single slot changes. Override for incremental updates.
## Default: does nothing (subclass that doesn't override gets full refresh via inventory_changed).
func on_slot_updated(_inventory: Inventory, _index: int) -> void:
	pass

func _connect_slot_signals(component: InventoryComponent) -> void:
	if component.main_inventory:
		if not component.main_inventory.slot_updated.is_connected(_on_main_slot_updated):
			component.main_inventory.slot_updated.connect(_on_main_slot_updated)
	if component.hotbar_inventory:
		if not component.hotbar_inventory.slot_updated.is_connected(_on_hotbar_slot_updated):
			component.hotbar_inventory.slot_updated.connect(_on_hotbar_slot_updated)

func _disconnect_slot_signals(component: InventoryComponent) -> void:
	if component.main_inventory and component.main_inventory.slot_updated.is_connected(_on_main_slot_updated):
		component.main_inventory.slot_updated.disconnect(_on_main_slot_updated)
	if component.hotbar_inventory and component.hotbar_inventory.slot_updated.is_connected(_on_hotbar_slot_updated):
		component.hotbar_inventory.slot_updated.disconnect(_on_hotbar_slot_updated)

func _on_main_slot_updated(index: int) -> void:
	if inventory_component:
		on_slot_updated(inventory_component.main_inventory, index)

func _on_hotbar_slot_updated(index: int) -> void:
	if inventory_component:
		on_slot_updated(inventory_component.hotbar_inventory, index)
```

- [ ] **Step 2: Add incremental refresh to InventoryUI**

In `addons/inventory_system/ui/inventory_ui.gd`, add after `refresh()`:

```gdscript
func on_slot_updated(inventory: Inventory, index: int) -> void:
	var container: Container = null
	if inventory == inventory_component.main_inventory:
		container = grid_container
	elif inventory == inventory_component.hotbar_inventory:
		container = hotbar_container
	
	if not container:
		return
	
	if index < 0 or index >= container.get_child_count():
		return
	
	var slot_ui: SlotUI = container.get_child(index) as SlotUI
	if slot_ui:
		slot_ui.set_slot(inventory, index, inventory.slots[index])
```

- [ ] **Step 3: Disconnect `inventory_changed` from full refresh in InventoryUI**

Since InventoryUI now handles incremental updates via `on_slot_updated`, it should NOT also do a full refresh on every `inventory_changed`. In `addons/inventory_system/ui/inventory_ui.gd`, override `set_inventory` to skip the `inventory_changed -> refresh` connection:

Actually, this needs care. The full `refresh()` is still needed for initial setup and resize. The `inventory_changed` signal fires on every change alongside `slot_updated`. We should disconnect `inventory_changed` from `refresh` in InventoryUI since it now uses `slot_updated` for incremental updates, but keep the initial `refresh()` call.

In `addons/inventory_system/ui/base_inventory_display.gd`, update `set_inventory` to make the `inventory_changed -> refresh` connection optional:

```gdscript
## Whether to use full refresh on inventory_changed. Subclasses that implement
## on_slot_updated() can set this to false for incremental updates.
var _use_full_refresh: bool = true
```

And update `set_inventory`:

```gdscript
func set_inventory(component: InventoryComponent):
	if inventory_component:
		if inventory_component.inventory_changed.is_connected(refresh):
			inventory_component.inventory_changed.disconnect(refresh)
		_disconnect_slot_signals(inventory_component)
	
	inventory_component = component
	if inventory_component:
		if _use_full_refresh:
			inventory_component.inventory_changed.connect(refresh)
		_connect_slot_signals(inventory_component)
		if interaction_handler:
			interaction_handler.inventory_component = inventory_component
		refresh()
```

Then in `addons/inventory_system/ui/inventory_ui.gd`, set `_use_full_refresh = false` in `_ready()`:

Add before `super._ready()`:

```gdscript
func _ready():
	_use_full_refresh = false
	super._ready()
	if equipment_component:
		set_equipment(equipment_component)
	_setup_interaction_handler()
```

- [ ] **Step 4: Also add incremental refresh to QuickInventoryUI**

In `addons/inventory_system/ui/quick_inventory_ui.gd`, add:

```gdscript
func on_slot_updated(inventory: Inventory, index: int) -> void:
	if inventory != inventory_component.hotbar_inventory:
		return
	if index < 0 or index >= container.get_child_count():
		return
	var slot_ui: SlotUI = container.get_child(index) as SlotUI
	if slot_ui:
		slot_ui.set_slot(inventory, index, inventory.slots[index])
```

And in `_ready()`, add `_use_full_refresh = false`:

```gdscript
func _ready():
	_use_full_refresh = false
	super._ready()
```

- [ ] **Step 5: Commit**

```bash
git add addons/inventory_system/ui/base_inventory_display.gd addons/inventory_system/ui/inventory_ui.gd addons/inventory_system/ui/quick_inventory_ui.gd
git commit -m "feat(ui): incremental slot refresh via slot_updated signal"
```

---

### Task 3: Remove legacy ConsumableItem fields

**Files:**
- Modify: `addons/inventory_system/core/consumable_item.gd` (remove health_restore, mana_restore, _sync_legacy_effects, legacy support blocks)

- [ ] **Step 1: Remove legacy fields and code**

Replace the entire file content:

```gdscript
@tool
extends InventoryItem
class_name ConsumableItem
## Consumable item that applies effects when used.
## Uses the ItemEffect system for OCP-compliant extensibility.

## Array of effects to apply when this item is consumed.
## Add HealEffect, ManaEffect, or custom effects here.
@export var effects: Array[ItemEffect] = []

func can_use() -> bool:
	return true

## Apply all effects to the user.
func use(user: Node) -> void:
	if not user:
		push_warning("ConsumableItem: No user provided for item use")
		return
	
	for effect in effects:
		if effect and effect.can_apply(user):
			effect.apply(user)

func get_tooltip_text() -> String:
	var text = super.get_tooltip_text()
	text += _format_section_header("Consumable", "lime")
	
	for effect in effects:
		if effect:
			var effect_text = effect.get_tooltip_text()
			if effect_text:
				text += "\n" + effect_text
	
	return text
```

- [ ] **Step 2: Verify no .tres files reference legacy fields**

Run: `grep -r "health_restore\|mana_restore" items/`

If any .tres files reference these fields, they will need their effects migrated. Godot will silently ignore unknown properties on load, so existing saves will still work — the fields just won't do anything.

- [ ] **Step 3: Commit**

```bash
git add addons/inventory_system/core/consumable_item.gd
git commit -m "refactor(consumable): remove deprecated health_restore/mana_restore legacy fields"
```

---

### Task 4: WorldItem uses @export instead of tree traversal

**Files:**
- Modify: `addons/inventory_system/core/world_item.gd:129-139` (replace child iteration with export/group lookup)

- [ ] **Step 1: Add `inventory_component` export and update `_try_pickup()`**

In `addons/inventory_system/core/world_item.gd`, add after line 24 (`@export var destroy_on_pickup`):

```gdscript
## Optional: Explicit reference to the InventoryComponent. If not set, auto-discovers from player.
@export var inventory_component: InventoryComponent
```

Replace `_try_pickup()`:

```gdscript
func _try_pickup() -> void:
	if not item or not _player:
		return

	# Use explicit reference if set, otherwise find on player
	var inv_comp: InventoryComponent = inventory_component
	if not inv_comp:
		inv_comp = _player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inv_comp:
		push_warning("WorldItem: No InventoryComponent found on player (set export or add child named 'InventoryComponent')")
		return

	var remaining := inv_comp.add_item(item, amount)
	if remaining < amount:
		var picked := amount - remaining
		picked_up.emit(item, picked)

		if remaining == 0 and destroy_on_pickup:
			_play_pickup_effect()
		else:
			amount = remaining
```

Note: `_play_pickup_effect()` already calls `queue_free()` internally, so we remove the redundant `queue_free()` that was after it.

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/world_item.gd
git commit -m "refactor(world-item): use get_node_or_null instead of child iteration for InventoryComponent"
```

---

### Task 5: Integrate `InventorySlot.can_add()` into Inventory.add_item()

**Files:**
- Modify: `addons/inventory_system/core/inventory_slot.gd:20-25` (update can_add to also check weight)
- Modify: `addons/inventory_system/core/inventory.gd:8-45` (use slot.can_add() in add_item)

- [ ] **Step 1: Use `slot.can_add()` in `Inventory.add_item()`**

In the `add_item` method (already modified in Task 1), the stacking check `if not slot.is_empty() and slot.item == item` and the space calculation duplicate what `can_add()` already knows. Replace the stacking loop body:

In `addons/inventory_system/core/inventory.gd`, in the stacking section of `add_item`, replace:

```gdscript
	# First try to stack with existing items (only for stackable items)
	if item.max_stack > 1:
		for i in range(start_index, slots.size()):
			var slot = slots[i]
			if not slot.is_empty() and slot.item == item:
				var space = item.max_stack - slot.amount
				var to_add = min(remaining, space)
				slot.amount += to_add
				remaining -= to_add
				changed_indices.append(i)
				if remaining == 0:
					_emit_changes(changed_indices)
					return 0
```

With:

```gdscript
	# First try to stack with existing items (only for stackable items)
	if item.max_stack > 1:
		for i in range(start_index, slots.size()):
			var slot = slots[i]
			if slot.can_add(item, 1):
				var space = item.max_stack - slot.amount
				var to_add = min(remaining, space)
				slot.amount += to_add
				remaining -= to_add
				changed_indices.append(i)
				if remaining == 0:
					_emit_changes(changed_indices)
					return 0
```

Note: `can_add()` already checks `is_empty() || (item == p_item && amount + p_amount <= max_stack)`. For the stacking loop, it correctly matches non-empty slots with the same item that have room. Empty slots return true from `can_add()` but we only want to stack here (empty slots handled below), so the `max_stack > 1` gate plus the stack math handles this correctly — an empty slot's `can_add` returns true but `space = max_stack - 0` gives the right behavior.

Actually, on reflection, using `can_add` here would also match empty slots (since `is_empty()` returns true in `can_add`). We want only non-empty matching slots in the stacking pass. Keep the original check for the stacking loop. The `can_add()` method is better suited for external callers checking if a specific slot can receive an item. No change needed here.

- [ ] **Step 2: Commit**

No file changes in this task — `can_add()` is already correct for external use (e.g., UI validation). The stacking loop intentionally separates "stack into existing" from "fill empty" passes, which `can_add()` can't distinguish. Leave as-is.

Skip this task — `can_add()` serves its purpose for external callers. The internal stacking logic correctly handles the two-pass approach.

---

### Task 6: Add validation guards

**Files:**
- Modify: `addons/inventory_system/core/equipment_component.gd:21-28` (validate slot_name)
- Modify: `addons/inventory_system/core/world_item.gd:56-74` (guard null item in _ready)

- [ ] **Step 1: Add slot_name validation to EquipmentComponent.equip()**

In `addons/inventory_system/core/equipment_component.gd`, replace `equip()`:

```gdscript
func equip(item: Resource, slot_name: String) -> bool:
	if not item:
		return unequip(slot_name)
	
	if not equipment_slots.has(slot_name):
		push_warning("EquipmentComponent: Slot '%s' does not exist. Defined slots: %s" % [slot_name, defined_slots])
		return false

	if item.slot_type_name != slot_name:
		return false

	equipment_slots[slot_name] = item
	equipment_changed.emit(slot_name, item)
	stats_changed.emit()
	return true
```

- [ ] **Step 2: Guard null item in WorldItem._ready()**

In `addons/inventory_system/core/world_item.gd`, add at the start of `_ready()`:

```gdscript
func _ready() -> void:
	if not item:
		push_warning("WorldItem: No item assigned to '%s'" % name)
	
	_base_y = position.y
```

(Rest of _ready stays the same.)

- [ ] **Step 3: Add slot_name validation to EquipmentComponent.unequip()**

In `addons/inventory_system/core/equipment_component.gd`, update `unequip()`:

```gdscript
func unequip(slot_name: String) -> bool:
	if not equipment_slots.has(slot_name):
		push_warning("EquipmentComponent: Cannot unequip — slot '%s' does not exist" % slot_name)
		return false
	equipment_slots[slot_name] = null
	equipment_changed.emit(slot_name, null)
	stats_changed.emit()
	return true
```

- [ ] **Step 4: Commit**

```bash
git add addons/inventory_system/core/equipment_component.gd addons/inventory_system/core/world_item.gd
git commit -m "fix: add validation guards to EquipmentComponent and WorldItem"
```

---

### Task 7: Remove ItemInstance affixes placeholder

**Files:**
- Modify: `addons/inventory_system/core/item_instance.gd:19-20` (remove affixes)

- [ ] **Step 1: Remove affixes field**

In `addons/inventory_system/core/item_instance.gd`, remove lines 19-20:

```gdscript
## Random stat modifiers (populated by loot generation in Phase 2).
var affixes: Array[Resource] = []
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/item_instance.gd
git commit -m "refactor(item-instance): remove unused affixes placeholder"
```

---

### Task 8: Add sort methods to Inventory

**Files:**
- Modify: `addons/inventory_system/core/inventory.gd` (add sort methods after `deserialize()`)

- [ ] **Step 1: Add sort methods**

Add at the end of `addons/inventory_system/core/inventory.gd`:

```gdscript
## Sort inventory slots. Empty slots are moved to the end.
func sort_by_name() -> void:
	_sort_slots(func(a: InventorySlot, b: InventorySlot) -> bool:
		if a.is_empty(): return false
		if b.is_empty(): return true
		return a.item.name.naturalnocasecmp_to(b.item.name) < 0
	)

func sort_by_rarity() -> void:
	_sort_slots(func(a: InventorySlot, b: InventorySlot) -> bool:
		if a.is_empty(): return false
		if b.is_empty(): return true
		if a.item.rarity != b.item.rarity:
			return a.item.rarity > b.item.rarity  # Higher rarity first
		return a.item.name.naturalnocasecmp_to(b.item.name) < 0
	)

func sort_by_value() -> void:
	_sort_slots(func(a: InventorySlot, b: InventorySlot) -> bool:
		if a.is_empty(): return false
		if b.is_empty(): return true
		if a.item.value != b.item.value:
			return a.item.value > b.item.value  # Higher value first
		return a.item.name.naturalnocasecmp_to(b.item.name) < 0
	)

func sort_by_weight() -> void:
	_sort_slots(func(a: InventorySlot, b: InventorySlot) -> bool:
		if a.is_empty(): return false
		if b.is_empty(): return true
		if a.item.weight != b.item.weight:
			return a.item.weight > b.item.weight  # Heavier first
		return a.item.name.naturalnocasecmp_to(b.item.name) < 0
	)

func _sort_slots(comparator: Callable) -> void:
	slots.sort_custom(comparator)
	inventory_updated.emit()
	_emit_weight_changed()
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/core/inventory.gd
git commit -m "feat(inventory): add sort methods (name, rarity, value, weight)"
```

---

### Task 9: Fix ThemeManager toast positioning

**Files:**
- Modify: `addons/inventory_system/ui/themes/theme_manager.gd:100-108` (use anchors)

- [ ] **Step 1: Replace hardcoded offsets with anchors**

In `addons/inventory_system/ui/themes/theme_manager.gd`, replace `_create_toast_label()`:

```gdscript
func _create_toast_label() -> void:
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.anchor_left = 0.5
	_toast_label.anchor_right = 0.5
	_toast_label.anchor_top = 0.0
	_toast_label.anchor_bottom = 0.0
	_toast_label.offset_left = -150.0
	_toast_label.offset_right = 150.0
	_toast_label.offset_top = 40.0
	_toast_label.offset_bottom = 70.0
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.visible = false
	get_parent().call_deferred("add_child", _toast_label)
```

- [ ] **Step 2: Commit**

```bash
git add addons/inventory_system/ui/themes/theme_manager.gd
git commit -m "fix(theme-manager): use proper anchors for toast label positioning"
```

---

## Task Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Granular `slot_updated` signal | base_inventory, inventory, inventory_component |
| 2 | Incremental UI refresh | base_inventory_display, inventory_ui, quick_inventory_ui |
| 3 | Remove legacy ConsumableItem fields | consumable_item |
| 4 | WorldItem export instead of tree traversal | world_item |
| 5 | ~~Integrate can_add()~~ (skipped — already serves its purpose) | — |
| 6 | Validation guards | equipment_component, world_item |
| 7 | Remove ItemInstance affixes placeholder | item_instance |
| 8 | Sort methods on Inventory | inventory |
| 9 | Fix toast anchoring | theme_manager |

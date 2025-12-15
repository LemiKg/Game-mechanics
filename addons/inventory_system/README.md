# Modular Inventory System

A modular, resource-based inventory system for Godot 4 with equipment support and drag-and-drop UI.

## Features
- **Resource-based Items**: Define items as Resources (`InventoryItem`, `EquipmentItem`).
- **Component-based Logic**: Add `InventoryComponent` and `EquipmentComponent` to any node.
- **Drag and Drop UI**: Ready-to-use UI with drag-and-drop support.
- **Equipment System**: Define custom slots (Head, Body, Weapon, etc.) using `EquipmentSlotType`.

## Setup

1.  **Enable the Plugin**: Go to Project Settings -> Plugins and enable "Inventory System".
2.  **Create Slot Types**: Right-click in FileSystem -> Create New -> Resource -> `EquipmentSlotType`. Create types like "Head", "Body", "Weapon".
3.  **Create Items**:
    *   Generic Items: Create New -> Resource -> `InventoryItem`.
    *   Equipment: Create New -> Resource -> `EquipmentItem`. Assign the `Slot Type`.
4.  **Setup Player**:
    *   Add `InventoryComponent` node.
    *   Add `EquipmentComponent` node.
    *   In `EquipmentComponent`, add your `EquipmentSlotType` resources to the `Defined Slots` array.
5.  **Setup UI**:
    *   Instance `addons/inventory_system/ui/inventory_ui.tscn`.
    *   Assign the `Inventory Component` and `Equipment Component` properties in the inspector (referencing your Player's components).
    *   Assign `Equipment Container` to a container node where you want equipment slots to appear (or leave empty if you want to manually place them).

## Architecture
- **Core**: `InventoryItem`, `Inventory`, `InventoryComponent`.
- **UI**: `InventoryUI`, `SlotUI`, `EquipmentSlotUI`.
- **Separation of Concerns**: The UI listens to signals from the Components. Logic is handled in Components.

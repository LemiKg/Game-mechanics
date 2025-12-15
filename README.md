# Game Mechanics Library

A collection of reusable, modular Godot 4 addons implementing common game mechanics with clean architecture and SOLID principles.

## Purpose

This project serves as a **library of production-ready game mechanics** that can be dropped into any Godot 4 project. Each mechanic is implemented as a self-contained addon following consistent design patterns, making them easy to:

- **Integrate** — Copy the addon folder and enable in Project Settings
- **Extend** — Abstract base classes allow customization without modification
- **Combine** — Addons communicate via signals, not hard dependencies

## Available Addons

| Addon | Description | Status |
|-------|-------------|--------|
| [Inventory System](addons/inventory_system/) | Resource-based inventory with equipment, consumables, and drag-drop UI | ✅ Complete |
| [Player Control Core](addons/player_control_core/) | Shared player control framework with state machine, motor, and input routing | ✅ Complete |
| [Player Control FPS](addons/player_control_fps/) | First-person camera controller with mouse look | ✅ Complete |
| [Player Control 3rd Person](addons/player_control_3rd_person/) | Third-person orbit camera with collision | ✅ Complete |

## Addon Dependencies

```
player_control_fps ─────┐
                        ├──► player_control_core
player_control_3rd_person ─┘

inventory_system (standalone)
```

## Planned Addons

- **Dialogue System** — Branching dialogue trees with conditions and events
- **Quest System** — Quest tracking with objectives and rewards
- **Save/Load System** — Serialization framework for Resources and Nodes
- **Crafting System** — Recipe-based item crafting
- **Stat System** — RPG stats with modifiers and buffs
- **Ability System** — Cooldown-based abilities with effects

## Architecture Philosophy

All addons in this library follow these principles:

### Layer Separation

```
┌─────────────────┐
│   UI Layer      │  Display only, emits signals
├─────────────────┤
│  Logic Layer    │  Components, handlers, controllers
├─────────────────┤
│  Data Layer     │  Resources (pure data)
└─────────────────┘
```

### SOLID Compliance

- **Single Responsibility** — Each class has one job
- **Open/Closed** — Extend via inheritance, not modification
- **Liskov Substitution** — Subclasses honor base contracts
- **Interface Segregation** — Small, focused interfaces
- **Dependency Inversion** — Depend on abstractions (`@export`)

### Communication Patterns

- ✅ Signals for decoupled events
- ✅ `@export` for dependency injection
- ✅ Resources for shared data
- ❌ No `get_node()` with hardcoded paths
- ❌ No `find_parent()` or tree traversal
- ❌ No circular dependencies

## Getting Started

1. Clone this repository or download the addon you need
2. Copy the addon folder to your project's `addons/` directory
3. Enable the plugin in **Project Settings → Plugins**
4. See the addon's README for specific setup instructions

## Requirements

- Godot 4.3+
- GDScript (no C# dependencies)

## Contributing

When adding new addons, follow the [Copilot Instructions](.github/copilot-instructions.md) for architecture guidelines.

## License

MIT License — Free for personal and commercial use.

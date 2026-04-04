# UI Theme System - Design Spec

## Summary

Create a toggleable theme system with three visual themes (Medieval Fantasy, Clean Dark, Light Minimal) that can be cycled at runtime via F4. Includes a ThemeManager, background blur shader for panels, and HUD label styling. All UI elements inherit the active theme from the CanvasLayer.

## Themes

### Medieval Fantasy
- Panel: dark brown `(0.25, 0.15, 0.1, 0.95)`, 3px gold border `(0.7, 0.55, 0.2)`, 6px radius
- Slots: `(0.3, 0.2, 0.15, 1)`, 2px tan border
- Labels: warm white `(0.95, 0.9, 0.8)`, 1px dark shadow
- ProgressBar fill: gold `(0.7, 0.55, 0.2)`, background dark brown `(0.12, 0.08, 0.05, 0.8)`
- Separators: `(0.5, 0.4, 0.2, 0.6)`

### Clean Dark
- Panel: dark blue-gray `(0.08, 0.08, 0.12, 0.85)`, 1px border `(0.3, 0.3, 0.4, 0.8)`, 4px radius
- Slots: `(0.12, 0.12, 0.16, 0.9)`, 1px border `(0.25, 0.25, 0.35)`
- Labels: light gray `(0.85, 0.85, 0.9)`, no shadow
- ProgressBar fill: blue-teal `(0.2, 0.6, 0.8)`, background `(0.1, 0.1, 0.15, 0.7)`
- Separators: `(0.25, 0.25, 0.35, 0.5)`

### Light Minimal
- Panel: off-white `(0.95, 0.93, 0.9, 0.92)`, 1px border `(0.7, 0.68, 0.65)`, 6px radius
- Slots: `(0.88, 0.86, 0.83, 1)`, 1px border `(0.6, 0.58, 0.55)`
- Labels: dark `(0.15, 0.15, 0.18)`, no shadow
- ProgressBar fill: green `(0.3, 0.7, 0.4)`, background `(0.8, 0.78, 0.75, 0.6)`
- Separators: `(0.7, 0.68, 0.65, 0.4)`

## Components

### ThemeManager (Node, child of CanvasLayer)
- Holds array of Theme resources
- `current_theme_index: int` — tracks active theme
- `cycle_theme()` — advances index, applies theme to parent CanvasLayer
- Listens for F4 input to cycle
- Signal: `theme_changed(theme_name: String)`
- Applies theme via `canvas_layer.theme = themes[index]`

### Background Blur Shader
- `shaders/ui_blur.gdshader` — gaussian blur using screen texture
- Applied via `BackBufferCopy` + `ColorRect` with shader behind panels
- Blur strength configurable per theme
- Used on: inventory panel, tooltip panel

### HUD Label Styling
- Controls text and perspective label get a `PanelContainer` parent with theme-styled background
- Semi-transparent, rounded corners — readable over any terrain
- Styled automatically by the active theme's PanelContainer StyleBox

### StaminaBar Theme Integration
- StaminaBarUI reads ProgressBar styles from the active theme instead of hardcoded colors
- Fill color still lerps based on stamina ratio, but the base/low colors come from theme
- Background uses theme's ProgressBar background style

## Files

### New Files
| File | Purpose |
|------|---------|
| `addons/inventory_system/ui/themes/theme_medieval.tres` | Medieval fantasy theme resource |
| `addons/inventory_system/ui/themes/theme_dark.tres` | Clean dark theme resource |
| `addons/inventory_system/ui/themes/theme_light.tres` | Light minimal theme resource |
| `addons/inventory_system/ui/themes/theme_manager.gd` | Theme switching logic |
| `addons/inventory_system/ui/shaders/ui_blur.gdshader` | Background blur for panels |

### Modified Files
| File | Changes |
|------|---------|
| `scenes/player.tscn` | Add ThemeManager node, wrap HUD labels in PanelContainers, add blur nodes behind inventory/tooltip |
| `addons/player_control_core/ui/stamina_bar_ui.gd` | Read colors from theme instead of hardcoded |
| `project.godot` | Add F4 input action for theme cycling |

## Theme Resource Structure

Each `.tres` Theme defines overrides for these Control types:
- `PanelContainer` — main panel style (inventory, tooltip, HUD labels)
- `Panel` — secondary panels
- `Button` — if any buttons exist
- `ProgressBar` — stamina bar fill and background
- `Label` — font color, shadow color, shadow offset
- `HSeparator` / `VSeparator` — separator styling
- `HScrollBar` / `VScrollBar` — scrollbar for inventory

## Toggle

F4 key cycles: Medieval → Dark → Light → Medieval. Current theme name shown briefly as a toast notification (fades after 2s).

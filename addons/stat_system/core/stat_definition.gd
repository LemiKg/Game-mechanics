@tool
extends Resource
class_name StatDefinition
## Static schema for one stat type.
## Authored once per stat (e.g. health.tres, attack.tres) and referenced
## by every StatBlock that includes that stat.

## Unique identifier (e.g. "health", "attack"). StringName for fast lookup.
@export var id: StringName = &""

## Display name for UI (e.g. "Health").
@export var display_name: String = ""

## Base value before any modifiers are applied.
@export var base_value: float = 0.0

## Lower clamp on the final computed value.
@export var min_value: float = 0.0

## Upper clamp on the final computed value. 0 = unbounded.
@export var max_value: float = 0.0

## When true, this stat tracks a `current` value separately from its computed
## max (HP, MP, stamina). When false, it is a flat stat (attack, defense).
@export var is_resource: bool = false

## Per-second regen applied to `current` for resource stats. 0 = no regen.
@export var regen_per_second: float = 0.0

## Optional icon for UI bars/buff lists.
@export var icon: Texture2D

## Display color for UI bars.
@export var color: Color = Color.WHITE

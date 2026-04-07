@tool
extends Resource
class_name StatModifier
## One bonus applied to one stat from one source.
## Modifiers may be permanent (duration < 0) or timed (duration > 0).

enum Op { FLAT, PERCENT }

## Reason a modifier was removed. Forwarded with the modifier_removed signal.
enum RemoveReason { SOURCE_REMOVED, EXPIRED, MANUAL }

## Which stat this modifier targets (matches StatDefinition.id).
@export var stat_id: StringName = &""

## FLAT adds value directly. PERCENT contributes value to a percent sum
## that is multiplied in once by AdditivePercentFormula.
@export var op: Op = Op.FLAT

## Magnitude. For PERCENT, 10.0 means +10% of (base + flat_sum).
@export var value: float = 0.0

## Source identifier for clean removal (e.g. "iron_helmet", "haste_buff").
## remove_modifiers_by_source uses this to clear all modifiers from one source.
@export var source_id: StringName = &""

## Lifetime in seconds. -1 = permanent (default). >0 = ticks down each frame
## via StatBlock.tick().
@export var duration: float = -1.0

## Display name for buff bar UI.
@export var display_name: String = ""

## Optional icon for buff bar UI.
@export var icon: Texture2D

## Runtime: time remaining for timed modifiers. Initialized by add_modifier.
## Not exported — recomputed at runtime, not persisted.
var remaining: float = -1.0

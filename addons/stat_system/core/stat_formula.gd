@tool
extends Resource
class_name StatFormula
## Strategy resource: computes the final value of one stat from its
## definition and the list of modifiers currently targeting it.
## Subclass and override compute() to add new math rules without
## modifying StatBlock (OCP).

## @virtual Compute the final value of `definition` given `modifiers`.
## Implementations should clamp to [definition.min_value, definition.max_value]
## (treating max_value == 0 as unbounded).
func compute(definition: StatDefinition, modifiers: Array[StatModifier]) -> float:
	push_error("StatFormula.compute() is abstract — override in subclass")
	return 0.0

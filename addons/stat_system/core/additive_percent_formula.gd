@tool
extends StatFormula
class_name AdditivePercentFormula
## Default StatFormula:  final = (base + sum_flat) * (1 + sum_percent / 100)
## Result is clamped to [definition.min_value, definition.max_value],
## treating max_value == 0 as unbounded.

func compute(definition: StatDefinition, modifiers: Array[StatModifier]) -> float:
	if definition == null:
		push_warning("AdditivePercentFormula: null definition")
		return 0.0

	var sum_flat: float = 0.0
	var sum_percent: float = 0.0
	for m in modifiers:
		if m == null or m.stat_id != definition.id:
			continue
		match m.op:
			StatModifier.Op.FLAT:
				sum_flat += m.value
			StatModifier.Op.PERCENT:
				sum_percent += m.value

	var base_plus_flat: float = definition.base_value + sum_flat
	var result: float = base_plus_flat + base_plus_flat * sum_percent / 100.0

	if result < definition.min_value:
		result = definition.min_value
	if definition.max_value > 0.0 and result > definition.max_value:
		result = definition.max_value

	return result

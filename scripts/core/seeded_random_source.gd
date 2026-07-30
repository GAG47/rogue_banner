class_name SeededRandomSource
extends RefCounted

var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_random.seed = seed_value


func choose_weighted_index(weights: Array[float]) -> int:
	var total_weight: float = 0.0
	for weight: float in weights:
		if weight > 0.0 and is_finite(weight):
			total_weight += weight
	if total_weight <= 0.0:
		return -1

	var roll: float = _random.randf() * total_weight
	var accumulated: float = 0.0
	for index: int in range(weights.size()):
		var weight: float = maxf(0.0, weights[index])
		accumulated += weight
		if roll < accumulated:
			return index
	return weights.size() - 1

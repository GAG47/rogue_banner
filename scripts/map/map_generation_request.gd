class_name MapGenerationRequest
extends RefCounted

var definition: MapDefinition
var run_seed: int = 0
var generation_index: int = 0


static func create(
	map_definition: MapDefinition,
	seed: int,
	index: int
) -> MapGenerationRequest:
	var request: MapGenerationRequest = MapGenerationRequest.new()
	request.definition = map_definition
	request.run_seed = seed
	request.generation_index = index
	return request

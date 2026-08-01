class_name EnemyDeployment
extends RefCounted

var definition: EnemyDefinition
var coordinate: Vector2i


static func create(
		enemy_definition: EnemyDefinition,
		deployment_coordinate: Vector2i
) -> EnemyDeployment:
	var deployment: EnemyDeployment = EnemyDeployment.new()
	deployment.definition = enemy_definition
	deployment.coordinate = deployment_coordinate
	return deployment


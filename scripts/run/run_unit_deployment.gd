class_name RunUnitDeployment
extends RefCounted

var run_unit_id: int = 0
var coordinate: Vector2i


static func create(
		unit_instance_id: int,
		deployment_coordinate: Vector2i
) -> RunUnitDeployment:
	var deployment: RunUnitDeployment = RunUnitDeployment.new()
	deployment.run_unit_id = unit_instance_id
	deployment.coordinate = deployment_coordinate
	return deployment


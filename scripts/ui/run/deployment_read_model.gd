class_name DeploymentReadModel
extends RefCounted

var encounter_name: String = ""
var node_kind: GameEnums.MapNodeKind = GameEnums.MapNodeKind.BATTLE
var width: int = 0
var height: int = 0
var cells: Array[DeploymentCellReadModel] = []
var available_units: Array[RunUnitReadModel] = []


func get_cell(coordinate: Vector2i) -> DeploymentCellReadModel:
	for cell: DeploymentCellReadModel in cells:
		if cell.coordinate == coordinate:
			return cell
	return null

class_name RemoveRunUnitCommand
extends RunCommand

var unit_instance_id: int = 0


static func create(runtime_unit_id: int) -> RemoveRunUnitCommand:
	var command: RemoveRunUnitCommand = RemoveRunUnitCommand.new()
	command.unit_instance_id = runtime_unit_id
	return command


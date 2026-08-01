class_name UninstallArtCommand
extends RunCommand

var unit_instance_id: int = 0
var slot_index: int = -1


static func create(
		runtime_unit_id: int,
		target_slot_index: int
) -> UninstallArtCommand:
	var command: UninstallArtCommand = UninstallArtCommand.new()
	command.unit_instance_id = runtime_unit_id
	command.slot_index = target_slot_index
	return command


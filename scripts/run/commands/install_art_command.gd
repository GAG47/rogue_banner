class_name InstallArtCommand
extends RunCommand

var unit_instance_id: int = 0
var art_instance_id: int = 0
var slot_index: int = -1


static func create(
		runtime_unit_id: int,
		runtime_art_id: int,
		target_slot_index: int
) -> InstallArtCommand:
	var command: InstallArtCommand = InstallArtCommand.new()
	command.unit_instance_id = runtime_unit_id
	command.art_instance_id = runtime_art_id
	command.slot_index = target_slot_index
	return command


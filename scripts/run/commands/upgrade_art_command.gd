class_name UpgradeArtCommand
extends RunCommand

var art_instance_id: int = 0


static func create(runtime_art_id: int) -> UpgradeArtCommand:
	var command: UpgradeArtCommand = UpgradeArtCommand.new()
	command.art_instance_id = runtime_art_id
	return command


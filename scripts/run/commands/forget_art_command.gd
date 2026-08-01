class_name ForgetArtCommand
extends RunCommand

var art_instance_id: int = 0


static func create(runtime_art_id: int) -> ForgetArtCommand:
	var command: ForgetArtCommand = ForgetArtCommand.new()
	command.art_instance_id = runtime_art_id
	return command


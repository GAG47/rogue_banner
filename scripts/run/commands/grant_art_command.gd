class_name GrantArtCommand
extends RunCommand

var definition: ArtDefinition


static func create(art_definition: ArtDefinition) -> GrantArtCommand:
	var command: GrantArtCommand = GrantArtCommand.new()
	command.definition = art_definition
	return command


class_name GrantRelicCommand
extends RunCommand

var definition: RelicDefinition


static func create(relic_definition: RelicDefinition) -> GrantRelicCommand:
	var command: GrantRelicCommand = GrantRelicCommand.new()
	command.definition = relic_definition
	return command


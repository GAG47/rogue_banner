class_name GrantScrollCommand
extends RunCommand

var definition: ScrollDefinition
var quantity: int = 0


static func create(
		scroll_definition: ScrollDefinition,
		scroll_quantity: int
) -> GrantScrollCommand:
	var command: GrantScrollCommand = GrantScrollCommand.new()
	command.definition = scroll_definition
	command.quantity = scroll_quantity
	return command


class_name ConsumeScrollCommand
extends RunCommand

var stack_instance_id: int = 0
var quantity: int = 1


static func create(stack_id: int, amount: int = 1) -> ConsumeScrollCommand:
	var command: ConsumeScrollCommand = ConsumeScrollCommand.new()
	command.stack_instance_id = stack_id
	command.quantity = amount
	return command


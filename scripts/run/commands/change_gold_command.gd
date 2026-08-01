class_name ChangeGoldCommand
extends RunCommand

var amount: int = 0


static func create(gold_change: int) -> ChangeGoldCommand:
	var command: ChangeGoldCommand = ChangeGoldCommand.new()
	command.amount = gold_change
	return command


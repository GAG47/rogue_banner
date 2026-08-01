class_name HealRunUnitCommand
extends RunCommand

var unit_instance_id: int = 0
var amount: int = 0


static func create(
		runtime_unit_id: int,
		healing_amount: int
) -> HealRunUnitCommand:
	var command: HealRunUnitCommand = HealRunUnitCommand.new()
	command.unit_instance_id = runtime_unit_id
	command.amount = healing_amount
	return command


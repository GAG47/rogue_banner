class_name DamageRunUnitCommand
extends RunCommand

var unit_instance_id: int = 0
var amount: int = 0


static func create(
	runtime_unit_id: int,
	damage_amount: int
) -> DamageRunUnitCommand:
	var command: DamageRunUnitCommand = DamageRunUnitCommand.new()
	command.unit_instance_id = runtime_unit_id
	command.amount = damage_amount
	return command

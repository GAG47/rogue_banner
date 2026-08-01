class_name RecruitUnitCommand
extends RunCommand

var definition: UnitDefinition


static func create(unit_definition: UnitDefinition) -> RecruitUnitCommand:
	var command: RecruitUnitCommand = RecruitUnitCommand.new()
	command.definition = unit_definition
	return command


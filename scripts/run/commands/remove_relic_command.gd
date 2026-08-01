class_name RemoveRelicCommand
extends RunCommand

var relic_instance_id: int = 0


static func create(runtime_relic_id: int) -> RemoveRelicCommand:
	var command: RemoveRelicCommand = RemoveRelicCommand.new()
	command.relic_instance_id = runtime_relic_id
	return command


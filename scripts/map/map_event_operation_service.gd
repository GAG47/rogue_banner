class_name MapEventOperationService
extends RefCounted

var _command_service: RunCommandService
var _grant_service: RewardGrantService


func _init(
	command_service: RunCommandService = null,
	grant_service: RewardGrantService = null
) -> void:
	_command_service = command_service
	if _command_service == null:
		_command_service = RunCommandService.new()
	_grant_service = grant_service
	if _grant_service == null:
		_grant_service = RewardGrantService.new(_command_service)


func execute_in_transaction(
	run: RunState,
	operation: MapEventOperationDefinition,
	request: MapEventResolveRequest
) -> RunCommandResult:
	if run == null or operation == null or request == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_COMMAND
		)
	if operation is OpenRewardPoolMapOperationDefinition:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_COMMAND
		)
	if operation is ChangeGoldMapOperationDefinition:
		return _execute(
				run,
				ChangeGoldCommand.create(
						(operation as ChangeGoldMapOperationDefinition).amount
				)
		)
	if operation is HealUnitMapOperationDefinition:
		return _execute(
				run,
				HealRunUnitCommand.create(
						request.unit_instance_id,
						(operation as HealUnitMapOperationDefinition).amount
				)
		)
	if operation is DamageUnitMapOperationDefinition:
		return _execute(
				run,
				DamageRunUnitCommand.create(
						request.unit_instance_id,
						(operation as DamageUnitMapOperationDefinition).amount
				)
		)
	if operation is ConsumeScrollMapOperationDefinition:
		return _execute(
				run,
				ConsumeScrollCommand.create(
						request.scroll_stack_instance_id,
						(operation as ConsumeScrollMapOperationDefinition).quantity
				)
		)
	if operation is RemoveRelicMapOperationDefinition:
		return _execute(
				run,
				RemoveRelicCommand.create(request.relic_instance_id)
		)
	if operation is GrantRewardMapOperationDefinition:
		return _grant_service.grant_in_transaction(
				run,
				(operation as GrantRewardMapOperationDefinition).payload,
				request.to_reward_destination()
		)
	return RunCommandResult.failure(
			GameEnums.RunCommandCode.INVALID_COMMAND
	)


func _execute(run: RunState, command: RunCommand) -> RunCommandResult:
	return _command_service.execute_in_transaction(run, command, true)

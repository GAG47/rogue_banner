class_name RunOutcomeApplier
extends RefCounted


func apply_in_transaction(
		run: RunState,
		outcome: BattleOutcome
) -> RunCommandResult:
	if run == null:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_RUN
		)
	if run.get_phase() != GameEnums.RunPhase.IN_BATTLE:
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.OUTCOME_ALREADY_APPLIED
		)
	var session: RunBattleSessionState = (
		run._get_active_battle_session_mutable()
	)
	if (
		session == null
		or outcome == null
		or not outcome.is_terminal()
		or outcome.battle_session_id != session.battle_session_id
	):
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.BATTLE_SESSION_MISMATCH
		)

	var seen_unit_ids: Array[int] = []
	for unit_outcome: BattleUnitOutcome in outcome.unit_outcomes:
		if (
			unit_outcome == null
			or unit_outcome.source_run_unit_id <= 0
			or seen_unit_ids.has(unit_outcome.source_run_unit_id)
			or not session.participant_run_unit_ids.has(
					unit_outcome.source_run_unit_id
			)
		):
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.INVALID_BATTLE_OUTCOME
			)
		var unit: RunUnitState = run.get_unit(
				unit_outcome.source_run_unit_id
		)
		if (
			unit == null
			or unit_outcome.remaining_health < 0
			or unit_outcome.remaining_health > unit.definition.max_health
		):
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.INVALID_BATTLE_OUTCOME
			)
		seen_unit_ids.append(unit.instance_id)
	if seen_unit_ids.size() != session.participant_run_unit_ids.size():
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_BATTLE_OUTCOME
		)

	var seen_stack_ids: Array[int] = []
	for scroll_outcome: BattleScrollOutcome in outcome.scroll_outcomes:
		if (
			scroll_outcome == null
			or scroll_outcome.source_run_stack_id <= 0
			or seen_stack_ids.has(scroll_outcome.source_run_stack_id)
			or not session.scroll_stack_ids.has(
					scroll_outcome.source_run_stack_id
			)
		):
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.INVALID_BATTLE_OUTCOME
			)
		var stack: ScrollStackState = run.get_scroll(
				scroll_outcome.source_run_stack_id
		)
		if (
			stack == null
			or scroll_outcome.initial_quantity != stack.quantity
			or scroll_outcome.remaining_quantity < 0
			or scroll_outcome.remaining_quantity
			> scroll_outcome.initial_quantity
		):
			return RunCommandResult.failure(
					GameEnums.RunCommandCode.INVALID_BATTLE_OUTCOME
			)
		seen_stack_ids.append(stack.instance_id)
	if seen_stack_ids.size() != session.scroll_stack_ids.size():
		return RunCommandResult.failure(
				GameEnums.RunCommandCode.INVALID_BATTLE_OUTCOME
		)

	for unit_outcome: BattleUnitOutcome in outcome.unit_outcomes:
		run.get_unit(
			unit_outcome.source_run_unit_id
		).current_health = unit_outcome.remaining_health
	for scroll_outcome: BattleScrollOutcome in outcome.scroll_outcomes:
		var stack: ScrollStackState = run.get_scroll(
				scroll_outcome.source_run_stack_id
		)
		stack.quantity = scroll_outcome.remaining_quantity
		if stack.quantity == 0:
			run._remove_scroll_stack(stack.instance_id)
	return RunCommandResult.success()

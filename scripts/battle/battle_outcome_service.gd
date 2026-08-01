class_name BattleOutcomeService
extends RefCounted


func create_outcome(battle: BattleState) -> BattleOutcomeResult:
	if (
		battle == null
		or battle.battle_session_id <= 0
		or battle.round_number <= 0
		or battle.phase not in [
			GameEnums.BattlePhase.VICTORY,
			GameEnums.BattlePhase.FAILURE,
		]
	):
		return BattleOutcomeResult.failure(
				GameEnums.RunCommandCode.INVALID_BATTLE_OUTCOME
		)
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.battle_session_id = battle.battle_session_id
	outcome.final_phase = battle.phase
	outcome.final_round_number = battle.round_number
	for battle_unit_id: int in battle.get_run_participant_battle_ids():
		var run_unit_id: int = battle.get_run_unit_id(battle_unit_id)
		var unit: UnitState = battle.get_unit(battle_unit_id)
		outcome.unit_outcomes.append(
				BattleUnitOutcome.create(
						run_unit_id,
						unit.current_health if unit != null else 0
				)
		)
	for stack: BattleScrollStackState in battle.get_scrolls():
		outcome.scroll_outcomes.append(
				BattleScrollOutcome.create(
						stack.source_run_stack_id,
						stack.initial_quantity,
						stack.quantity
				)
		)
	return BattleOutcomeResult.success(outcome)


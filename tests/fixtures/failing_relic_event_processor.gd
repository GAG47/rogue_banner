class_name FailingRelicEventProcessor
extends BattleEventProcessor


func process(
		battle: BattleState,
		initial_events: Array[BattleEvent]
) -> BattleEventProcessResult:
	var processed: BattleEventProcessResult = super.process(
			battle,
			initial_events
	)
	if not processed.succeeded or battle.get_relics().is_empty():
		return processed
	return BattleEventProcessResult.failure(
			GameEnums.ActionFailureCode.EFFECT_EXECUTION_FAILED,
			processed.events
	)

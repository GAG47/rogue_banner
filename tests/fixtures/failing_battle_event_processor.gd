class_name FailingBattleEventProcessor
extends BattleEventProcessor

var injected_failure_code: GameEnums.ActionFailureCode = (
		GameEnums.ActionFailureCode.EFFECT_EXECUTION_FAILED
)


func process(
		_battle: BattleState,
		_initial_events: Array[BattleEvent]
) -> BattleEventProcessResult:
	return BattleEventProcessResult.failure(injected_failure_code)

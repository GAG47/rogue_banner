class_name BattleTransaction
extends RefCounted

var _target: BattleState
var working_state: BattleState


static func begin(target: BattleState) -> BattleTransaction:
	if target == null:
		return null
	var working: BattleState = target.duplicate_state()
	if working == null:
		return null
	var transaction: BattleTransaction = BattleTransaction.new()
	transaction._target = target
	transaction.working_state = working
	return transaction


func commit() -> bool:
	if _target == null or working_state == null:
		return false
	return _target._commit_from(working_state)

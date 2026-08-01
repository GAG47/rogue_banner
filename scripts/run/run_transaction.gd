class_name RunTransaction
extends RefCounted

var _target: RunState
var _source_version: int = 0
var working_state: RunState


static func begin(target: RunState) -> RunTransaction:
	if target == null:
		return null
	var working: RunState = target.duplicate_state()
	if working == null:
		return null
	var transaction: RunTransaction = RunTransaction.new()
	transaction._target = target
	transaction._source_version = target.get_state_version()
	transaction.working_state = working
	return transaction


func commit() -> bool:
	if _target == null or working_state == null:
		return false
	return _target._commit_from(working_state, _source_version)

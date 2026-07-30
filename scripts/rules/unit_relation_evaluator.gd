class_name UnitRelationEvaluator
extends RefCounted


func matches(
	actor: UnitState,
	target: UnitState,
	relation: GameEnums.TargetRelation
) -> bool:
	if actor == null or target == null:
		return false
	match relation:
		GameEnums.TargetRelation.SELF:
			return actor.instance_id == target.instance_id
		GameEnums.TargetRelation.ALLY:
			return (
				actor.instance_id != target.instance_id
				and actor.side == target.side
			)
		GameEnums.TargetRelation.ENEMY:
			return actor.side != target.side
		GameEnums.TargetRelation.NEUTRAL:
			return false
		GameEnums.TargetRelation.ANY:
			return true
	return false


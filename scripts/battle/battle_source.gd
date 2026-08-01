class_name BattleSource
extends RefCounted

var kind: GameEnums.BattleSourceKind = GameEnums.BattleSourceKind.SYSTEM
var side: GameEnums.BattleSide = GameEnums.BattleSide.PLAYER
var instance_id: int = 0
var acting_unit_id: int = 0


static func unit(
		unit_instance_id: int,
		unit_side: GameEnums.BattleSide
) -> BattleSource:
	var source: BattleSource = BattleSource.new()
	source.kind = GameEnums.BattleSourceKind.UNIT
	source.side = unit_side
	source.instance_id = unit_instance_id
	source.acting_unit_id = unit_instance_id
	return source


static func relic(
		relic_instance_id: int,
		owner_side: GameEnums.BattleSide
) -> BattleSource:
	var source: BattleSource = BattleSource.new()
	source.kind = GameEnums.BattleSourceKind.RELIC
	source.side = owner_side
	source.instance_id = relic_instance_id
	return source


static func scroll(
		stack_instance_id: int,
		owner_side: GameEnums.BattleSide,
		user_unit_id: int
) -> BattleSource:
	var source: BattleSource = BattleSource.new()
	source.kind = GameEnums.BattleSourceKind.SCROLL
	source.side = owner_side
	source.instance_id = stack_instance_id
	source.acting_unit_id = user_unit_id
	return source


static func system(system_side: GameEnums.BattleSide) -> BattleSource:
	var source: BattleSource = BattleSource.new()
	source.kind = GameEnums.BattleSourceKind.SYSTEM
	source.side = system_side
	return source


func duplicate_state() -> BattleSource:
	var source: BattleSource = BattleSource.new()
	source.kind = kind
	source.side = side
	source.instance_id = instance_id
	source.acting_unit_id = acting_unit_id
	return source


func is_valid() -> bool:
	match kind:
		GameEnums.BattleSourceKind.UNIT:
			return instance_id > 0 and acting_unit_id == instance_id
		GameEnums.BattleSourceKind.RELIC:
			return instance_id > 0 and acting_unit_id == 0
		GameEnums.BattleSourceKind.SCROLL:
			return instance_id > 0 and acting_unit_id > 0
		GameEnums.BattleSourceKind.SYSTEM:
			return instance_id == 0 and acting_unit_id == 0
	return false


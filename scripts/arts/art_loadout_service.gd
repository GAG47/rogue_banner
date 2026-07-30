class_name ArtLoadoutService
extends RefCounted

var _condition_evaluator: ConditionEvaluator


func _init(condition_evaluator: ConditionEvaluator = null) -> void:
	_condition_evaluator = condition_evaluator
	if _condition_evaluator == null:
		_condition_evaluator = ConditionEvaluator.new()


func install(
		unit: RunUnitState,
		art: ArtDefinition,
		slot_index: int
) -> ArtLoadoutResult:
	var validation: ArtLoadoutResult = validate_install(unit, art, slot_index)
	if not validation.succeeded():
		return validation
	unit.installed_arts[slot_index] = art
	return ArtLoadoutResult.success(slot_index, art)


func validate_install(
		unit: RunUnitState,
		art: ArtDefinition,
		slot_index: int
) -> ArtLoadoutResult:
	if unit == null or unit.definition == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_UNIT)
	if art == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_ART)
	if slot_index < 0 or slot_index >= unit.definition.slot_count:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_SLOT)
	_ensure_slot_count(unit)
	if unit.installed_arts[slot_index] != null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.SLOT_OCCUPIED)
	if not _has_required_tags(unit.definition, art):
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.MISSING_TAG)

	var context: ArtInstallConditionContext = ArtInstallConditionContext.create(
			unit,
			art,
			slot_index
	)
	if not _condition_evaluator.evaluate_all(
			art.installation_conditions,
			context
	).passed():
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.CONDITION_FAILED)
	return ArtLoadoutResult.success(slot_index, art)


func remove(unit: RunUnitState, slot_index: int) -> ArtLoadoutResult:
	if unit == null or unit.definition == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_UNIT)
	if slot_index < 0 or slot_index >= unit.definition.slot_count:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_SLOT)
	_ensure_slot_count(unit)
	var removed_art: ArtDefinition = unit.installed_arts[slot_index]
	if removed_art == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.SLOT_EMPTY)
	unit.installed_arts[slot_index] = null
	return ArtLoadoutResult.success(slot_index, removed_art)


func upgrade(unit: RunUnitState, slot_index: int) -> ArtLoadoutResult:
	if unit == null or unit.definition == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_UNIT)
	if slot_index < 0 or slot_index >= unit.definition.slot_count:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_SLOT)
	_ensure_slot_count(unit)
	var current_art: ArtDefinition = unit.installed_arts[slot_index]
	if current_art == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.SLOT_EMPTY)
	var upgraded_art: ArtDefinition = current_art.upgraded_variant
	if upgraded_art == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.NO_UPGRADE)
	if not _has_required_tags(unit.definition, upgraded_art):
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.MISSING_TAG)
	var context: ArtInstallConditionContext = ArtInstallConditionContext.create(
			unit,
			upgraded_art,
			slot_index
	)
	if not _condition_evaluator.evaluate_all(
			upgraded_art.installation_conditions,
			context
	).passed():
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.CONDITION_FAILED)
	unit.installed_arts[slot_index] = upgraded_art
	return ArtLoadoutResult.success(slot_index, upgraded_art)


func _has_required_tags(
		unit_definition: UnitDefinition,
		art: ArtDefinition
) -> bool:
	for required_tag: TagDefinition in art.required_tags:
		if required_tag == null:
			return false
		var found: bool = false
		for unit_tag: TagDefinition in unit_definition.tags:
			if (
				unit_tag != null
				and unit_tag.content_id == required_tag.content_id
			):
				found = true
				break
		if not found:
			return false
	return true


func _ensure_slot_count(unit: RunUnitState) -> void:
	while unit.installed_arts.size() < unit.definition.slot_count:
		unit.installed_arts.append(null)

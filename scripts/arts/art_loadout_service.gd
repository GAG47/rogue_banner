class_name ArtLoadoutService
extends RefCounted

var _condition_evaluator: ConditionEvaluator
var _definition_validator: DefinitionValidator


func _init(
		condition_evaluator: ConditionEvaluator = null,
		definition_validator: DefinitionValidator = null
) -> void:
	_condition_evaluator = condition_evaluator
	if _condition_evaluator == null:
		_condition_evaluator = ConditionEvaluator.new()
	_definition_validator = definition_validator
	if _definition_validator == null:
		_definition_validator = DefinitionValidator.new()


func install(
		unit: RunUnitState,
		art: RunArtState,
		slot_index: int
) -> ArtLoadoutResult:
	var validation: ArtLoadoutResult = validate_install(
			unit,
			art,
			slot_index
	)
	if not validation.succeeded():
		return validation
	unit.installed_art_instance_ids[slot_index] = art.instance_id
	return ArtLoadoutResult.success(
			slot_index,
			art.definition,
			art.instance_id
	)


func validate_install(
		unit: RunUnitState,
		art: RunArtState,
		slot_index: int
) -> ArtLoadoutResult:
	if art == null or art.instance_id <= 0:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_ART)
	var common: ArtLoadoutResult = _validate_slot(
			unit,
			slot_index,
			true
	)
	if not common.succeeded():
		return common
	return validate_definition_for_slot(
			unit,
			art.definition,
			slot_index
	)


func validate_definition_for_slot(
		unit: RunUnitState,
		art: ArtDefinition,
		slot_index: int
) -> ArtLoadoutResult:
	if unit == null or unit.definition == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_UNIT)
	if art == null or not _definition_validator.validate(art).is_valid():
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_ART)
	if slot_index < 0 or slot_index >= unit.definition.slot_count:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_SLOT)
	if not _has_required_tags(unit.definition, art):
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.MISSING_TAG)
	var context: ArtInstallConditionContext = ArtInstallConditionContext.create(
			unit,
			art,
			slot_index
	)
	var condition_result: ConditionResult = _condition_evaluator.evaluate_all(
			art.installation_conditions,
			context
	)
	if not condition_result.passed():
		return ArtLoadoutResult.failure(
				GameEnums.ArtLoadoutCode.CONDITION_FAILED
		)
	return ArtLoadoutResult.success(slot_index, art)


func validate_loadout(
		unit: RunUnitState,
		installed_arts: Array[RunArtState]
) -> ArtLoadoutResult:
	if unit == null or unit.definition == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_UNIT)
	if not _definition_validator.validate(unit.definition).is_valid():
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_UNIT)
	if (
		unit.installed_art_instance_ids.size()
		!= unit.definition.slot_count
		or installed_arts.size() != unit.definition.slot_count
	):
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_SLOT)
	var seen_ids: Array[int] = []
	for slot_index: int in range(installed_arts.size()):
		var art: RunArtState = installed_arts[slot_index]
		var installed_id: int = unit.installed_art_instance_ids[slot_index]
		if installed_id == 0:
			if art != null:
				return ArtLoadoutResult.failure(
						GameEnums.ArtLoadoutCode.INVALID_ART
				)
			continue
		if (
			art == null
			or art.instance_id != installed_id
			or seen_ids.has(installed_id)
		):
			return ArtLoadoutResult.failure(
					GameEnums.ArtLoadoutCode.INVALID_ART
			)
		seen_ids.append(installed_id)
		var validation: ArtLoadoutResult = validate_definition_for_slot(
				unit,
				art.definition,
				slot_index
		)
		if not validation.succeeded():
			return validation
	return ArtLoadoutResult.success(-1, null)


func validate_definition_loadout(
		unit: RunUnitState,
		definitions: Array[ArtDefinition]
) -> ArtLoadoutResult:
	if (
		unit == null
		or unit.definition == null
		or definitions.size() != unit.definition.slot_count
	):
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_UNIT)
	for slot_index: int in range(definitions.size()):
		var definition: ArtDefinition = definitions[slot_index]
		if definition == null:
			continue
		var validation: ArtLoadoutResult = validate_definition_for_slot(
				unit,
				definition,
				slot_index
		)
		if not validation.succeeded():
			return validation
	return ArtLoadoutResult.success(-1, null)


func remove(
		unit: RunUnitState,
		slot_index: int
) -> ArtLoadoutResult:
	var validation: ArtLoadoutResult = _validate_slot(
			unit,
			slot_index,
			false
	)
	if not validation.succeeded():
		return validation
	var removed_id: int = unit.installed_art_instance_ids[slot_index]
	unit.installed_art_instance_ids[slot_index] = 0
	return ArtLoadoutResult.success(slot_index, null, removed_id)


func upgrade(
		unit: RunUnitState,
		art: RunArtState,
		slot_index: int
) -> ArtLoadoutResult:
	if (
		unit == null
		or art == null
		or slot_index < 0
		or slot_index >= unit.installed_art_instance_ids.size()
		or unit.installed_art_instance_ids[slot_index] != art.instance_id
	):
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_ART)
	var upgraded_art: ArtDefinition = art.definition.upgraded_variant
	if upgraded_art == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.NO_UPGRADE)
	var validation: ArtLoadoutResult = validate_definition_for_slot(
			unit,
			upgraded_art,
			slot_index
	)
	if not validation.succeeded():
		return validation
	art.definition = upgraded_art
	return ArtLoadoutResult.success(
			slot_index,
			upgraded_art,
			art.instance_id
	)


func _validate_slot(
		unit: RunUnitState,
		slot_index: int,
		require_empty: bool
) -> ArtLoadoutResult:
	if unit == null or unit.definition == null:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_UNIT)
	if slot_index < 0 or slot_index >= unit.definition.slot_count:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.INVALID_SLOT)
	_ensure_slot_count(unit)
	var current_id: int = unit.installed_art_instance_ids[slot_index]
	if require_empty and current_id != 0:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.SLOT_OCCUPIED)
	if not require_empty and current_id == 0:
		return ArtLoadoutResult.failure(GameEnums.ArtLoadoutCode.SLOT_EMPTY)
	return ArtLoadoutResult.success(slot_index, null, current_id)


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
	while (
		unit.installed_art_instance_ids.size()
		< unit.definition.slot_count
	):
		unit.installed_art_instance_ids.append(0)

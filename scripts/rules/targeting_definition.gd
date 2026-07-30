class_name TargetingDefinition
extends Resource

@export var target_kind: GameEnums.TargetKind = GameEnums.TargetKind.UNIT
@export var target_relation: GameEnums.TargetRelation = GameEnums.TargetRelation.ENEMY
@export var minimum_range: int = 1
@export var maximum_range: int = 1
@export var minimum_targets: int = 1
@export var maximum_targets: int = 1
@export var requires_line_of_sight: bool = true
@export var affected_offsets: Array[Vector2i] = [Vector2i.ZERO]


func validate_configuration(
		result: DefinitionValidationResult,
		field_path: StringName
) -> void:
	if minimum_range < 0:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_TARGETING,
				_child_path(field_path, &"minimum_range"),
				"Minimum range cannot be negative."
		)
	if maximum_range < minimum_range:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_TARGETING,
				_child_path(field_path, &"maximum_range"),
				"Maximum range cannot be less than minimum range."
		)
	if minimum_targets < 1:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_TARGETING,
				_child_path(field_path, &"minimum_targets"),
				"Minimum targets must be at least one."
		)
	if maximum_targets < minimum_targets:
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_TARGETING,
				_child_path(field_path, &"maximum_targets"),
				"Maximum targets cannot be less than minimum targets."
		)
	if affected_offsets.is_empty():
		result.add_issue(
				GameEnums.DefinitionValidationCode.INVALID_TARGETING,
				_child_path(field_path, &"affected_offsets"),
				"Targeting requires at least one affected Cell offset."
		)
	var seen_offsets: Dictionary[Vector2i, bool] = {}
	for index: int in range(affected_offsets.size()):
		var offset: Vector2i = affected_offsets[index]
		if seen_offsets.has(offset):
			result.add_issue(
					GameEnums.DefinitionValidationCode.INVALID_TARGETING,
					StringName(
							"%s.affected_offsets[%d]"
							% [String(field_path), index]
					),
					"Affected Cell offsets cannot contain duplicates."
			)
		else:
			seen_offsets[offset] = true


func _child_path(parent: StringName, child: StringName) -> StringName:
	return StringName("%s.%s" % [String(parent), String(child)])

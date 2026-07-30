class_name IntentDefinition
extends DefinitionResource

@export var icon: Texture2D
@export var kind: GameEnums.IntentKind = GameEnums.IntentKind.LOCKED
@export var art: ArtDefinition
@export var target_rule: GameEnums.IntentTargetRule = (
		GameEnums.IntentTargetRule.NEAREST_OPPONENT_UNIT
)
@export var movement_rule: GameEnums.IntentMovementRule = (
		GameEnums.IntentMovementRule.NONE
)
@export var direction_rule: GameEnums.IntentDirectionRule = (
		GameEnums.IntentDirectionRule.TOWARD_TARGET
)
@export var fixed_direction: GameEnums.CardinalDirection = (
		GameEnums.CardinalDirection.LEFT
)
@export var sequence: GameEnums.IntentSequence = GameEnums.IntentSequence.ART_ONLY

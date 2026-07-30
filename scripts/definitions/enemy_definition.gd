class_name EnemyDefinition
extends DefinitionResource

@export var unit_definition: UnitDefinition
@export var rank: GameEnums.EnemyRank = GameEnums.EnemyRank.STANDARD
@export var available_intents: Array[IntentDefinition] = []
@export var default_decision: EnemyDecisionPolicyDefinition
@export var phases: Array[EnemyPhaseDefinition] = []

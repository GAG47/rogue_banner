class_name EncounterDefinition
extends DefinitionResource

@export var battlefield: BattlefieldDefinition
@export var enemy_spawns: Array[EnemySpawnDefinition] = []
@export var battle_rank: GameEnums.EnemyRank = GameEnums.EnemyRank.STANDARD
@export var reward_pool: RewardPoolDefinition

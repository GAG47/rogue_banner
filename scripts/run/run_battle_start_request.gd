class_name RunBattleStartRequest
extends RefCounted

var grid: GridState
var player_deployments: Array[RunUnitDeployment] = []
var enemy_deployments: Array[EnemyDeployment] = []
var floor_number: int = 1
var battle_rank: GameEnums.EnemyRank = GameEnums.EnemyRank.STANDARD
var reward_pool: RewardPoolDefinition

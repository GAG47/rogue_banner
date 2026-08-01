class_name BattleSetup
extends RefCounted

var battle_session_id: int = 0
var battle_seed: int = 0
var source_run_version: int = 0
var grid: GridState
var player_units: Array[BattleSetupUnit] = []
var enemy_deployments: Array[EnemyDeployment] = []
var relics: Array[BattleRelicState] = []
var scrolls: Array[BattleScrollStackState] = []


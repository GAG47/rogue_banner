class_name RunSessionSnapshot
extends RefCounted

var route: RunSessionRoute.Value = RunSessionRoute.Value.UNAVAILABLE
var summary: RunSummaryReadModel
var map: MapReadModel
var inventory: InventoryReadModel
var reward: RewardReadModel
var deployment: DeploymentReadModel
var event: EventReadModel
var battle: BattleReadModel

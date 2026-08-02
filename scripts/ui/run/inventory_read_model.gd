class_name InventoryReadModel
extends RefCounted

var units: Array[RunUnitReadModel] = []
var arts: Array[RunArtReadModel] = []
var relics: Array[RunRelicReadModel] = []
var scrolls: Array[RunScrollReadModel] = []
var team_capacity: int = 0
var scroll_capacity: int = 0


func get_unit(unit_id: int) -> RunUnitReadModel:
	for unit: RunUnitReadModel in units:
		if unit.instance_id == unit_id:
			return unit
	return null


func get_art(art_id: int) -> RunArtReadModel:
	for art: RunArtReadModel in arts:
		if art.instance_id == art_id:
			return art
	return null

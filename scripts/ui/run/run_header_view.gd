class_name RunHeaderView
extends HBoxContainer

signal inventory_requested
signal abandon_requested

@export var run_title_label: Label
@export var phase_label: Label
@export var gold_label: Label
@export var team_label: Label
@export var relic_label: Label
@export var scroll_label: Label
@export var inventory_button: Button
@export var abandon_button: Button


func _ready() -> void:
	inventory_button.pressed.connect(
		func() -> void: inventory_requested.emit()
	)
	abandon_button.pressed.connect(
		func() -> void: abandon_requested.emit()
	)


func present(
	summary: RunSummaryReadModel,
	route: RunSessionRoute.Value
) -> void:
	if summary == null:
		return
	run_title_label.text = "%s的远征" % summary.hero_name
	phase_label.text = RunUiTextFormatter.route_text(route)
	gold_label.text = "金币 %d" % summary.gold
	team_label.text = "队伍 %d/%d" % [
		summary.unit_count,
		summary.team_capacity,
	]
	relic_label.text = "遗物 %d" % summary.relic_count
	scroll_label.text = "卷轴 %d/%d" % [
		summary.scroll_stack_count,
		summary.scroll_capacity,
	]
	inventory_button.disabled = route != RunSessionRoute.Value.MAP
	abandon_button.disabled = route == RunSessionRoute.Value.RESULT

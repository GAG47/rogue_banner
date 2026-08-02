class_name DeploymentPanelView
extends PanelContainer

signal battle_start_requested(deployments: Array[RunUnitDeployment])

@export var encounter_label: Label
@export var unit_selector: OptionButton
@export var deployment_grid: GridContainer
@export var deployed_unit_list: VBoxContainer
@export var start_battle_button: Button
@export var reset_button: Button

var _model: DeploymentReadModel
var _assignments: Dictionary[Vector2i, int] = {}
var _unit_names: Dictionary[int, String] = {}


func _ready() -> void:
	start_battle_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_reset_assignments)


func present(model: DeploymentReadModel) -> void:
	if model == null:
		return
	var changed_encounter: bool = (
		_model == null or _model.encounter_name != model.encounter_name
	)
	_model = model
	if changed_encounter:
		_assignments.clear()
	encounter_label.text = "%s · 选择参战单位和蓝色部署格" % (
		model.encounter_name
	)
	_rebuild_unit_selector()
	_rebuild_grid()
	_refresh_assignments()


func _rebuild_unit_selector() -> void:
	unit_selector.clear()
	_unit_names.clear()
	for unit: RunUnitReadModel in _model.available_units:
		unit_selector.add_item("%s · 生命%d/%d" % [
			unit.display_name,
			unit.current_health,
			unit.maximum_health,
		])
		unit_selector.set_item_metadata(
			unit_selector.item_count - 1,
			unit.instance_id
		)
		_unit_names[unit.instance_id] = unit.display_name


func _rebuild_grid() -> void:
	_clear_children(deployment_grid)
	deployment_grid.columns = maxi(1, _model.width)
	for cell: DeploymentCellReadModel in _model.cells:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(82, 58)
		button.text = _cell_text(cell)
		button.disabled = not cell.allows_player_deployment
		if cell.allows_player_deployment:
			button.pressed.connect(
				_assign_selected_unit.bind(cell.coordinate)
			)
		deployment_grid.add_child(button)


func _cell_text(cell: DeploymentCellReadModel) -> String:
	if not cell.enemy_name.is_empty():
		return "%d,%d\n%s" % [cell.coordinate.x, cell.coordinate.y, cell.enemy_name]
	if _assignments.has(cell.coordinate):
		return "%d,%d\n%s" % [
			cell.coordinate.x,
			cell.coordinate.y,
			_unit_names.get(_assignments[cell.coordinate], "我方单位"),
		]
	return "%d,%d\n%s" % [
		cell.coordinate.x,
		cell.coordinate.y,
		"可部署" if cell.allows_player_deployment else cell.terrain_name,
	]


func _assign_selected_unit(coordinate: Vector2i) -> void:
	if unit_selector.selected < 0:
		return
	var unit_id: int = int(unit_selector.get_selected_metadata())
	var previous_cells: Array[Vector2i] = []
	for existing: Vector2i in _assignments:
		if _assignments[existing] == unit_id or existing == coordinate:
			previous_cells.append(existing)
	for existing: Vector2i in previous_cells:
		_assignments.erase(existing)
	_assignments[coordinate] = unit_id
	_rebuild_grid()
	_refresh_assignments()


func _refresh_assignments() -> void:
	_clear_children(deployed_unit_list)
	for coordinate: Vector2i in _assignments:
		var label: Label = Label.new()
		label.text = "%s → %d,%d" % [
			_unit_names.get(_assignments[coordinate], "单位"),
			coordinate.x,
			coordinate.y,
		]
		deployed_unit_list.add_child(label)
	start_battle_button.disabled = _assignments.is_empty()


func _reset_assignments() -> void:
	_assignments.clear()
	_rebuild_grid()
	_refresh_assignments()


func _on_start_pressed() -> void:
	var deployments: Array[RunUnitDeployment] = []
	for coordinate: Vector2i in _assignments:
		deployments.append(
			RunUnitDeployment.create(_assignments[coordinate], coordinate)
		)
	battle_start_requested.emit(deployments)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

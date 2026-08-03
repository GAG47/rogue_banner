class_name DeploymentPanelView
extends PanelContainer

signal battle_start_requested(deployments: Array[RunUnitDeployment])

const UNIT_CARD_MINIMUM_SIZE: Vector2 = Vector2(124.0, 76.0)
const DEPLOYMENT_COLOR: Color = Color("3ac7f2")

@export var encounter_label: Label
@export var deployment_count_label: Label
@export var board_view: BattleBoardView
@export var unit_roster: HBoxContainer
@export var start_battle_button: Button
@export var reset_button: Button

var _model: DeploymentReadModel
var _assignments: Dictionary[Vector2i, int] = {}
var _unit_models: Dictionary[int, RunUnitReadModel] = {}
var _unit_buttons: Dictionary[int, Button] = {}
var _selected_unit_id: int = 0


func _ready() -> void:
	start_battle_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_reset_assignments)
	board_view.cell_pressed.connect(_on_cell_pressed)


func present(model: DeploymentReadModel) -> void:
	if model == null:
		return
	var changed_encounter: bool = (
		_model == null
		or _model.encounter_instance_id != model.encounter_instance_id
	)
	_model = model
	_rebuild_unit_lookup()
	if changed_encounter:
		_assignments.clear()
		_selected_unit_id = 0
	_reconcile_draft()
	if _selected_unit_id <= 0:
		_select_first_unassigned_unit()
	encounter_label.text = model.encounter_name
	if changed_encounter or _roster_requires_rebuild():
		_rebuild_unit_roster()
	else:
		_refresh_unit_roster()
	_refresh_board()
	_refresh_status()


func get_rendered_cell_count() -> int:
	return board_view.get_rendered_cell_count()


func get_rendered_unit_count() -> int:
	return _unit_buttons.size()


func get_deployment_count() -> int:
	return _assignments.size()


func get_selected_unit_id() -> int:
	return _selected_unit_id


func is_unit_deployed(unit_instance_id: int) -> bool:
	return _assignments.values().has(unit_instance_id)


func select_unit(unit_instance_id: int) -> bool:
	if not _unit_models.has(unit_instance_id):
		return false
	_selected_unit_id = unit_instance_id
	_refresh_board()
	_refresh_unit_roster()
	_refresh_status()
	return true


func place_selected_unit(coordinate: Vector2i) -> bool:
	if _model == null or _selected_unit_id <= 0:
		return false
	var cell: DeploymentCellReadModel = _model.get_cell(coordinate)
	if cell == null or not cell.allows_player_deployment:
		return false
	var removed_coordinates: Array[Vector2i] = []
	for existing_coordinate: Vector2i in _assignments:
		if (
			_assignments[existing_coordinate] == _selected_unit_id
			or existing_coordinate == coordinate
		):
			removed_coordinates.append(existing_coordinate)
	for existing_coordinate: Vector2i in removed_coordinates:
		_assignments.erase(existing_coordinate)
	_assignments[coordinate] = _selected_unit_id
	_select_first_unassigned_unit()
	_refresh_board()
	_refresh_unit_roster()
	_refresh_status()
	return true


func _rebuild_unit_lookup() -> void:
	_unit_models.clear()
	for unit: RunUnitReadModel in _model.available_units:
		if unit != null:
			_unit_models[unit.instance_id] = unit


func _reconcile_draft() -> void:
	var valid_deployment_cells: Array[Vector2i] = []
	for cell: DeploymentCellReadModel in _model.cells:
		if cell != null and cell.allows_player_deployment:
			valid_deployment_cells.append(cell.coordinate)
	var invalid_coordinates: Array[Vector2i] = []
	for coordinate: Vector2i in _assignments:
		if (
			not valid_deployment_cells.has(coordinate)
			or not _unit_models.has(_assignments[coordinate])
		):
			invalid_coordinates.append(coordinate)
	for coordinate: Vector2i in invalid_coordinates:
		_assignments.erase(coordinate)
	if not _unit_models.has(_selected_unit_id):
		_selected_unit_id = 0


func _roster_requires_rebuild() -> bool:
	if _unit_buttons.size() != _model.available_units.size():
		return true
	for unit: RunUnitReadModel in _model.available_units:
		if unit == null or not _unit_buttons.has(unit.instance_id):
			return true
	return false


func _rebuild_unit_roster() -> void:
	_clear_children(unit_roster)
	_unit_buttons.clear()
	for unit: RunUnitReadModel in _model.available_units:
		if unit == null:
			continue
		var button: Button = Button.new()
		button.custom_minimum_size = UNIT_CARD_MINIMUM_SIZE
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(select_unit.bind(unit.instance_id))
		unit_roster.add_child(button)
		_unit_buttons[unit.instance_id] = button
	_refresh_unit_roster()


func _refresh_unit_roster() -> void:
	for unit: RunUnitReadModel in _model.available_units:
		if unit == null:
			continue
		var button: Button = _unit_buttons.get(unit.instance_id) as Button
		if button == null:
			continue
		button.text = "◆\n%s" % unit.display_name
		button.tooltip_text = "%s\n生命：%d/%d\n%s" % [
			unit.display_name,
			unit.current_health,
			unit.maximum_health,
			"已部署，点击后可以调整位置"
				if is_unit_deployed(unit.instance_id)
				else "尚未部署",
		]
		_apply_unit_style(button, unit.instance_id)


func _apply_unit_style(button: Button, unit_instance_id: int) -> void:
	var deployed: bool = is_unit_deployed(unit_instance_id)
	var selected: bool = unit_instance_id == _selected_unit_id
	var fill: Color = Color("172935")
	var border: Color = Color("5bbfd3")
	var text_color: Color = Color("e4f6fa")
	var border_width: int = 2
	if deployed:
		fill = Color("111a21")
		border = Color("394b55")
		text_color = Color("70818a")
		border_width = 1
	if selected:
		fill = Color("17435a")
		border = DEPLOYMENT_COLOR
		text_color = Color("f2fcff")
		border_width = 3
	button.add_theme_stylebox_override(
		"normal",
		_unit_style(fill, border, border_width)
	)
	button.add_theme_stylebox_override(
		"hover",
		_unit_style(fill.lightened(0.1), border.lightened(0.1), 3)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_unit_style(fill.darkened(0.08), border, 3)
	)
	button.add_theme_stylebox_override(
		"focus",
		_unit_style(fill, Color("e9fbff"), 3)
	)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.08))
	button.add_theme_color_override("font_pressed_color", text_color)


func _unit_style(
	fill: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 3
	return style


func _on_cell_pressed(coordinate: Vector2i) -> void:
	if _selected_unit_id <= 0 and _assignments.has(coordinate):
		select_unit(_assignments[coordinate])
		return
	place_selected_unit(coordinate)


func _select_first_unassigned_unit() -> void:
	_selected_unit_id = 0
	for unit: RunUnitReadModel in _model.available_units:
		if unit != null and not is_unit_deployed(unit.instance_id):
			_selected_unit_id = unit.instance_id
			return


func _refresh_board() -> void:
	if board_view != null and _model != null:
		board_view.present_deployment(
			_model,
			_assignments,
			_selected_unit_id
		)


func _refresh_status() -> void:
	deployment_count_label.text = "已部署  %d/%d" % [
		_assignments.size(),
		_model.available_units.size(),
	]
	start_battle_button.disabled = _assignments.is_empty()


func _reset_assignments() -> void:
	_assignments.clear()
	_select_first_unassigned_unit()
	_refresh_board()
	_refresh_unit_roster()
	_refresh_status()


func _on_start_pressed() -> void:
	var deployments: Array[RunUnitDeployment] = []
	var coordinates: Array[Vector2i] = _assignments.keys()
	coordinates.sort_custom(
		func(left: Vector2i, right: Vector2i) -> bool:
			if left.y == right.y:
				return left.x < right.x
			return left.y < right.y
	)
	for coordinate: Vector2i in coordinates:
		deployments.append(
			RunUnitDeployment.create(_assignments[coordinate], coordinate)
		)
	battle_start_requested.emit(deployments)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

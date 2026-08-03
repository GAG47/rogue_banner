class_name MapRouteGraphView
extends Control

signal node_requested(node_instance_id: int)

const MINIMUM_GRAPH_WIDTH: float = 980.0
const MAXIMUM_ROUTE_WIDTH: float = 1120.0
const GRAPH_MARGIN_X: float = 110.0
const GRAPH_MARGIN_Y: float = 64.0
const LAYER_GAP: float = 98.0
const NODE_VIEW_SIZE: Vector2 = Vector2(64.0, 64.0)
const NODE_BUTTON_SIZE: Vector2 = Vector2(44.0, 44.0)
const PAPER_EDGE: float = 30.0

const OUTER_COLOR: Color = Color("20180f")
const PAPER_COLOR: Color = Color("b69a69")
const PAPER_INNER_COLOR: Color = Color("ae9060")
const PAPER_MARK_COLOR: Color = Color("6f583718")
const FUTURE_LINE_COLOR: Color = Color("4b3a2b9c")
const COMPLETED_COLOR: Color = Color("2d625d")
const REACHABLE_COLOR: Color = Color("f0c653")
const CURRENT_COLOR: Color = Color("4baaa2")
const FUTURE_COLOR: Color = Color("675747")

var _model: MapReadModel
var _maximum_layer: int = 0
var _nodes_by_id: Dictionary[int, MapNodeState] = {}
var _node_positions: Dictionary[int, Vector2] = {}
var _node_views: Dictionary[int, Control] = {}
var _node_buttons: Dictionary[int, Button] = {}
var _tooltips_enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout_nodes)


func present(model: MapReadModel) -> void:
	_clear_generated_nodes()
	_model = model
	_nodes_by_id.clear()
	_node_positions.clear()
	_maximum_layer = 0
	if model == null:
		custom_minimum_size = Vector2(MINIMUM_GRAPH_WIDTH, 520.0)
		queue_redraw()
		return
	for node: MapNodeState in model.nodes:
		if node == null or node.definition == null:
			continue
		_nodes_by_id[node.instance_id] = node
		_maximum_layer = maxi(_maximum_layer, node.layer_index)
	custom_minimum_size = Vector2(
		MINIMUM_GRAPH_WIDTH,
		GRAPH_MARGIN_Y * 2.0 + _maximum_layer * LAYER_GAP + NODE_VIEW_SIZE.y
	)
	for node_id: int in _sorted_node_ids():
		_create_node_view(_nodes_by_id[node_id])
	_layout_nodes()
	queue_redraw()


func get_node_position(node_instance_id: int) -> Vector2:
	return _node_positions.get(node_instance_id, Vector2.ZERO)


func get_rendered_node_count() -> int:
	return _node_views.size()


func get_rendered_connection_count() -> int:
	return _model.connections.size() if _model != null else 0


func is_node_interactive(node_instance_id: int) -> bool:
	var button: Button = _node_buttons.get(node_instance_id) as Button
	return button != null and not button.disabled


func set_tooltips_enabled(enabled: bool) -> void:
	_tooltips_enabled = enabled
	for node_id: int in _node_views:
		var node: MapNodeState = _nodes_by_id.get(node_id) as MapNodeState
		var container: Control = _node_views[node_id] as Control
		var button: Button = _node_buttons.get(node_id) as Button
		var text: String = _node_tooltip(node) if enabled and node != null else ""
		container.tooltip_text = text
		if button != null:
			button.tooltip_text = text


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OUTER_COLOR)
	var paper_rect: Rect2 = Rect2(
		Vector2(PAPER_EDGE, 0.0),
		Vector2(maxf(0.0, size.x - PAPER_EDGE * 2.0), size.y)
	)
	draw_rect(paper_rect, PAPER_COLOR)
	draw_rect(
		paper_rect.grow(-10.0),
		PAPER_INNER_COLOR,
		false,
		2.0
	)
	_draw_paper_marks(paper_rect)
	if _model == null:
		return
	for connection: MapConnection in _model.connections:
		if (
			connection == null
			or not _node_positions.has(connection.from_node_id)
			or not _node_positions.has(connection.to_node_id)
		):
			continue
		var start: Vector2 = _node_positions[connection.from_node_id]
		var finish: Vector2 = _node_positions[connection.to_node_id]
		var color: Color = _connection_color(connection)
		var highlighted: bool = (
			_model.reachable_node_ids.has(connection.to_node_id)
			or _is_completed_connection(connection)
		)
		if highlighted:
			draw_line(start, finish, Color(color, 0.18), 10.0, true)
			draw_dashed_line(start, finish, color, 4.0, 11.0, true, true)
		else:
			draw_dashed_line(start, finish, color, 2.5, 10.0, true, true)
	for node_id: int in _node_positions:
		if _model.reachable_node_ids.has(node_id):
			draw_circle(
				_node_positions[node_id],
				31.0,
				Color(REACHABLE_COLOR, 0.16)
			)


func _draw_paper_marks(paper_rect: Rect2) -> void:
	for index: int in range(24):
		var x_ratio: float = float((index * 37 + 19) % 101) / 101.0
		var y_ratio: float = float((index * 61 + 11) % 97) / 97.0
		var mark_center: Vector2 = Vector2(
			paper_rect.position.x + paper_rect.size.x * x_ratio,
			paper_rect.size.y * y_ratio
		)
		draw_line(
			mark_center,
			mark_center + Vector2(float(7 + index % 11), float(index % 3 - 1)),
			PAPER_MARK_COLOR,
			1.5,
			true
		)


func _layout_nodes() -> void:
	if _model == null or _node_views.is_empty():
		return
	var graph_width: float = maxf(MINIMUM_GRAPH_WIDTH, size.x)
	var route_width: float = minf(
		MAXIMUM_ROUTE_WIDTH,
		graph_width - GRAPH_MARGIN_X * 2.0
	)
	var route_left: float = (graph_width - route_width) * 0.5
	var nodes_by_layer: Dictionary[int, Array] = {}
	for node_id: int in _sorted_node_ids():
		var node: MapNodeState = _nodes_by_id[node_id]
		if not nodes_by_layer.has(node.layer_index):
			nodes_by_layer[node.layer_index] = []
		(nodes_by_layer[node.layer_index] as Array).append(node)
	for layer_index: int in nodes_by_layer:
		var layer_nodes: Array = nodes_by_layer[layer_index]
		layer_nodes.sort_custom(
			func(left: MapNodeState, right: MapNodeState) -> bool:
				return left.column_index < right.column_index
		)
		var spacing: float = route_width / float(layer_nodes.size() + 1)
		for index: int in range(layer_nodes.size()):
			var node: MapNodeState = layer_nodes[index] as MapNodeState
			var center: Vector2 = Vector2(
				route_left
				+ spacing * float(index + 1)
				+ _horizontal_jitter(node, layer_nodes.size()),
				_layer_y(node.layer_index)
			)
			_node_positions[node.instance_id] = center
			var view: Control = _node_views[node.instance_id] as Control
			view.position = center - NODE_VIEW_SIZE * 0.5
	queue_redraw()


func _horizontal_jitter(node: MapNodeState, layer_size: int) -> float:
	if layer_size <= 1:
		return 0.0
	return float((node.instance_id * 37 + node.layer_index * 17) % 17 - 8) * 2.0


func _layer_y(layer_index: int) -> float:
	return (
		GRAPH_MARGIN_Y
		+ float(_maximum_layer - layer_index) * LAYER_GAP
		+ NODE_VIEW_SIZE.y * 0.5
	)


func _create_node_view(node: MapNodeState) -> void:
	var container: Control = Control.new()
	container.custom_minimum_size = NODE_VIEW_SIZE
	container.size = NODE_VIEW_SIZE
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.tooltip_text = _node_tooltip(node) if _tooltips_enabled else ""

	var button: Button = Button.new()
	button.position = (NODE_VIEW_SIZE - NODE_BUTTON_SIZE) * 0.5
	button.size = NODE_BUTTON_SIZE
	button.pivot_offset = NODE_BUTTON_SIZE * 0.5
	button.text = RunUiTextFormatter.node_kind_symbol(node.definition.kind)
	button.tooltip_text = container.tooltip_text
	button.add_theme_font_size_override("font_size", 27)
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if _model.reachable_node_ids.has(node.instance_id)
		else Control.CURSOR_ARROW
	)
	_apply_node_style(button, node)
	button.mouse_entered.connect(_on_node_hover_changed.bind(button, true))
	button.mouse_exited.connect(_on_node_hover_changed.bind(button, false))
	if not button.disabled:
		button.pressed.connect(_on_node_pressed.bind(node.instance_id))
	container.add_child(button)

	add_child(container)
	_node_views[node.instance_id] = container
	_node_buttons[node.instance_id] = button


func _node_tooltip(node: MapNodeState) -> String:
	var status_text: String = "后续路线"
	if _model.reachable_node_ids.has(node.instance_id):
		status_text = "可以进入"
	elif node.instance_id == _model.current_node_id:
		status_text = "当前位置"
	elif node.status == GameEnums.MapNodeStatus.RESOLVED:
		status_text = "已经完成"
	elif node.status == GameEnums.MapNodeStatus.ENTERED:
		status_text = "正在处理"
	return "%s · %s\n%s" % [
		RunUiTextFormatter.node_kind_text(node.definition.kind),
		status_text,
		node.definition.display_name,
	]


func _apply_node_style(button: Button, node: MapNodeState) -> void:
	var kind_color: Color = _node_kind_color(node.definition.kind)
	var border_color: Color = kind_color
	var fill: Color = Color("3c3025")
	var border_width: int = 3
	var text_color: Color = kind_color
	if _model.reachable_node_ids.has(node.instance_id):
		border_color = REACHABLE_COLOR
		fill = Color("4a3922")
		border_width = 5
		text_color = kind_color.lightened(0.18)
	elif node.instance_id == _model.current_node_id:
		border_color = CURRENT_COLOR
		fill = Color("304c48")
		border_width = 5
	elif node.status == GameEnums.MapNodeStatus.RESOLVED:
		border_color = COMPLETED_COLOR
		fill = Color("30433e")
	else:
		border_color = kind_color
		fill = Color("403428")
		text_color = kind_color.lightened(0.12)
	button.disabled = not _model.reachable_node_ids.has(node.instance_id)
	button.add_theme_stylebox_override(
		"normal",
		_node_style(fill, border_color, border_width)
	)
	button.add_theme_stylebox_override(
		"hover",
		_node_style(fill.lightened(0.1), border_color.lightened(0.08), 5)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_node_style(fill.darkened(0.08), border_color, 5)
	)
	button.add_theme_stylebox_override(
		"focus",
		_node_style(fill, Color("fff0b0"), 4)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_node_style(fill, border_color, border_width)
	)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)


func _node_style(
	fill: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.08, 0.045, 0.02, 0.48)
	style.shadow_size = 3
	return style


func _node_kind_color(kind: GameEnums.MapNodeKind) -> Color:
	match kind:
		GameEnums.MapNodeKind.START:
			return Color("8bc5b9")
		GameEnums.MapNodeKind.BATTLE:
			return Color("b85f50")
		GameEnums.MapNodeKind.ELITE:
			return Color("a9487c")
		GameEnums.MapNodeKind.BOSS:
			return Color("8c3040")
		GameEnums.MapNodeKind.SHOP:
			return Color("759351")
		GameEnums.MapNodeKind.CAMP:
			return Color("a84f2e")
		GameEnums.MapNodeKind.CHEST:
			return Color("5f7da4")
		GameEnums.MapNodeKind.EVENT:
			return Color("aa8125")
	return FUTURE_COLOR


func _connection_color(connection: MapConnection) -> Color:
	if _model.reachable_node_ids.has(connection.to_node_id):
		return REACHABLE_COLOR
	if _is_completed_connection(connection):
		return COMPLETED_COLOR
	return FUTURE_LINE_COLOR


func _is_completed_connection(connection: MapConnection) -> bool:
	var source: MapNodeState = _nodes_by_id.get(
		connection.from_node_id
	) as MapNodeState
	var target: MapNodeState = _nodes_by_id.get(
		connection.to_node_id
	) as MapNodeState
	return (
		source != null
		and target != null
		and source.status == GameEnums.MapNodeStatus.RESOLVED
		and target.status == GameEnums.MapNodeStatus.RESOLVED
	)


func _sorted_node_ids() -> Array[int]:
	var ids: Array[int] = []
	for node_id: int in _nodes_by_id:
		ids.append(node_id)
	ids.sort_custom(
		func(left_id: int, right_id: int) -> bool:
			var left: MapNodeState = _nodes_by_id[left_id]
			var right: MapNodeState = _nodes_by_id[right_id]
			if left.layer_index == right.layer_index:
				return left.column_index < right.column_index
			return left.layer_index < right.layer_index
	)
	return ids


func _on_node_pressed(node_instance_id: int) -> void:
	node_requested.emit(node_instance_id)


func _on_node_hover_changed(button: Button, hovered: bool) -> void:
	if button == null:
		return
	button.scale = Vector2.ONE * (1.22 if hovered else 1.0)
	button.z_index = 10 if hovered else 0


func _clear_generated_nodes() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_node_views.clear()
	_node_buttons.clear()

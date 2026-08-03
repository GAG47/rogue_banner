class_name MapPanelView
extends PanelContainer

signal node_requested(node_instance_id: int)

@export var route_scroll: ScrollContainer
@export var route_graph: MapRouteGraphView

var _model: MapReadModel


func _ready() -> void:
	route_graph.node_requested.connect(_on_node_pressed)


func present(model: MapReadModel) -> void:
	_model = model
	if model == null:
		route_graph.present(null)
		return
	route_graph.present(model)
	call_deferred("_center_current_node")


func _on_node_pressed(node_instance_id: int) -> void:
	node_requested.emit(node_instance_id)


func set_tooltips_enabled(enabled: bool) -> void:
	route_graph.set_tooltips_enabled(enabled)


func _center_current_node() -> void:
	if _model == null or route_scroll == null:
		return
	var position: Vector2 = route_graph.get_node_position(
		_model.current_node_id
	)
	var maximum_scroll: int = maxi(
		0,
		int(route_scroll.get_v_scroll_bar().max_value)
		- int(route_scroll.get_v_scroll_bar().page)
	)
	route_scroll.scroll_vertical = clampi(
		int(position.y - route_scroll.size.y * 0.58),
		0,
		maximum_scroll
	)

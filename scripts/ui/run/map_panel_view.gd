class_name MapPanelView
extends PanelContainer

signal node_requested(node_instance_id: int)

@export var node_list: VBoxContainer
@export var node_detail_label: Label


func present(model: MapReadModel) -> void:
	_clear_children(node_list)
	if model == null:
		node_detail_label.text = "路线数据不可用。"
		return
	var nodes: Array[MapNodeState] = model.nodes.duplicate()
	nodes.sort_custom(
		func(left: MapNodeState, right: MapNodeState) -> bool:
			if left.layer_index == right.layer_index:
				return left.column_index < right.column_index
			return left.layer_index < right.layer_index
	)
	for node: MapNodeState in nodes:
		if node == null or not model.visible_node_ids.has(node.instance_id):
			continue
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 48)
		var current_mark: String = "  ← 当前" if (
			node.instance_id == model.current_node_id
		) else ""
		button.text = "第%d层 · %s · %s%s" % [
			node.layer_index,
			RunUiTextFormatter.node_kind_text(node.definition.kind),
			node.definition.display_name,
			current_mark,
		]
		var reachable: bool = model.reachable_node_ids.has(node.instance_id)
		button.disabled = not reachable
		if reachable:
			button.pressed.connect(
				_on_node_pressed.bind(node.instance_id)
			)
		node_list.add_child(button)
	node_detail_label.text = (
		"选择高亮的相邻节点继续远征。节点内容在地图生成时已经确定。"
	)


func _on_node_pressed(node_instance_id: int) -> void:
	node_requested.emit(node_instance_id)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

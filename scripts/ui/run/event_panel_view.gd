class_name EventPanelView
extends PanelContainer

signal choice_requested(choice_id: StringName)
signal result_execute_requested(request: MapEventResolveRequest)

@export var title_label: Label
@export var detail_label: Label
@export var choice_list: VBoxContainer
@export var target_unit_selector: OptionButton
@export var execute_button: Button

var _model: EventReadModel


func _ready() -> void:
	execute_button.pressed.connect(_on_execute_pressed)


func present(model: EventReadModel, inventory: InventoryReadModel) -> void:
	_model = model
	_clear_children(choice_list)
	target_unit_selector.clear()
	if model == null:
		title_label.text = "事件不可用"
		return
	title_label.text = model.title
	for unit: RunUnitReadModel in inventory.units:
		target_unit_selector.add_item("%s · 生命%d/%d" % [
			unit.display_name,
			unit.current_health,
			unit.maximum_health,
		])
		target_unit_selector.set_item_metadata(
			target_unit_selector.item_count - 1,
			unit.instance_id
		)
	var choosing: bool = (
		model.stage == GameEnums.MapSessionStage.EVENT_CHOICE
	)
	for choice: EventChoiceReadModel in model.choices:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 46)
		button.text = choice.display_name
		button.disabled = not choosing or not choice.available
		button.tooltip_text = choice.unavailable_reason
		button.pressed.connect(
			_on_choice_pressed.bind(choice.choice_id)
		)
		choice_list.add_child(button)
	execute_button.visible = not choosing
	target_unit_selector.visible = not choosing
	detail_label.text = (
		"选择一个结果。不可用选项会显示失败原因。"
		if choosing
		else (
			"已选择：%s\n结果已经确定。选择目标后执行；失败重试不会重新抽取结果。"
			% model.selected_choice_name
		)
	)


func _on_choice_pressed(choice_id: StringName) -> void:
	choice_requested.emit(choice_id)


func _on_execute_pressed() -> void:
	var request: MapEventResolveRequest = MapEventResolveRequest.new()
	if target_unit_selector.selected >= 0:
		request.unit_instance_id = int(
			target_unit_selector.get_selected_metadata()
		)
	result_execute_requested.emit(request)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

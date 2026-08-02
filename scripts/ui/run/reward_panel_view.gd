class_name RewardPanelView
extends PanelContainer

signal option_claim_requested(
	offer_id: int,
	option_id: int,
	destination: RewardGrantDestination
)
signal option_skip_requested(offer_id: int, option_id: int)
signal offer_finish_requested(offer_id: int)
signal offer_take_all_requested(offer_id: int)
signal shop_close_requested(offer_id: int)
signal scroll_discard_requested(stack_instance_id: int)

@export var title_label: Label
@export var option_list: VBoxContainer
@export var target_unit_selector: OptionButton
@export var target_art_selector: OptionButton
@export var scroll_selector: OptionButton
@export var discard_scroll_button: Button
@export var finish_button: Button
@export var take_all_button: Button
@export var close_shop_button: Button

var _model: RewardReadModel


func _ready() -> void:
	finish_button.pressed.connect(
		func() -> void: offer_finish_requested.emit(_model.offer_id)
	)
	take_all_button.pressed.connect(
		func() -> void: offer_take_all_requested.emit(_model.offer_id)
	)
	close_shop_button.pressed.connect(
		func() -> void: shop_close_requested.emit(_model.offer_id)
	)
	discard_scroll_button.pressed.connect(_on_discard_scroll_pressed)


func present(
	model: RewardReadModel,
	inventory: InventoryReadModel,
	is_shop: bool
) -> void:
	_model = model
	_clear_children(option_list)
	if model == null:
		title_label.text = "奖励不可用"
		return
	title_label.text = "商店" if is_shop else "节点奖励"
	_rebuild_destinations(inventory)
	for option: RewardOptionReadModel in model.options:
		_add_option(option, is_shop)
	finish_button.visible = model.rule == GameEnums.RewardOfferRule.PICK_ANY
	take_all_button.visible = model.rule == GameEnums.RewardOfferRule.TAKE_ALL
	close_shop_button.visible = is_shop
	var can_discard: bool = (
		inventory != null and not inventory.scrolls.is_empty()
	)
	scroll_selector.visible = can_discard and not is_shop
	discard_scroll_button.visible = can_discard and not is_shop


func _add_option(option: RewardOptionReadModel, is_shop: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "%s\n%s%s" % [
		option.title,
		option.detail,
		" · %d金币" % option.price if is_shop else "",
	]
	row.add_child(label)
	if option.status == GameEnums.RewardOptionStatus.AVAILABLE:
		var claim: Button = Button.new()
		claim.text = "购买" if is_shop else "领取"
		claim.pressed.connect(
			_on_claim_pressed.bind(option)
		)
		row.add_child(claim)
		if _model.rule == GameEnums.RewardOfferRule.PICK_ANY:
			var skip: Button = Button.new()
			skip.text = "放弃"
			skip.pressed.connect(
				_on_skip_pressed.bind(option.option_id)
			)
			row.add_child(skip)
	else:
		var status: Label = Label.new()
		status.text = _option_status_text(option.status)
		row.add_child(status)
	option_list.add_child(row)


func _on_claim_pressed(option: RewardOptionReadModel) -> void:
	option_claim_requested.emit(
		_model.offer_id,
		option.option_id,
		_build_destination(option)
	)


func _on_skip_pressed(option_id: int) -> void:
	option_skip_requested.emit(_model.offer_id, option_id)


func _option_status_text(status: GameEnums.RewardOptionStatus) -> String:
	match status:
		GameEnums.RewardOptionStatus.CLAIMED:
			return "已领取"
		GameEnums.RewardOptionStatus.SOLD:
			return "已购买"
		GameEnums.RewardOptionStatus.SKIPPED:
			return "已放弃"
	return "已关闭"


func _rebuild_destinations(inventory: InventoryReadModel) -> void:
	target_unit_selector.clear()
	target_art_selector.clear()
	scroll_selector.clear()
	if inventory == null:
		return
	for unit: RunUnitReadModel in inventory.units:
		target_unit_selector.add_item(unit.display_name)
		target_unit_selector.set_item_metadata(
			target_unit_selector.item_count - 1,
			unit.instance_id
		)
	for art: RunArtReadModel in inventory.arts:
		target_art_selector.add_item(art.display_name)
		target_art_selector.set_item_metadata(
			target_art_selector.item_count - 1,
			art.instance_id
		)
	for scroll: RunScrollReadModel in inventory.scrolls:
		scroll_selector.add_item("%s × %d" % [
			scroll.display_name,
			scroll.quantity,
		])
		scroll_selector.set_item_metadata(
			scroll_selector.item_count - 1,
			scroll.stack_instance_id
		)


func _build_destination(
	option: RewardOptionReadModel
) -> RewardGrantDestination:
	if option.requires_unit_target and target_unit_selector.selected >= 0:
		return RewardGrantDestination.unit(
			int(target_unit_selector.get_selected_metadata())
		)
	if option.requires_art_target and target_art_selector.selected >= 0:
		return RewardGrantDestination.art(
			int(target_art_selector.get_selected_metadata())
		)
	return RewardGrantDestination.none()


func _on_discard_scroll_pressed() -> void:
	if scroll_selector.selected >= 0:
		scroll_discard_requested.emit(
			int(scroll_selector.get_selected_metadata())
		)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

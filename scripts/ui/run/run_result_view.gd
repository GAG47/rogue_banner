class_name RunResultView
extends PanelContainer

signal new_run_requested

@export var title_label: Label
@export var detail_label: Label
@export var new_run_button: Button


func _ready() -> void:
	new_run_button.pressed.connect(func() -> void: new_run_requested.emit())


func present(summary: RunSummaryReadModel) -> void:
	if summary == null:
		return
	match summary.end_reason:
		GameEnums.RunEndReason.VICTORY:
			title_label.text = "远征胜利"
			detail_label.text = "你击败了路线首领，完成了第一局完整远征。"
		GameEnums.RunEndReason.DEFEAT:
			title_label.text = "远征失败"
			detail_label.text = "队伍在战斗中全军覆没。"
		GameEnums.RunEndReason.ABANDONED:
			title_label.text = "远征已放弃"
			detail_label.text = "本局已经结束，可以使用同一套内容重新开始。"
		_:
			title_label.text = "远征结束"
			detail_label.text = "本局流程已经结束。"

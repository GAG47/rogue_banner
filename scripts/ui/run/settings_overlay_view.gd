class_name SettingsOverlayView
extends ColorRect

signal closed
signal abandon_requested
signal tooltips_changed(enabled: bool)

@export var fullscreen_check_box: CheckBox
@export var tooltip_check_box: CheckBox
@export var abandon_run_button: Button
@export var close_button: Button


func _ready() -> void:
	fullscreen_check_box.toggled.connect(_on_fullscreen_toggled)
	tooltip_check_box.toggled.connect(
		func(enabled: bool) -> void: tooltips_changed.emit(enabled)
	)
	abandon_run_button.pressed.connect(
		func() -> void: abandon_requested.emit()
	)
	close_button.pressed.connect(func() -> void: closed.emit())


func present(tooltips_enabled: bool, can_abandon: bool) -> void:
	visible = true
	fullscreen_check_box.set_pressed_no_signal(
		DisplayServer.window_get_mode() in [
			DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		]
	)
	tooltip_check_box.set_pressed_no_signal(tooltips_enabled)
	abandon_run_button.disabled = not can_abandon


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)

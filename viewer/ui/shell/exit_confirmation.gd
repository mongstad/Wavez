extends Window
## Application exit only; job owners retain their existing cancellation protocol.
signal exit_requested
var exit_button: Button
var cancel_button: Button

func setup(owner_shell) -> void:
	title = "WAVEZ • Exit"
	borderless = true; exclusive = true; transient = true; visible = false
	theme = owner_shell.style_slice.theme
	close_requested.connect(hide)
	window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: hide())
	var surface := PanelContainer.new(); add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_theme_stylebox_override("panel", theme.flat_box(&"surface.1", 16, 16, 0))
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation", 16); surface.add_child(content)
	var heading := Label.new(); heading.text = "Active jobs are still running"
	heading.theme_type_variation = "PanelTitle"; content.add_child(heading)
	var message := Label.new(); message.text = "Exiting WAVEZ will cancel all active jobs."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(message)
	var space := Control.new(); space.size_flags_vertical = Control.SIZE_EXPAND_FILL; content.add_child(space)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 16); content.add_child(actions)
	exit_button = Button.new(); exit_button.text = "Exit WAVEZ"
	exit_button.theme_type_variation = "DestructiveButton"; actions.add_child(exit_button)
	exit_button.pressed.connect(func(): hide(); exit_requested.emit())
	cancel_button = Button.new(); cancel_button.text = "Cancel"
	cancel_button.theme_type_variation = "SecondaryButton"; actions.add_child(cancel_button)
	cancel_button.pressed.connect(hide)
	theme.style_dialog_actions(self)

func open() -> void:
	popup_centered(Vector2i(480, 160))
	cancel_button.grab_focus()
	cancel_button.grab_focus.call_deferred()

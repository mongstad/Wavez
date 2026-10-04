extends Window
## Edit → Preferences → File Locations. Drafts are committed together on Apply.
const Locations = preload("res://ui/file_locations_preferences.gd")
const Job = preload("res://video/render_job.gd")
var shell
var draft: Dictionary = {}
var fields: Dictionary = {}
var mode_choice: OptionButton
var ffmpeg_path: LineEdit
var ffmpeg_browse: Button
var notice: Label
var apply_button: Button
var reset_button: Button
var pickers: Dictionary = {}
var previous_focus: WeakRef

func setup(owner_shell) -> void:
	shell = owner_shell
	title = "WAVEZ • File Locations"
	borderless = true
	min_size = Vector2i(560, 280)
	size = Vector2i(740, 310)
	visible = false
	theme = shell.style_slice.theme
	close_requested.connect(dismiss)
	window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: dismiss())
	var surface := PanelContainer.new(); add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_theme_stylebox_override("panel", theme.flat_box(&"surface.1", 16, 16, 0))
	var margin := MarginContainer.new(); surface.add_child(margin)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 10); margin.add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	var heading := Label.new(); heading.text = "File Locations"; heading.theme_type_variation = "PanelTitle"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	shell.close_action(header, dismiss, "Close File Locations")
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus = true; column.add_child(scroll)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8); scroll.add_child(rows)
	var ffmpeg_row := _row(rows, "FFmpeg")
	mode_choice = OptionButton.new(); mode_choice.custom_minimum_size.x = 132
	mode_choice.add_item("Auto-detect"); mode_choice.add_item("Custom"); ffmpeg_row.add_child(mode_choice)
	ffmpeg_path = LineEdit.new(); ffmpeg_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ffmpeg_path.editable = false; ffmpeg_path.placeholder_text = "Not found"; ffmpeg_row.add_child(ffmpeg_path)
	ffmpeg_browse = _browse(ffmpeg_row, "ffmpeg")
	mode_choice.item_selected.connect(func(index: int):
		draft.ffmpeg_mode = "auto" if index == 0 else "custom"
		_refresh_ffmpeg())
	for entry in [["Video exports", "video_dir"], ["Image exports", "image_dir"], ["Log files", "log_dir"]]:
		var row := _row(rows, entry[0])
		var field := LineEdit.new(); field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.placeholder_text = "System default (user://logs)" if entry[1] == "log_dir" else "Choose a directory"
		if entry[1] == "log_dir": field.tooltip_text = ProjectSettings.globalize_path("user://logs")
		row.add_child(field); fields[entry[1]] = field
		field.text_changed.connect(_directory_edited.bind(entry[1]))
		_browse(row, entry[1])
	notice = Label.new(); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.theme_type_variation = "PropertyLabel"; column.add_child(notice); notice.hide()
	var footer := HBoxContainer.new(); footer.add_theme_constant_override("separation", 8); column.add_child(footer)
	reset_button = Button.new(); reset_button.text = "Reset Defaults"; footer.add_child(reset_button)
	reset_button.pressed.connect(func(): draft = Locations.defaults(); _refresh())
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; footer.add_child(spacer)
	var cancel := Button.new(); cancel.text = "Cancel"; cancel.pressed.connect(dismiss); footer.add_child(cancel)
	apply_button = Button.new(); apply_button.text = "Apply"; apply_button.theme_type_variation = "PrimaryButton"
	apply_button.pressed.connect(commit); footer.add_child(apply_button)
	_build_pickers()

func _row(parent: VBoxContainer, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); parent.add_child(row)
	var label := Label.new(); label.text = caption; label.custom_minimum_size.x = 125; row.add_child(label)
	return row

func _browse(row: HBoxContainer, key: String) -> Button:
	var button := Button.new(); button.text = "Browse…"; button.theme_type_variation = "SecondaryButton"
	row.add_child(button); button.pressed.connect(_open_picker.bind(key))
	return button

func _build_pickers() -> void:
	for key in ["ffmpeg", "video_dir", "image_dir", "log_dir"]:
		var picker := FileDialog.new()
		picker.access = FileDialog.ACCESS_FILESYSTEM
		picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE if key == "ffmpeg" else FileDialog.FILE_MODE_OPEN_DIR
		picker.use_native_dialog = true; picker.mode_overrides_title = false
		picker.title = "Choose FFmpeg executable" if key == "ffmpeg" else "Choose " + {"video_dir":"video export", "image_dir":"image export", "log_dir":"log file"}[key] + " directory"
		add_child(picker); pickers[key] = picker
		if key == "ffmpeg": picker.file_selected.connect(_selected_ffmpeg)
		else: picker.dir_selected.connect(_selected_directory.bind(key))

func open() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	previous_focus = weakref(focused) if focused != null else null
	draft = shell.viewer.file_locations.snapshot()
	_refresh()
	var available: Vector2 = shell.viewer.get_viewport().get_visible_rect().size - Vector2(32, 32)
	popup_centered(Vector2i(Vector2(740, 310).min(available)))

func dismiss() -> void:
	for picker in pickers.values(): picker.hide()
	draft.clear(); hide()
	if previous_focus != null:
		var prior = previous_focus.get_ref()
		if is_instance_valid(prior) and prior.is_visible_in_tree(): prior.grab_focus()
	previous_focus = null

func _refresh() -> void:
	mode_choice.select(0 if draft.ffmpeg_mode == "auto" else 1)
	for key in fields: fields[key].text = draft[key]
	_refresh_ffmpeg()
	notice.text = ""; notice.hide()
	apply_button.disabled = draft == shell.viewer.file_locations.snapshot()

func _refresh_ffmpeg() -> void:
	var custom: bool = draft.ffmpeg_mode == "custom"
	var path: String = draft.ffmpeg_path if custom else Job.find_ffmpeg()
	var problem := Job.ffmpeg_problem(path) if not path.is_empty() else "Not found"
	ffmpeg_path.text = path if problem.is_empty() else (path + " — " + problem if custom and not path.is_empty() else problem)
	ffmpeg_path.tooltip_text = ffmpeg_path.text
	ffmpeg_browse.text = "Browse…"
	apply_button.disabled = draft == shell.viewer.file_locations.snapshot()

func _open_picker(key: String) -> void:
	var picker: FileDialog = pickers[key]
	var path: String = draft.ffmpeg_path if key == "ffmpeg" else draft[key]
	if not path.is_empty(): picker.current_dir = path.get_base_dir() if key == "ffmpeg" else path
	picker.popup_centered_ratio(.75)

func _selected_ffmpeg(path: String) -> void:
	draft.ffmpeg_mode = "custom"
	draft.ffmpeg_path = path
	_refresh_ffmpeg()

func _selected_directory(path: String, key: String) -> void:
	draft[key] = path
	fields[key].text = path
	apply_button.disabled = draft == shell.viewer.file_locations.snapshot()

func _directory_edited(value: String, key: String) -> void:
	draft[key] = value
	apply_button.disabled = draft == shell.viewer.file_locations.snapshot()

func commit() -> void:
	if apply_button.disabled: return
	var previous_log_dir: String = shell.viewer.file_locations.settings.log_dir
	var error: String = shell.viewer.file_locations.save(draft)
	if not error.is_empty():
		notice.text = error; notice.show()
		return
	draft = shell.viewer.file_locations.snapshot()
	_refresh()
	if draft.log_dir != previous_log_dir:
		notice.text = "Saved. The log directory changes with the next Wavez session."
		notice.show()

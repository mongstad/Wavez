extends PanelContainer
## Development-only, capture-free showcase. Not referenced by Main.tscn or production scripts.
const T = preload("res://ui/theme/simscope_tokens.tres")
const DARK = preload("res://ui/theme/simscope_dark.tres")
const Scale = preload("res://ui/theme/ui_scale.gd")
const Action = preload("res://ui/components/action_button.gd")
const Number = preload("res://ui/components/number_field.gd")
const Property = preload("res://ui/components/property_row.gd")
const Disclosure = preload("res://ui/components/disclosure.gd")
const Enum = preload("res://ui/components/enum_field.gd")
const Message = preload("res://ui/components/inline_message.gd")
const Progress = preload("res://ui/components/progress_status.gd")
const Dialog = preload("res://ui/components/dialog_shell.gd")
const Scalar = preload("res://ui/components/scalar_slider.gd")
var manage_window := true
var tabs := TabContainer.new()
var grids: Array[GridContainer] = []
var specimens: Dictionary = {}
var event_label := Label.new()
var scale_picker := OptionButton.new()
var dialog

func _ready() -> void:
	theme = DARK; theme_type_variation = &"AtmosphericSurface"
	if manage_window:
		get_window().title = "SimScope · UI Laboratory · Midnight Scientific"
		Scale.apply(get_window(), 1.0)
	var layout := VBoxContainer.new(); add_child(layout)
	var header := HFlowContainer.new(); layout.add_child(header)
	# Small identity marks leave controls and content visually dominant.
	for role in [&"accent.primary", &"identity.purple", &"identity.teal"]:
		var mark := ColorRect.new(); mark.color = T.color(role)
		mark.custom_minimum_size = Vector2(4, 16)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE; header.add_child(mark)
	var title := label("SimScope / UI Laboratory", &"ApplicationTitle")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF; header.add_child(title)
	var subtitle := label("Midnight Scientific · UX2", &"SecondaryLabel")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF; header.add_child(subtitle)
	for factor in T.scales: scale_picker.add_item("%d%%" % roundi(factor * 100))
	scale_picker.tooltip_text = "Interface scale; logical tokens are applied once at the window boundary."
	header.add_child(scale_picker)
	scale_picker.item_selected.connect(func(index: int):
		if manage_window: Scale.apply(get_window(), T.scales[index]))
	layout.add_child(tabs); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_controls(); _numbers(); _status(); _tokens(); _tiers()
	event_label.theme_type_variation = &"StatusLabel"
	event_label.text = "Ready · Tab to move focus · Enter to commit numbers · Escape to restore a draft"
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(event_label)
	resized.connect(_layout_grids); _layout_grids()

func label(text: String, role: StringName = &"") -> Label:
	var value := Label.new(); value.text = text; value.theme_type_variation = role
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return value

func page(title: String) -> GridContainer:
	var scroll := ScrollContainer.new(); scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var grid := GridContainer.new(); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid); grids.append(grid)
	return grid

func group(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new(); panel.theme_type_variation = &"PropertyGroup"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var content := VBoxContainer.new(); panel.add_child(content)
	content.add_child(label(title, &"PanelTitle")); content.add_child(HSeparator.new())
	return content

func flow(parent: Control) -> HFlowContainer:
	var row := HFlowContainer.new(); parent.add_child(row); return row

func action(parent: Control, id: String, title: String, role: StringName = &"SecondaryButton"):
	var control = Action.new(); control.configure(StringName(id), title, role)
	parent.add_child(control); specimens[id] = control
	control.invoked.connect(func(key: StringName): event_label.text = "Action intent: " + key)
	return control

func row(parent: Control, title: String, editor: Control, units: String = "", help: String = ""):
	var control = Property.new(); parent.add_child(control); control.configure(title, editor, units, help)
	return control

func _controls() -> void:
	var grid := page("Controls")
	var buttons := group(grid, "Actions & states")
	var actions := flow(buttons)
	action(actions, "open", "Open capture…", &"PrimaryButton")
	action(actions, "save", "Save recipe…")
	action(actions, "delete", "Remove selection", &"DestructiveButton")
	var state_row := flow(buttons)
	var selected = action(state_row, "selected", "Selected", &"SelectedButton")
	selected.button.icon = DARK.icon_named("check", &"selection.text")
	selected.button.toggle_mode = true; selected.button.set_pressed_no_signal(true)
	var pressed = action(state_row, "pressed", "Pressed")
	pressed.button.toggle_mode = true; pressed.button.set_pressed_no_signal(true)
	action(state_row, "compact", "Compact · 28 px", &"CompactButton").button.custom_minimum_size.y = T.compact_height
	var icon = action(state_row, "play_icon", "Play preview", &"IconAction")
	icon.set_icon(DARK.icon_named("play"), true)
	var disabled = action(buttons, "unavailable", "Export unavailable")
	disabled.set_available(false, "No capture is loaded. Open a capture before exporting.")
	buttons.add_child(label("Hover and press controls; keyboard focus remains visible independently of selection.", &"HelpLabel"))
	var menu := MenuButton.new(); menu.text = "Example menu…"; buttons.add_child(menu)
	menu.get_popup().theme = DARK
	menu.get_popup().add_item("Open capture…"); menu.get_popup().add_check_item("Show guides"); menu.get_popup().set_item_checked(1, true)
	menu.get_popup().add_separator(); menu.get_popup().add_item("Export unavailable"); menu.get_popup().set_item_disabled(3, true)
	menu.get_popup().id_pressed.connect(func(id: int): event_label.text = "Menu intent: %d" % id)
	specimens.menu = menu
	var inputs := group(grid, "Inputs & choices")
	var search := LineEdit.new(); search.placeholder_text = "Search properties"; search.clear_button_enabled = true
	search.right_icon = DARK.icon_named("search", &"text.muted"); search.theme_type_variation = &"SearchInput"
	inputs.add_child(search); specimens.search = search
	var checks := flow(inputs)
	for entry in [["Visible", true, false], ["Unchecked", false, false], ["Unavailable", false, true]]:
		var check := CheckBox.new(); check.text = entry[0]; check.button_pressed = entry[1]; check.disabled = entry[2]; checks.add_child(check)
	var radios := flow(inputs); var radio_group := ButtonGroup.new()
	for title in ["Linear", "Logarithmic"]:
		var radio := CheckBox.new(); radio.text = title; radio.button_group = radio_group; radio.button_pressed = title == "Linear"; radios.add_child(radio)
	var choice = Enum.new(); row(inputs, "Channel", choice)
	choice.set_options([{"id": &"rho", "label": "Density · kg/m³"}, {"id": &"temperature", "label": "Temperature · K"}, {"id": &"pressure", "label": "Pressure unavailable", "available": false, "reason": "The fixture has no pressure channel."}], &"rho")
	specimens.enum = choice
	var scalar = Scalar.new(); scalar.configure(0.0, 4.0, 0.01, 1.25); row(inputs, "Size multiplier", scalar, "×", "Approximate display parameter; scientific values use the Numbers tab.")
	specimens.scalar = scalar
	var disabled_slider := HSlider.new(); disabled_slider.editable = false; disabled_slider.value = 45; disabled_slider.custom_minimum_size.y = 32
	row(inputs, "Unavailable", disabled_slider, "", "No source is loaded; the slider is unavailable.")
	var spin := preload("res://ui/components/visual_spin_box.gd").new(); spin.min_value = 0; spin.max_value = 100; spin.step = 0.1; spin.value = 12.5
	row(inputs, "Native spin box", spin, "×", "For bounded approximate display settings only."); specimens.spin = spin
	var collections := group(grid, "Tree & exact columns")
	var tree := Tree.new(); tree.columns = 2; tree.hide_root = true; tree.custom_minimum_size.y = 152
	tree.set_column_title(0, "Object"); tree.set_column_title(1, "State"); tree.column_titles_visible = true
	var root_item := tree.create_item()
	for entry in [["Particles", "Exact source sample"], ["Surface mesh", "Held scalar"], ["Density field", "Unavailable"]]:
		var item := tree.create_item(root_item); item.set_text(0, entry[0]); item.set_text(1, entry[1])
		if entry[0] == "Particles": item.select(0)
	collections.add_child(tree); specimens.tree = tree
	collections.add_child(label("Selected rows have a leading marker. Scientific availability is always stated in text.", &"HelpLabel"))
	var lists := group(grid, "Lists & disclosure")
	var list := ItemList.new(); list.custom_minimum_size.y = 120
	for title in ["Particle IDs", "World-space region", "Derived selection"]: list.add_item(title)
	list.select(0); lists.add_child(list); specimens.list = list
	var body := VBoxContainer.new(); body.add_child(label("An explicit body reference controls this section. Closing it restores focus to its header.", &"SecondaryLabel"))
	var disclosure = Disclosure.new(); lists.add_child(disclosure); disclosure.configure(&"lab.details", "Selection details", body); specimens.disclosure = disclosure

func _numbers() -> void:
	var grid := page("Numbers")
	var scientific := group(grid, "Scientific values · float64")
	var number = Number.new(); number.set_model(Number.FloatText.parse("1.2345678901234567e-19").value)
	row(scientific, "Threshold", number, "kg/m³", "Enter commits. Escape restores. Focus loss retains the draft; the committed value stays unchanged.")
	specimens.scientific = number
	number.committed.connect(func(value): event_label.text = "Committed float64: " + JSON.stringify(value, "", false, true))
	var invalid = Number.new(); invalid.minimum = 0; invalid.set_model(0.00000000000000012)
	invalid.editor.text = "-3e-9"; invalid.commit()
	row(scientific, "Positive bound", invalid, "s", "Invalid drafts remain editable beside an explicit error. The last valid value is retained.")
	specimens.invalid = invalid
	var readonly = Number.new(); readonly.set_model(Number.FloatText.parse("2.2250738585072014e-308").value); readonly.editor.editable = false
	row(scientific, "Read-only value", readonly, "", "Controlled by the source; the full value remains selectable and copyable.")
	var exact := group(grid, "Exact identifiers · signed int64")
	var identifier = Number.new(); identifier.kind = Number.Kind.EXACT_INTEGER; identifier.set_model(9007199254740993)
	row(exact, "Member ID", identifier, "", "IDs greater than 2^53 never pass through a floating-point control.")
	specimens.integer = identifier
	for entry in [["Minimum", -9223372036854775807 - 1], ["Maximum", 9223372036854775807]]:
		var field = Number.new(); field.kind = Number.Kind.EXACT_INTEGER; field.set_model(entry[1]); row(exact, entry[0], field)
	var values := group(grid, "Numeric typography & density")
	values.add_child(label("DejaVu Sans Mono · 13 px · bundled face", &"SecondaryLabel"))
	for text in ["  0.00000000000000000e+00", "  1.23456789012345670e-19", " -9.87654321098765432e+12", "    9007199254740993", "9223372036854775807"]:
		var value := label(text, &"NumericValue"); value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; values.add_child(value)
	values.add_child(label("0123456789  + − / . :  e E  µ Δ  ×  kg/m³", &"NumericValue"))
	var narrow := group(grid, "Responsive property rows")
	narrow.add_child(label("Rows stack below 320 logical pixels. Resize the window or change interface scale to inspect this boundary.", &"HelpLabel"))
	var edit := LineEdit.new(); edit.text = "synthetic/object/density"; edit.select_all_on_focus = true
	row(narrow, "A long descriptive property label", edit, "m/s", "Paths and exact values remain selectable; text is never reduced to fit.")
	var small := PanelContainer.new(); small.theme_type_variation = &"RaisedPanel"; small.custom_minimum_size.x = 280
	small.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; narrow.add_child(small)
	var field := LineEdit.new(); field.text = "1.25"
	var prop = row(small, "Stacked at 280 px", field, "s"); specimens.narrow_property = prop

func _status() -> void:
	var grid := page("Feedback")
	var statuses := group(grid, "Semantic messages")
	var badges := flow(statuses)
	for pair in [["success", "Ready"], ["info", "Preparing"], ["warning", "Limited"], ["error", "Failed"]]:
		var badge := preload("res://ui/components/status_badge.gd").new(); badge.configure(pair[0], pair[1]); badges.add_child(badge)
	for entry in [["info", "Preparing the next sample", "Showing the last committed state while preparation completes."], ["success", "Export complete", "Example only: no file was written."], ["warning", "Some source support is missing", "The finite subtotal is incomplete; missing values have not been fabricated."], ["error", "Invalid interval", "End time must follow start time. Correct the input and try again."]]:
		var message = Message.new(); statuses.add_child(message); message.configure(entry[0], entry[1], entry[2])
	var jobs := group(grid, "Progress & durable notification")
	var progress = Progress.new(); jobs.add_child(progress); progress.set_progress("Preparing", 0.625); specimens.progress = progress
	var unknown = Progress.new(); jobs.add_child(unknown); unknown.set_progress("Waiting for source")
	jobs.add_child(label("Progress text sits outside the two-tone track so it stays readable at every value.", &"HelpLabel"))
	var notification = Message.new(); jobs.add_child(notification)
	notification.configure("error", "Example operation failed", "A recovery path stays visible until acknowledged. Dismissal does not cancel a job.", true)
	notification.acknowledged.connect(func(): notification.hide(); event_label.text = "Notification acknowledged; no job was cancelled.")
	var open_dialog = action(jobs, "dialog", "Open dialog specimen…")
	open_dialog.invoked.connect(func(_id): show_dialog())
	jobs.add_child(label("Dialog title and actions stay fixed while its body scrolls. Escape closes the specimen and restores focus.", &"HelpLabel"))
	var tip := group(grid, "Tooltip & text hierarchy")
	var tooltip := PanelContainer.new(); tooltip.theme_type_variation = &"PopupSurface"; tip.add_child(tooltip)
	tooltip.add_child(label("Frame scene (F)\nFits the visible geometry. The source coordinates are unchanged.", &"SecondaryLabel"))
	tip.add_child(label("Visible tooltip specimen. Native hover tooltips use the same popup surface.", &"HelpLabel"))

func show_dialog() -> void:
	if dialog == null:
		dialog = Dialog.new(); add_child(dialog)
		for index in range(12):
			var edit := LineEdit.new(); edit.text = "Example value %02d" % (index + 1)
			row(dialog.body, "Property %02d" % (index + 1), edit, "s")
		dialog.add_action(&"close", "Close")
		dialog.add_action(&"apply", "Apply example", &"PrimaryButton")
		dialog.action_requested.connect(func(id: StringName): event_label.text = "Dialog intent: " + id; dialog.dismiss())
	dialog.present("Dialog specimen", get_window())

func _tokens() -> void:
	var grid := page("Tokens")
	var palette := group(grid, "Midnight blue-black surfaces")
	for role in ["surface.0", "surface.1", "surface.2", "surface.3", "surface.hover", "surface.pressed"]:
		var line := HBoxContainer.new(); palette.add_child(line)
		var swatch := ColorRect.new(); swatch.color = T.color(StringName(role)); swatch.custom_minimum_size = Vector2(48, 32); line.add_child(swatch)
		line.add_child(label(role + "  #" + swatch.color.to_html(false).to_upper(), &"NumericValue"))
	palette.add_child(label("Atmospheric background: static diagonal blue-black depth. Controls and diagnostic surfaces stay opaque.", &"HelpLabel"))
	var type := group(grid, "Typography hierarchy")
	for pair in [["ApplicationTitle", "Application title · 18"], ["PanelTitle", "Panel title · 16"], ["SectionTitle", "Section heading · 14"], ["PropertyLabel", "Property label / body · 14"], ["SecondaryLabel", "Secondary text · 14"], ["HelpLabel", "Help and units · 12"], ["NumericValue", "1234567890.01234567 · 13"], ["StatusLabel", "Ready · compact status · 12"]]: type.add_child(label(pair[1], pair[0]))
	var metrics := group(grid, "Logical metrics")
	for text in ["Spacing    4 / 8 / 12 / 16 / 24 / 32", "Controls   32 default / 28 compact", "Corners    4 control / 6 popup", "Borders    1 control / 2 focus + 2 gap", "Icons      16 in 32 hit target", "Scroll     10 visual / 14 lane", "Property   128 label / stack below 320", "Scale      100 / 125 / 150 / 200%"]: metrics.add_child(label(text, &"NumericValue"))
	metrics.add_child(label("Only the presentation window scales. Theme values, scientific palettes and export geometry remain independent.", &"HelpLabel"))
	var semantic := group(grid, "Semantic roles")
	for role in ["accent.primary", "selection.fill", "state.success", "state.warning", "state.error", "state.info", "focus.ring"]:
		var line := HBoxContainer.new(); semantic.add_child(line)
		var swatch := ColorRect.new(); swatch.color = T.color(StringName(role)); swatch.custom_minimum_size = Vector2(32, 24); line.add_child(swatch)
		line.add_child(label(role + "  #" + swatch.color.to_html(false).to_upper(), &"NumericValue"))

	var identity := group(grid, "Identity accents · sparse marks only")
	identity.add_child(label("Blue leads interaction. Purple and teal are small identity details, separate from status, intensity tiers and scientific colormaps.", &"HelpLabel"))
	for role in ["identity.purple", "identity.teal"]:
		var line := HBoxContainer.new(); identity.add_child(line)
		var swatch := ColorRect.new(); swatch.color = T.color(StringName(role)); swatch.custom_minimum_size = Vector2(4, 24); line.add_child(swatch)
		line.add_child(label(role + "  #" + swatch.color.to_html(false).to_upper(), &"NumericValue"))

func _tiers() -> void:
	var grid := page("Tiers")
	var tiers := group(grid, "Categorical intensity · UI only")
	tiers.add_child(label("Tier labels describe a category, not success, danger or a measured scientific value.", &"HelpLabel"))
	for index in 5:
		var tier: String = ["Low", "Medium", "High", "XHigh", "Max"][index]
		var line := HBoxContainer.new(); tiers.add_child(line)
		# A small ordinal cue and explicit text remain useful without color vision.
		var indicator := label("%d / 5 · %s" % [index + 1, tier], StringName("Tier" + tier))
		line.add_child(indicator)
		line.add_child(label("tier." + tier.to_lower() + "  #" + T.color(StringName("tier." + tier.to_lower())).to_html(false).to_upper(), &"NumericValue"))
	var states := group(grid, "Operational status · independent of tier")
	states.add_child(label("A Max tier can succeed; a Low tier can fail. Status always retains its own icon and wording.", &"HelpLabel"))
	for entry in [["Max", "success", "Success"], ["Low", "error", "Error"], ["High", "warning", "Warning"], ["Medium", "info", "Info"]]:
		var line := HBoxContainer.new(); states.add_child(line)
		line.add_child(label("Tier: " + entry[0], StringName("Tier" + entry[0])))
		var badge := preload("res://ui/components/status_badge.gd").new()
		badge.configure(entry[1], entry[2]); line.add_child(badge)
	states.add_child(label("Use small labels only. Never tint a whole panel or use these colors as a scientific colormap.", &"HelpLabel"))

func _layout_grids() -> void:
	for grid in grids: grid.columns = 2 if size.x >= 1040 else 1

extends HSlider
## Physical size multiplier in Range.value; logarithmic travel in Range.ratio.
const MINIMUM := 0.01
const MAXIMUM := 8.0
const FloatText = preload("res://ui/components/float64_text.gd")
const SizePopover = preload("res://ui/components/particle_size_popover.gd")
signal edit_started
var readout := Label.new()
var popover: PopupPanel
var thumb_drag := false
var drag_origin := 0.0
var drag_ratio := 0.0

func _init() -> void:
	min_value = MINIMUM; max_value = MAXIMUM; step = 0.0; exp_edit = true
	value_changed.connect(func(_value): refresh())
	readout.theme_changed.connect(refresh)
	focus_exited.connect(func(): thumb_drag = false)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			thumb_drag = false
			if popover != null: popover.hide())

func install(parent: VBoxContainer, initial: float) -> void:
	var heading := HBoxContainer.new(); parent.add_child(heading)
	var label := Label.new(); label.text = "Particle size"
	label.theme_type_variation = "PropertyLabel"; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	readout.theme_type_variation = "NumericValue"; readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(readout)
	value = initial; parent.add_child(self)
	var bounds := HBoxContainer.new(); parent.add_child(bounds)
	for endpoint in ["0.01", "8"]:
		var caption := Label.new(); caption.text = endpoint; caption.theme_type_variation = "HelpLabel"
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if endpoint == "8": caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bounds.add_child(caption)
	refresh()

func _ready() -> void:
	popover = SizePopover.new(); add_child(popover)
	popover.confirmed.connect(func(candidate: float): value = candidate; popover.hide())

func sync_model(candidate: float) -> void:
	# External state application dismisses a stale draft; silent Range updates do
	# not emit value_changed, so refresh the readout explicitly.
	if value != candidate and popover != null: popover.hide()
	set_value_no_signal(candidate); refresh()

func refresh() -> void:
	readout.text = FloatText.format_value(value)
	# The shell enables wrapping on labels. Reserve the whole numeric string so
	# a precise value cannot collapse into a column of digits beside the title.
	readout.custom_minimum_size.x = ceilf(readout.get_theme_font("font").get_string_size(readout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, readout.get_theme_font_size("font_size")).x)

func thumb_rect() -> Rect2:
	var texture: Texture2D = get_theme_icon("grabber_highlight" if has_focus() else "grabber")
	var dimensions := texture.get_size()
	var centered := get_theme_constant("center_grabber") != 0
	var travel := size.x - (0.0 if centered else dimensions.x)
	var fraction := 1.0 - ratio if is_layout_rtl() else ratio
	var point := Vector2(fraction * travel - (dimensions.x * .5 if centered else 0.0), (size.y - dimensions.y) * .5 + get_theme_constant("grabber_offset"))
	return Rect2(point, dimensions)

func open_editor() -> void:
	if not editable or not is_visible_in_tree(): return
	thumb_drag = false; grab_focus(); edit_started.emit()
	popover.configure(value, self)
	popover.open_at(Rect2(global_position + thumb_rect().position, thumb_rect().size))

func _gui_input(event: InputEvent) -> void:
	if not editable: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and thumb_rect().has_point(event.position):
				grab_focus(); thumb_drag = not event.double_click
				drag_origin = event.position.x; drag_ratio = ratio
				if event.double_click: open_editor.call_deferred()
				# A click on the thumb must preserve an exact manual value. Native
				# track clicks snap to the mouse position even without a drag.
				accept_event()
			elif not event.pressed and thumb_drag:
				thumb_drag = false; accept_event()
		elif event.pressed and scrollable and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			ratio += .01 * (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			accept_event()
	elif event is InputEventMouseMotion and thumb_drag:
		var travel: float = size.x - (0.0 if get_theme_constant("center_grabber") else get_theme_icon("grabber_highlight").get_width())
		if travel > 0:
			ratio = drag_ratio + (event.position.x - drag_origin) / travel * (-1 if is_layout_rtl() else 1)
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not event.echo:
			open_editor.call_deferred(); accept_event()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]:
			if event.keycode == KEY_HOME: value = min_value
			elif event.keycode == KEY_END: value = max_value
			else: ratio += (.001 if event.shift_pressed else .01) * (1 if (event.keycode == KEY_RIGHT) != is_layout_rtl() else -1)
			accept_event()

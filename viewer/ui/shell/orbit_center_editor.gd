extends Control
## Transient editor for the two existing orbit parameters. Never moves the camera until Apply.
var viewer
var center := Vector3.ZERO
var radius := 1.0
var panel: PanelContainer
var details: VBoxContainer
var details_toggle: Button
var coordinates: Array[LineEdit] = []
var radius_input: LineEdit
var notice: Label
var guide: Control
var drag_axis := -1
var drag_origin := Vector3.ZERO
var drag_mouse := Vector2.ZERO
var drag_direction := Vector2.ZERO
var drag_units := 0.0
var last_view: Array = []

func setup(owner_viewer) -> void:
	viewer = owner_viewer
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = viewer.shell.style_slice.theme
	guide = preload("res://ui/shell/orbit_center_guide.gd").new()
	var canvas := CanvasLayer.new(); canvas.layer = 0; add_child(canvas)
	guide.editor = self; canvas.add_child(guide); guide.hide()
	panel = PanelContainer.new(); panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",theme.rounded_tonal_surface(true,true,12,10)); add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",8); panel.add_child(box)
	var header := HBoxContainer.new(); box.add_child(header)
	var title := Label.new(); title.text = "Edit orbit center and radius"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	details_toggle = Button.new(); header.add_child(details_toggle)
	details = VBoxContainer.new(); details.add_theme_constant_override("separation",8); box.add_child(details)
	details_toggle.pressed.connect(func(): show_details(not details.visible))
	var hint := Label.new(); hint.text = "Drag X / Y / Z handles or enter coordinates."; hint.add_theme_font_size_override("font_size",13); details.add_child(hint)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",8); details.add_child(row)
	for axis in 3:
		var label := Label.new(); label.text = ["X","Y","Z"][axis]; label.modulate = guide.COLORS[axis]; row.add_child(label)
		var input := LineEdit.new(); input.custom_minimum_size.x = 90; input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.tooltip_text = "World-space " + label.text + " coordinate"; row.add_child(input); coordinates.append(input)
		input.text_submitted.connect(func(_value): read_fields())
		input.focus_exited.connect(read_fields)
	var radius_row := HBoxContainer.new(); radius_row.add_theme_constant_override("separation",8); details.add_child(radius_row)
	var radius_label := Label.new(); radius_label.text = "Radius"; radius_row.add_child(radius_label)
	radius_input = LineEdit.new(); radius_input.custom_minimum_size.x = 115; radius_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; radius_row.add_child(radius_input)
	radius_input.text_submitted.connect(func(_value): read_fields()); radius_input.focus_exited.connect(read_fields)
	radius_input.gui_input.connect(radius_event)
	radius_input.tooltip_text = "Wheel or −/+ changes the draft radius by 25%; Shift gives 2% steps."
	for direction in [-1,1]:
		var button := Button.new(); button.text = "−" if direction < 0 else "+"; button.custom_minimum_size.x = 32
		button.tooltip_text = radius_input.tooltip_text; radius_row.add_child(button)
		button.pressed.connect(func(): adjust_radius(direction,Input.is_key_pressed(KEY_SHIFT)))
		button.gui_input.connect(radius_event)
	var fine := Label.new(); fine.text = "Wheel here · Shift: fine"; fine.add_theme_font_size_override("font_size",12); radius_row.add_child(fine)
	notice = Label.new(); notice.add_theme_font_size_override("font_size",12); details.add_child(notice)
	var actions := HBoxContainer.new(); box.add_child(actions)
	var place := Button.new(); place.text = "Place ahead"; place.tooltip_text = "Place the draft center one draft radius along the current view direction. The camera stays unchanged."
	place.pressed.connect(place_ahead); actions.add_child(place)
	var space := Control.new(); space.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(space)
	var cancel := Button.new(); cancel.text = "Cancel"; cancel.pressed.connect(dismiss); actions.add_child(cancel)
	var apply := Button.new(); apply.text = "Apply"; apply.theme_type_variation = "PrimaryButton"; apply.pressed.connect(commit); actions.add_child(apply)
	viewer.get_window().focus_exited.connect(func(): drag_axis = -1)
	hide(); set_process(false); set_process_input(false)

func open() -> void:
	if viewer.offline_instance or viewer.inspection_busy: return
	center = viewer.camera_target; radius = viewer.camera_distance; drag_axis = -1
	write_fields(); last_view.clear(); show(); guide.show(); show_details(get_viewport_rect().size.y >= 720)
	set_process(true); set_process_input(true); refresh()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()

func show_details(expanded: bool) -> void:
	details.visible = expanded
	details_toggle.text = "Hide controls" if expanded else "Show controls"
	refresh()

func dismiss() -> void:
	drag_axis = -1; hide(); guide.hide(); set_process(false); set_process_input(false)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()

func read_fields() -> bool:
	if not visible: return false
	var values: Array[float] = []
	for input in coordinates + [radius_input]:
		var text: String = input.text.strip_edges()
		if not text.is_valid_float() or not is_finite(text.to_float()) or absf(text.to_float()) > 1e15:
			notice.text = "Enter finite coordinates and radius (maximum magnitude 1e15)."; return false
		values.append(text.to_float())
	if values[3] < 0.000001:
		notice.text = "Radius must be at least 0.000001."; return false
	center = Vector3(values[0],values[1],values[2]); radius = values[3]
	update_notice(); refresh(); return true

func write_fields() -> void:
	for axis in 3: coordinates[axis].text = str(center[axis])
	radius_input.text = str(radius); update_notice()

func update_notice() -> void:
	notice.text = "Normal wheel zoom retains its existing 8–500 bounds." if radius < 8 or radius > 500 else "Only Apply changes the orbit. Cancel discards this draft."

func adjust_radius(steps: float, fine: bool) -> void:
	if not read_fields(): return
	radius = clampf(radius*pow(1.02 if fine else 1.25,steps),0.000001,1e15)
	write_fields(); refresh()

func radius_event(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		adjust_radius((-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)*(event.factor if event.factor > 0 else 1.0),event.shift_pressed)
		accept_event()

func place_ahead() -> void:
	if not read_fields(): return
	center = viewer.camera.position-viewer.camera.basis.z*radius
	write_fields(); refresh()

func commit() -> void:
	if not read_fields() or viewer.inspection_busy: return
	viewer.camera_target = center
	viewer.camera_distance = radius
	viewer._update_camera()
	dismiss()

func refresh() -> void:
	if not visible: return
	var extent := get_viewport_rect().size
	var right := extent.x; var bottom := extent.y
	if viewer.shell.dock.is_visible_in_tree(): right = minf(right,viewer.shell.dock.get_global_rect().position.x)
	if viewer.shell.transport.is_visible_in_tree(): bottom = minf(bottom,viewer.shell.transport.get_global_rect().position.y)
	panel.size = Vector2(minf(520,right-24),0)
	panel.position = Vector2(maxf(12,(right-panel.size.x)*0.5),maxf(60,bottom-panel.size.y-12))
	guide.queue_redraw()

func _process(_delta: float) -> void:
	# Read-only projection tracking. A stationary draft never queues a redraw.
	var state := [viewer.camera.global_transform,viewer.camera.get_camera_projection(),get_viewport_rect(),viewer.shell.dock.get_global_rect(),viewer.shell.dock.is_visible_in_tree(),viewer.shell.transport.is_visible_in_tree(),panel.size]
	if state != last_view: last_view = state; refresh()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if drag_axis >= 0: drag_axis = -1; get_viewport().set_input_as_handled()
		elif not panel.get_global_rect().has_point(event.position) and viewer.shell.edge_reveal.is_viewport_point(event.position):
			if not read_fields(): return
			for axis in 3:
				var handle: Dictionary = guide.handle(axis)
				if not handle.is_empty() and event.position.distance_to(handle.end) <= 14:
					drag_axis = axis; drag_origin = center; drag_mouse = event.position
					drag_direction = handle.direction; drag_units = handle.units
					var focus := get_viewport().gui_get_focus_owner()
					if focus != null: focus.release_focus()
					get_viewport().set_input_as_handled(); break
	elif event is InputEventMouseMotion and drag_axis >= 0:
		center = drag_origin
		center[drag_axis] += (event.position-drag_mouse).dot(drag_direction)*drag_units
		write_fields(); refresh(); get_viewport().set_input_as_handled()

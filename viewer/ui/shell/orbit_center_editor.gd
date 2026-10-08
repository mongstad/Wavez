extends Control
## Transient editor for the existing orbit parameters. Draft values commit only on Apply.
const APPLY_HINT := "Apply starts Auto Orbit at this center. Cancel restores the previous view."
var viewer
var center := Vector3.ZERO
var radius := 1.0
var panel: PanelContainer
var details: VBoxContainer
var details_toggle: Button
var coordinates: Array[LineEdit] = []
var radius_input: LineEdit
var depth_input: LineEdit
var placement_depth := 1.0
var notice: Label
var guide: Control
var drag_axis := -1
var drag_origin := Vector3.ZERO
var drag_mouse := Vector2.ZERO
var drag_direction := Vector2.ZERO
var drag_units := 0.0
var edit_basis := Basis.IDENTITY
var drag_world_direction := Vector3.ZERO
var written_text: Array[String] = []
var written_values: Array[float] = []
var last_view: Array = []
var pre_edit_camera: Dictionary = {}
var position_readout: Label
var reference_panel: PanelContainer
var navigation_distance := 1.0

func setup(owner_viewer) -> void:
	viewer = owner_viewer
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = viewer.shell.style_slice.theme
	guide = preload("res://ui/shell/orbit_center_guide.gd").new()
	var canvas := CanvasLayer.new(); canvas.layer = 0; add_child(canvas)
	guide.editor = self; canvas.add_child(guide); guide.hide()
	panel = PanelContainer.new(); panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",theme.tonal_surface(12,10)); add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",8); panel.add_child(box)
	var header := HBoxContainer.new(); box.add_child(header)
	var title := Label.new(); title.text = "Edit orbit center and radius"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	details_toggle = Button.new(); header.add_child(details_toggle)
	details = VBoxContainer.new(); details.add_theme_constant_override("separation",8); box.add_child(details)
	details_toggle.pressed.connect(func(): show_details(not details.visible))
	position_readout = Label.new(); position_readout.add_theme_font_size_override("font_size",12); position_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reference_panel = PanelContainer.new(); reference_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference_panel.add_theme_stylebox_override("panel",theme.tonal_surface(10,8)); add_child(reference_panel); reference_panel.add_child(position_readout)
	var hint := Label.new(); hint.text = "Drag view axes. Numeric X / Y / Z are world coordinates."; hint.add_theme_font_size_override("font_size",13); details.add_child(hint)
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
	notice = Label.new(); notice.add_theme_font_size_override("font_size",12); box.add_child(notice)
	var actions := HBoxContainer.new(); box.add_child(actions)
	var place := Button.new(); place.text = "Place ahead"; place.tooltip_text = "Place the draft center straight ahead at Depth in world units. Radius and camera stay unchanged."
	place.pressed.connect(place_ahead); actions.add_child(place)
	# Keep the next placement's distance beside its action, also when collapsed.
	var depth_label := Label.new(); depth_label.text = "Depth"; actions.add_child(depth_label)
	depth_input = LineEdit.new(); depth_input.custom_minimum_size.x = 115; actions.add_child(depth_input)
	depth_input.tooltip_text = "Distance in world units along the current camera's forward direction, used when you click Place ahead. Navigation does not change this value."
	depth_label.tooltip_text = "Placement depth in world units ahead of the camera."
	depth_input.text_submitted.connect(func(_value): read_fields()); depth_input.focus_exited.connect(read_fields)
	var space := Control.new(); space.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(space)
	var cancel := Button.new(); cancel.text = "Cancel"; cancel.pressed.connect(dismiss); actions.add_child(cancel)
	var apply := Button.new(); apply.text = "Apply"; apply.theme_type_variation = "PrimaryButton"; apply.pressed.connect(commit); actions.add_child(apply)
	viewer.get_window().focus_exited.connect(func(): drag_axis = -1)
	hide(); set_process(false); set_process_input(false)

func open() -> void:
	if viewer.offline_instance or viewer.inspection_busy or visible: return
	pre_edit_camera = {
		"transform": viewer.camera.transform,
		"target": viewer.camera_target,
		"distance": viewer.camera_distance,
		"yaw": viewer.yaw,
		"pitch": viewer.pitch,
		"orbit_enabled": viewer.orbit_enabled,
		"free_camera": viewer.free_camera,
		"orbit_basis": viewer.camera_orbit_basis,
		"orbit_basis_active": viewer.camera_orbit_basis_active,
		"orbit_basis_yaw": viewer.camera_orbit_basis_yaw,
		"orbit_basis_pitch": viewer.camera_orbit_basis_pitch,
	}
	center = viewer.camera_target; radius = viewer.camera_distance; drag_axis = -1
	navigation_distance = viewer.camera_distance
	# Seed once from the opening view, then keep this explicit distance independent
	# of camera navigation, draft XYZ and radius until the user edits it.
	placement_depth = -(viewer.camera.global_transform.affine_inverse()*center).z
	if not is_finite(placement_depth) or placement_depth <= viewer.camera.near:
		placement_depth = maxf(navigation_distance,viewer.camera.near*2.0)
	edit_basis = viewer.camera.basis.orthonormalized()
	viewer.orbit_enabled = false
	viewer.free_camera = true
	viewer._sync_control_state()
	write_fields(); last_view.clear(); show(); guide.show(); show_details(get_viewport_rect().size.y >= 720)
	set_process(true); set_process_input(true); refresh()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	record_placement("open",center)

func show_details(expanded: bool) -> void:
	details.visible = expanded
	notice.visible = expanded or notice.text != APPLY_HINT
	details_toggle.text = "Hide controls" if expanded else "Show controls"
	refresh()

func dismiss(restore_camera := true) -> void:
	if not visible: return
	drag_axis = -1; hide(); guide.hide(); set_process(false); set_process_input(false)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	if restore_camera and not pre_edit_camera.is_empty():
		viewer.camera_target = pre_edit_camera.target
		viewer.camera_distance = pre_edit_camera.distance
		viewer.yaw = pre_edit_camera.yaw
		viewer.pitch = pre_edit_camera.pitch
		viewer.camera_orbit_basis = pre_edit_camera.orbit_basis
		viewer.camera_orbit_basis_active = pre_edit_camera.orbit_basis_active
		viewer.camera_orbit_basis_yaw = pre_edit_camera.orbit_basis_yaw
		viewer.camera_orbit_basis_pitch = pre_edit_camera.orbit_basis_pitch
		viewer.camera.transform = pre_edit_camera.transform
		viewer.orbit_enabled = pre_edit_camera.orbit_enabled
		viewer.free_camera = pre_edit_camera.free_camera
	pre_edit_camera.clear()
	viewer._sync_control_state()

func read_fields() -> bool:
	if not visible: return false
	var values: Array[float] = []
	var fields: Array = coordinates + [radius_input,depth_input]
	for index in fields.size():
		var input: LineEdit = fields[index]
		var text: String = input.text.strip_edges()
		if not text.is_valid_float() or not is_finite(text.to_float()) or absf(text.to_float()) > 1e15:
			notice.text = "Enter finite coordinates, radius and depth (maximum magnitude 1e15)."; notice.show(); return false
		# Display strings may be rounded. Untouched fields retain their exact draft
		# values, including when another coordinate/radius was edited.
		values.append(written_values[index] if text == written_text[index] else text.to_float())
	if values[3] < 0.000001:
		notice.text = "Radius must be at least 0.000001."; notice.show(); return false
	if values[4] <= viewer.camera.near:
		notice.text = "Placement depth must be greater than %s world units (near clip)." % str(viewer.camera.near); notice.show(); return false
	center = Vector3(values[0],values[1],values[2]); radius = values[3]; placement_depth = values[4]
	update_notice(); refresh(); return true

func write_fields() -> void:
	written_values.assign([center.x, center.y, center.z, radius, placement_depth])
	written_text.clear()
	for value in written_values: written_text.append(str(value))
	for axis in 3: coordinates[axis].text = str(center[axis])
	radius_input.text = str(radius); depth_input.text = str(placement_depth); update_notice()

func update_notice() -> void:
	notice.text = APPLY_HINT
	notice.visible = details.visible
	update_position_readout()

func update_position_readout() -> void:
	var inside: bool = viewer.camera.position.distance_to(center) < radius
	position_readout.text = "World XYZ:  %s  ·  %s  ·  %s\nRadius: %s%s" % [str(center.x),str(center.y),str(center.z),str(radius),"  ·  Inside radius volume" if inside else ""]

func placement_navigation(orientation: Basis) -> Transform3D:
	# Draft and camera navigation are separate state. RMB updates the ordinary
	# target; Free Camera translates it. Rotate/zoom the actual placement pose
	# about the world-space draft without snapping an off-axis camera onto its z axis.
	var camera: Camera3D = viewer.camera
	var old_target := camera.position-camera.basis.z*navigation_distance
	var translation: Vector3 = viewer.camera_target-old_target
	var rotation := orientation*camera.basis.inverse()
	var zoom: float = viewer.camera_distance/navigation_distance
	var position: Vector3 = center+rotation*(camera.position-center)*zoom+translation
	navigation_distance = viewer.camera_distance
	viewer.camera_target = position-orientation.z*navigation_distance
	return Transform3D(orientation,position)

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
	var previous_center := center
	# The visible distance determines the point on this ray. Reusing the old
	# center's current view depth made repeated clicks depend on navigation history.
	var camera: Camera3D = viewer.camera
	center = camera.global_position-camera.global_basis.z*placement_depth
	write_fields(); refresh()
	# A successful placement returns keyboard navigation to the viewport. Keep
	# ordinary numeric-edit focus protection when the user has not placed yet.
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	record_placement("place_ahead",previous_center)

func record_placement(action: String, previous_center: Vector3) -> void:
	# One bounded event per open/placement, never per navigation frame. Keep enough
	# precision to reconstruct the owner's ray instead of guessing from UI text.
	if viewer.session_log == null: return
	var camera: Camera3D = viewer.camera
	var projection := camera.get_camera_projection()
	var columns: Array = []
	for column in [projection.x,projection.y,projection.z,projection.w]:
		columns.append([column.x,column.y,column.z,column.w])
	var extent := camera.get_viewport().get_visible_rect().size
	var record := {
		"event":action,"schema":1,"capture_path":viewer.capture_path,
		"requested_time":viewer.requested_time,"sample":viewer.current_index+1,"playing":viewer.playing,
		"committed_time":viewer.committed_sample.get("requested_time"),
		"particle_source_indices":viewer.committed_sample.get("source_indices",[]),
		"renderer":RenderingServer.get_current_rendering_method(),"free_camera_speed_scale":viewer.free_camera_speed_scale,
		"camera_position":vector_record(camera.global_position),"camera_basis":basis_record(camera.global_basis),
		"projection_columns":columns,"projection":camera.projection,"fov":camera.fov,"size":camera.size,
		"near":camera.near,"far":camera.far,"keep_aspect":camera.keep_aspect,
		"h_offset":camera.h_offset,"v_offset":camera.v_offset,
		"frustum_offset":[camera.frustum_offset.x,camera.frustum_offset.y],
		"viewport_size":[extent.x,extent.y],"content_scale_factor":get_window().content_scale_factor,
		"window_mode":get_window().mode,"center":vector_record(center),"previous_center":vector_record(previous_center),
		"radius":radius,"placement_depth":placement_depth,"navigation_distance":navigation_distance,
		"camera_target":vector_record(viewer.camera_target),"camera_distance":viewer.camera_distance,
		"yaw":viewer.yaw,"pitch":viewer.pitch,"orbit_basis":basis_record(viewer.camera_orbit_basis),
		"orbit_basis_active":viewer.camera_orbit_basis_active,"orbit_basis_yaw":viewer.camera_orbit_basis_yaw,
		"orbit_basis_pitch":viewer.camera_orbit_basis_pitch,"edit_basis":basis_record(edit_basis),
		"free_camera":viewer.free_camera,"orbit_enabled":viewer.orbit_enabled,
	}
	# The selected field's small presentation dictionary has no scientific arrays.
	# Preserve its channel/clip/slice settings and committed clock as well as the ray.
	var field_id: String = viewer.scene_layers.selected_volume
	if viewer.scene_layers.states.has(field_id):
		record.field = {"id":field_id,"presentation":viewer.scene_layers.states[field_id].duplicate(true)}
		for layer in viewer.committed_sample.get("layers",[]):
			if layer.id == field_id:
				record.field.source_time = layer.source_time
				record.field.source_indices = layer.source_indices
	viewer.session_log.record("ORBIT",JSON.stringify(record,"",true,true))

func vector_record(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func basis_record(value: Basis) -> Array:
	return [vector_record(value.x),vector_record(value.y),vector_record(value.z)]

func commit() -> void:
	if not read_fields() or viewer.inspection_busy: return
	# Commit from the actual placement view, retaining its complete basis. This
	# also covers navigation performed while the editor was open.
	viewer.camera_orbit_basis = viewer.camera.basis
	viewer.camera_orbit_basis_active = true
	viewer.camera_orbit_basis_yaw = viewer.yaw
	viewer.camera_orbit_basis_pitch = viewer.pitch
	viewer.camera_target = center
	viewer.camera_distance = radius
	# End placement before updating the accepted target/radius; Apply uses the
	# ordinary camera path, rather than the temporary draft-navigation pivot.
	dismiss(false)
	viewer._update_camera()
	viewer._capture_auto_orbit_frame()
	viewer.orbit_enabled = true
	viewer._sync_control_state()

func refresh() -> void:
	if not visible: return
	update_position_readout()
	var extent := get_viewport_rect().size
	reference_panel.position = Vector2(12,60)
	reference_panel.size = Vector2(minf(480,extent.x-24),0)
	var right := extent.x; var bottom := extent.y
	if viewer.shell.dock.is_visible_in_tree(): right = minf(right,viewer.shell.dock.get_global_rect().position.x)
	if viewer.shell.transport.is_visible_in_tree(): bottom = minf(bottom,viewer.shell.transport.get_global_rect().position.y)
	panel.size = Vector2(minf(520,right-24),0)
	panel.position = Vector2(maxf(12,(right-panel.size.x)*0.5),maxf(60,bottom-panel.size.y-12))
	guide.update_surface(); guide.queue_redraw()

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
					drag_world_direction = edit_basis[axis]
					var focus := get_viewport().gui_get_focus_owner()
					if focus != null: focus.release_focus()
					get_viewport().set_input_as_handled(); break
	elif event is InputEventMouseMotion and drag_axis >= 0:
		center = drag_origin
		center += drag_world_direction*(event.position-drag_mouse).dot(drag_direction)*drag_units
		write_fields(); refresh(); get_viewport().set_input_as_handled()

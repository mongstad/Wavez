extends Control
const MeshView = preload("res://layers/mesh_view.gd")
const GridView = preload("res://layers/grid_view.gd")
## Transient editor for the existing orbit parameters. Draft values commit only on Apply.
var viewer
var center := Vector3.ZERO
var radius := 1.0
var depth := 1.0
var depth_input: LineEdit
var place_button: Button
var handle_basis := Basis.IDENTITY
var displayed_fields: Array[String] = []
# Only an explicit Apply owns this optional orbit plane. Ordinary navigation
# keeps the accepted main path; a changed pose/target invalidates this orbit.
var applied_orbit: Dictionary = {}
var last_applied: Dictionary = {}
var panel: PanelContainer
var details: VBoxContainer
var details_toggle: Button
var coordinates: Array[LineEdit] = []
var radius_input: LineEdit
var notice: Label
var readout: Label
var guide: Control
var drag_axis := -1
var drag_origin := Vector3.ZERO
var drag_mouse := Vector2.ZERO
var drag_direction := Vector2.ZERO
var drag_units := 0.0
var last_view: Array = []
var pre_edit_camera: Dictionary = {}

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
	var title := Label.new(); title.text = "Edit orbit center"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	details_toggle = Button.new(); header.add_child(details_toggle)
	viewer.shell.close_action(header, dismiss, "Cancel and restore the previous view")
	readout = Label.new(); readout.add_theme_font_size_override("font_size",12)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(readout)
	details = VBoxContainer.new(); details.add_theme_constant_override("separation",8); box.add_child(details)
	details_toggle.pressed.connect(func(): show_details(not details.visible))
	var hint := Label.new(); hint.text = "Drag Right / Up / Toward handles · coordinates are world X / Y / Z."; hint.add_theme_font_size_override("font_size",13); details.add_child(hint)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",8); details.add_child(row)
	for axis in 3:
		var label := Label.new(); label.text = ["X","Y","Z"][axis]; label.modulate = guide.COLORS[axis]; row.add_child(label)
		var input := LineEdit.new(); input.custom_minimum_size.x = 90; input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.tooltip_text = "World-space " + label.text + " coordinate"; row.add_child(input); coordinates.append(input)
		input.text_submitted.connect(func(_value): read_fields())
		input.focus_exited.connect(read_fields)
	var radius_row := HBoxContainer.new(); radius_row.add_theme_constant_override("separation",8); details.add_child(radius_row)
	var radius_label := Label.new(); radius_label.text = "Gizmo radius"; radius_row.add_child(radius_label)
	radius_input = LineEdit.new(); radius_input.custom_minimum_size.x = 115; radius_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; radius_row.add_child(radius_input)
	radius_input.text_submitted.connect(func(_value): read_fields()); radius_input.focus_exited.connect(read_fields)
	radius_input.gui_input.connect(radius_event)
	radius_input.tooltip_text = "Gizmo size only; orbit distance comes from your camera position. Wheel or −/+ gives 25% steps; Shift gives 2%."
	for direction in [-1,1]:
		var button := Button.new(); button.text = "−" if direction < 0 else "+"; button.custom_minimum_size.x = 32
		button.tooltip_text = radius_input.tooltip_text; radius_row.add_child(button)
		button.pressed.connect(func(): adjust_radius(direction,Input.is_key_pressed(KEY_SHIFT)))
		button.gui_input.connect(radius_event)
	var fine := Label.new(); fine.text = "Wheel here · Shift: fine"; fine.add_theme_font_size_override("font_size",12); radius_row.add_child(fine)
	var depth_row := HBoxContainer.new(); details.add_child(depth_row)
	var depth_label := Label.new(); depth_label.text = "Place ahead depth (world units)"; depth_row.add_child(depth_label)
	depth_input = LineEdit.new(); depth_input.custom_minimum_size.x = 120; depth_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; depth_row.add_child(depth_input)
	depth_input.text_submitted.connect(func(_value): read_fields()); depth_input.focus_exited.connect(read_fields)
	notice = Label.new(); notice.add_theme_font_size_override("font_size",12); details.add_child(notice)
	var actions := HBoxContainer.new(); box.add_child(actions)
	place_button = Button.new(); place_button.text = "Place ahead"; place_button.tooltip_text = "Place at the explicit depth along the current view ray. Radius and camera stay unchanged."
	place_button.pressed.connect(place_ahead); actions.add_child(place_button)
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
		"applied_orbit": applied_orbit.duplicate(true),
	}
	handle_basis = viewer.camera.global_basis.orthonormalized()
	initialize_draft()
	drag_axis = -1
	viewer.orbit_enabled = false
	viewer.free_camera = true
	viewer._sync_control_state()
	write_fields(); last_view.clear(); show(); guide.show(); show_details(get_viewport_rect().size.y >= 720)
	set_process(true); set_process_input(true); refresh()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()

func show_details(expanded: bool) -> void:
	details.visible = expanded
	details_toggle.text = "Hide controls" if expanded else "Show controls"
	refresh()

func dismiss(restore_camera := true) -> void:
	if not visible: return
	drag_axis = -1; hide(); guide.hide(); set_process(false); set_process_input(false)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	if restore_camera and not pre_edit_camera.is_empty():
		applied_orbit = pre_edit_camera.applied_orbit
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

func scene_bounds() -> AABB:
	# Read current displayed geometry in viewer-world coordinates. Particles are
	# already viewer_world in WVZ1; mesh/grid transforms are not assumed identity.
	var low := Vector3(INF,INF,INF); var high := Vector3(-INF,-INF,-INF)
	if viewer.frame_a != null:
		for point in viewer.frame_a.positions:
			var p: Vector3 = viewer.current_instance.global_transform * point
			if p.is_finite(): low = low.min(p); high = high.max(p)
	if viewer.scene_layers != null:
		for view in viewer.scene_layers.views.values():
			if not view.visible: continue
			if view is MeshView:
				for point in view.source_positions:
					var p: Vector3 = view.global_transform * point
					if p.is_finite(): low = low.min(p); high = high.max(p)
			elif view is GridView and not view.data.is_empty():
				var tx: Transform3D = view.world_to_grid.affine_inverse()
				for x in [view.bounds_min.x,view.bounds_max.x]:
					for y in [view.bounds_min.y,view.bounds_max.y]:
						for z in [view.bounds_min.z,view.bounds_max.z]:
							var p: Vector3 = tx * Vector3(x,y,z)
							if p.is_finite(): low = low.min(p); high = high.max(p)
	if not low.is_finite() or not high.is_finite(): return AABB()
	return AABB(low,high-low)

func initialize_draft() -> void:
	var camera: Camera3D = viewer.camera
	# Reopening a committed orbit is an exact edit, including after automatic
	# motion. It must not replace the chosen radius with a new default.
	if not last_applied.is_empty() and viewer.camera_target == last_applied.center and viewer.camera_distance == last_applied.orbit_distance:
		center = last_applied.center; radius = last_applied.radius; depth = last_applied.depth
		return
	var bounds := scene_bounds()
	var extent := bounds.size.length()
	var forward := -camera.global_basis.z.normalized()
	var near_depth := maxf(camera.near * 4.0, 0.00001)
	depth = maxf(near_depth, 1.0)
	if extent > 0 and is_finite(extent):
		var projected_depth := (bounds.get_center()-camera.global_position).dot(forward)
		depth = maxf(near_depth, projected_depth if projected_depth > near_depth else extent * 0.5)
		# 4% of world diagonal, further limited by the visible span at depth.
		# This handles a close camera and disconnected/multiple-scale scenes.
		var pixel_center := get_viewport_rect().size * 0.5
		var span := camera.project_position(pixel_center+Vector2(0,get_viewport_rect().size.y*.5),depth).distance_to(camera.project_position(pixel_center,depth))
		radius = maxf(0.000001, minf(extent * 0.04, span * 0.12))
	else:
		radius = maxf(0.000001, depth * 0.04)
	center = camera.global_position + forward * depth

func read_fields() -> bool:
	if not visible: return false
	var inputs: Array = coordinates + [radius_input,depth_input]
	var values: Array = [center.x,center.y,center.z,radius,depth]
	for i in inputs.size():
		# Formatting is presentation only: unchanged Apply never parses it back.
		if inputs[i].text == displayed_fields[i]: continue
		var text: String = inputs[i].text.strip_edges()
		if not text.is_valid_float() or not is_finite(text.to_float()) or absf(text.to_float()) > 1e15:
			notice.text = "Enter finite world values (maximum magnitude 1e15)."; return false
		values[i] = text.to_float()
	if values[3] < 0.000001 or values[4] < 0.000001:
		notice.text = "Radius and placement depth must be at least 0.000001."; return false
	center = Vector3(values[0],values[1],values[2]); radius = values[3]; depth = values[4]
	write_fields(); refresh(); return true

func write_fields() -> void:
	for axis in 3: coordinates[axis].text = str(center[axis])
	radius_input.text = str(radius)
	depth_input.text = str(depth)
	displayed_fields.clear()
	for input in coordinates + [radius_input,depth_input]: displayed_fields.append(input.text)
	update_notice()

func display_number(value: float) -> String:
	return String.num(value,clampi(5-int(floor(log(maxf(absf(value),0.000001))/log(10.0))),0,9))

func update_notice() -> void:
	readout.text = "World (%s, %s, %s) · Gizmo radius %s · Ahead depth %s" % [display_number(center.x),display_number(center.y),display_number(center.z),display_number(radius),display_number(depth)]
	notice.text = "Apply flies around this center from here, always facing it. Cancel restores the view."

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
	center = viewer.camera.global_position-viewer.camera.global_basis.z.normalized()*depth
	write_fields(); refresh()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()

func commit() -> void:
	if not read_fields() or viewer.inspection_busy: return
	var camera: Camera3D = viewer.camera
	var radial: Vector3 = camera.global_position - center
	var orbit_distance := radial.length()
	if not is_finite(orbit_distance) or orbit_distance <= 0.0:
		notice.text = "Move away from the center before applying an orbit."
		return
	# An unchanged re-Apply keeps the already coherent pose/distance exactly,
	# rather than re-normalizing float32 vectors and accumulating drift.
	var unchanged: bool = not applied_orbit.is_empty() and camera.transform == applied_orbit.pose and viewer.camera_target == center and viewer.camera_distance == applied_orbit.radius
	if not unchanged:
		var back := radial / orbit_distance
		# Look at the target from HERE. Project the existing up axis onto the
		# view plane; when looking along that axis, retain the old right axis.
		var right := camera.global_basis.y.cross(back)
		if right.length_squared() < 0.000001:
			right = camera.global_basis.x - back * camera.global_basis.x.dot(back)
		right = right.normalized()
		camera.global_basis = Basis(right,back.cross(right).normalized(),back)
		viewer.camera_target = center
		viewer.camera_distance = orbit_distance
		viewer._adopt_camera_basis()
	applied_orbit = {"axis":camera.basis.y.normalized(),"basis":camera.basis,"angle":0.0,"pose":camera.transform,"center":center,"radius":viewer.camera_distance}
	last_applied = {"center":center,"radius":radius,"depth":depth,"orbit_distance":viewer.camera_distance}
	dismiss(false)
	viewer.orbit_enabled = true
	viewer._sync_control_state()

func matches_applied_orbit() -> bool:
	return not applied_orbit.is_empty() and viewer.camera.transform == applied_orbit.pose and viewer.camera_target == applied_orbit.center and viewer.camera_distance == applied_orbit.radius

func carry_camera_roll(previous_pose: Transform3D) -> void:
	if applied_orbit.is_empty() or previous_pose != applied_orbit.pose or viewer.camera_target != applied_orbit.center or viewer.camera_distance != applied_orbit.radius: return
	# Banking changes screen-up, not the Apply-time observer plane or orbit
	# distance. Resume that plane from the banked basis without a horizon snap.
	applied_orbit.basis = viewer.camera.basis
	applied_orbit.angle = 0.0
	applied_orbit.pose = viewer.camera.transform

func zoom_orbit(step: float, inward: bool) -> bool:
	if not viewer.orbit_enabled or not matches_applied_orbit(): return false
	# A chosen point can be inside the scene's framing sphere. Its orbit only
	# needs camera clipping clearance, not clearance around the entire scene.
	var minimum: float = viewer.camera.near * 2.0
	var maximum: float = maxf(minimum, viewer.camera.far)
	var distance: float = viewer.camera_distance
	viewer.camera_distance = minf(distance, maxf(minimum, distance * step)) if inward else maxf(distance, minf(maximum, distance / step))
	viewer._update_camera()
	applied_orbit.radius = viewer.camera_distance
	applied_orbit.pose = viewer.camera.transform
	if not last_applied.is_empty() and last_applied.center == viewer.camera_target:
		last_applied.orbit_distance = viewer.camera_distance
	return true

func advance_orbit(delta: float) -> bool:
	if applied_orbit.is_empty(): return false
	if not matches_applied_orbit():
		applied_orbit.clear(); return false
	applied_orbit.angle = fmod(applied_orbit.angle + delta*viewer.orbit_speed, TAU)
	var orientation: Basis = (Basis(applied_orbit.axis,applied_orbit.angle)*applied_orbit.basis).orthonormalized()
	viewer.yaw += delta*viewer.orbit_speed
	viewer.camera.transform = Transform3D(orientation,viewer.camera_target+orientation.z*viewer.camera_distance)
	viewer._adopt_camera_basis()
	applied_orbit.pose = viewer.camera.transform
	return true

func refresh() -> void:
	if not visible: return
	var extent := get_viewport_rect().size
	var right := extent.x; var bottom := extent.y
	if viewer.shell.dock.is_visible_in_tree(): right = minf(right,viewer.shell.dock.get_global_rect().position.x)
	if viewer.shell.transport.is_visible_in_tree(): bottom = minf(bottom,viewer.shell.transport.get_global_rect().position.y)
	panel.size = Vector2(minf(600,right-24),0)
	panel.position = Vector2(maxf(12,(right-panel.size.x)*0.5),maxf(60,bottom-panel.size.y-12))
	if viewer.camera.global_position.distance_to(center) <= radius:
		notice.text = "Camera inside sphere · surface hidden; world guides and values remain."
	else: update_notice()
	guide.sync_geometry()
	guide.queue_redraw()

func _process(_delta: float) -> void:
	# Read-only projection tracking. A stationary draft never queues a redraw.
	var state := [viewer.camera.global_transform,viewer.camera.get_camera_projection(),get_viewport_rect(),viewer.shell.dock.get_global_rect(),viewer.shell.dock.is_visible_in_tree(),viewer.shell.transport.is_visible_in_tree(),panel.size]
	if state != last_view: last_view = state; refresh()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		dismiss(); get_viewport().set_input_as_handled(); return
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
		center += handle_basis[drag_axis]*(event.position-drag_mouse).dot(drag_direction)*drag_units
		write_fields(); refresh(); get_viewport().set_input_as_handled()

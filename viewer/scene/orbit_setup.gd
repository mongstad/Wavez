extends Node
## A temporary camera proposal. Only release publishes its pivot and radius.
const MIN_RADIUS := 0.000001
const MAX_RADIUS := 1.0e12
var viewer
var active := false
var radius := 1.0
var pivot := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var saved := {}
var mouse_mode := Input.MOUSE_MODE_VISIBLE
var mouse_position := Vector2.ZERO
var guide: Control

func setup(owner_viewer) -> void:
	viewer = owner_viewer
	# Draw above the world but below the existing application chrome (layer 1).
	var canvas := CanvasLayer.new(); canvas.layer = 0; add_child(canvas)
	guide = preload("res://scene/orbit_setup_guide.gd").new()
	guide.setup = self; canvas.add_child(guide); guide.hide()
	viewer.get_window().focus_exited.connect(cancel)
	viewer.get_viewport().size_changed.connect(refresh)

func begin(point: Vector2) -> bool:
	if active or not viewer.free_camera or viewer.inspection_busy or viewer.screenshot_saving: return false
	if viewer.selection_controller != null and viewer.selection_controller.selecting: return false
	if not viewer.shell.edge_reveal.is_viewport_point(point): return false
	saved = {"transform":viewer.camera.transform}
	yaw = viewer.yaw; pitch = viewer.pitch
	radius = clampf(viewer.camera_distance, minimum_radius(), MAX_RADIUS)
	mouse_mode = Input.mouse_mode; mouse_position = point
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	viewer.dragging = false
	active = true; guide.show(); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	refresh()
	return true

func minimum_radius() -> float:
	# Keep a representable displacement at remote float32 world coordinates.
	var p: Vector3 = viewer.camera.position.abs()
	return maxf(MIN_RADIUS, maxf(p.x,maxf(p.y,p.z)) * 0.000001)

func refresh() -> void:
	if not active: return
	radius = clampf(radius, minimum_radius(), MAX_RADIUS)
	pivot = viewer.camera.position - viewer.camera.basis.z * radius
	guide.queue_redraw()

func adjust(steps: float, fine: bool) -> void:
	if not active: return
	radius = clampf(radius * pow(1.02 if fine else 1.2, steps), minimum_radius(), MAX_RADIUS)
	refresh()

func look(relative: Vector2) -> void:
	if not active: return
	yaw -= relative.x * 0.006; pitch -= relative.y * 0.006
	viewer.camera.basis = Basis(Vector3.UP,yaw) * Basis(Vector3.RIGHT,-pitch)
	refresh()

func translate(move: Vector3, delta: float) -> void:
	viewer.camera.position += viewer.camera.basis * move * delta * radius * 0.5
	refresh()

func finish(commit: bool) -> void:
	if not active: return
	if commit:
		refresh()
		viewer.camera_target = pivot; viewer.camera_distance = radius
		viewer.yaw = yaw; viewer.pitch = pitch; viewer.custom_orbit = true
	else:
		viewer.camera.transform = saved.transform
	active = false; guide.hide(); saved.clear()
	Input.mouse_mode = mouse_mode
	if mouse_mode == Input.MOUSE_MODE_VISIBLE: Input.warp_mouse(mouse_position)

func cancel() -> void: finish(false)

func handle(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed: finish(true)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			adjust((-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0) * (event.factor if event.factor > 0 else 1.0), event.shift_pressed)
		return true
	if event is InputEventMouseMotion:
		look(event.relative); return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R: viewer._reset_camera(); return true
		if event.keycode == KEY_F: viewer._focus_activity(); return true
		# Window recovery keeps ownership of Escape. Do not turn it into a reset.
		if event.keycode == KEY_O: return true
	return false

func _exit_tree() -> void:
	if active: Input.mouse_mode = mouse_mode

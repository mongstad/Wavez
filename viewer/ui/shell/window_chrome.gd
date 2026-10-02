extends Node
## Compositor-owned movement/resizing: never synthesize native window coordinates.
const GRIP := 6.0
var shell
var start_drag: Callable = DisplayServer.window_start_drag
var start_resize: Callable = DisplayServer.window_start_resize
var actions := HBoxContainer.new()
var maximize_button: Button
var grips: Array[Control] = []
var minimized_from := -1
var minimized_immersive := false
var minimize_lost_focus := false

func setup(owner_shell, row: HBoxContainer) -> void:
	shell = owner_shell
	actions.name = "WindowActions"; actions.add_theme_constant_override("separation", 0); row.add_child(actions)
	var minimize_action: Button = shell.button(actions, "", minimize)
	minimize_action.tooltip_text = "Minimize"; minimize_action.set_meta("chrome_icon", "minimize")
	maximize_button = shell.button(actions, "", toggle_maximize); maximize_button.set_meta("chrome_icon", "maximize")
	var close: Button = shell.close_action(actions, request_close, "Close WAVEZ")
	close.set_meta("chrome_icon", "close")
	for action in actions.get_children():
		action.custom_minimum_size = Vector2(32, 32); action.theme_type_variation = "IconAction"
	if shell.viewer.offline_instance:
		set_process_input(false); return
	get_window().borderless = true
	get_window().min_size = Vector2i(970, 600)
	get_window().size_changed.connect(refresh)
	get_window().focus_entered.connect(restore_minimized)
	get_window().focus_exited.connect(func():
		if minimized_from >= 0: minimize_lost_focus = true)
	for cursor in [Control.CURSOR_FDIAGSIZE, Control.CURSOR_VSIZE, Control.CURSOR_BDIAGSIZE, Control.CURSOR_HSIZE, Control.CURSOR_HSIZE, Control.CURSOR_BDIAGSIZE, Control.CURSOR_VSIZE, Control.CURSOR_FDIAGSIZE]:
		var grip := Control.new(); grip.mouse_default_cursor_shape = cursor
		grip.z_index = 10; shell.add_child(grip); grips.append(grip)
	# Blank bar areas remain the custom title/drag surface.
	shell.bar.gui_input.connect(title_input)
	shell.title_drag.gui_input.connect(title_input)
	refresh()

func refresh() -> void:
	if shell.style_slice == null: return
	var extent: Vector2 = shell.get_viewport().get_visible_rect().size
	var rectangles := [Rect2(0,0,GRIP,GRIP), Rect2(GRIP,0,extent.x-GRIP*2,GRIP), Rect2(extent.x-GRIP,0,GRIP,GRIP), Rect2(0,GRIP,GRIP,extent.y-GRIP*2), Rect2(extent.x-GRIP,GRIP,GRIP,extent.y-GRIP*2), Rect2(0,extent.y-GRIP,GRIP,GRIP), Rect2(GRIP,extent.y-GRIP,extent.x-GRIP*2,GRIP), Rect2(extent.x-GRIP,extent.y-GRIP,GRIP,GRIP)]
	for i in grips.size():
		grips[i].position = rectangles[i].position; grips[i].size = rectangles[i].size
		grips[i].visible = not shell.immersive and get_window().mode == Window.MODE_WINDOWED
	var maximized := get_window().mode == Window.MODE_MAXIMIZED
	maximize_button.tooltip_text = "Restore window" if maximized else "Maximize"
	for action in actions.get_children():
		var id: String = action.get_meta("chrome_icon")
		if action == maximize_button: id = "restore" if maximized else "maximize"
		action.icon = shell.style_slice.theme.chrome_icon(id)

func toggle_maximize() -> void:
	if shell.immersive: shell.exit_immersive()
	get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_MAXIMIZED else Window.MODE_MAXIMIZED
	refresh.call_deferred()

func minimize() -> void:
	# Wayland has no minimized-state acknowledgement. Godot's request also
	# unsets maximization; restore the preceding mode on the actual focus event.
	minimized_immersive = shell.immersive
	minimized_from = get_window().mode
	minimize_lost_focus = false
	get_window().mode = Window.MODE_MINIMIZED

func restore_minimized() -> void:
	if minimized_from < 0 or not minimize_lost_focus: return
	var mode := minimized_from; minimized_from = -1
	minimize_lost_focus = false
	if minimized_immersive:
		# Allow the native configure event to arrive before #117's external-exit
		# recovery checks the restored fullscreen mode.
		shell.immersive_started = Time.get_ticks_msec(); shell.immersive_native_seen = false
	if get_window().mode != mode: get_window().mode = mode
	minimized_immersive = false
	refresh.call_deferred()

func title_input(event: InputEvent) -> void:
	if shell.immersive or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	if event.double_click: toggle_maximize()
	elif DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG): start_drag.call(get_window().get_window_id())
	shell.bar.accept_event()

static func resize_edge(point: Vector2, extent: Vector2) -> int:
	var left := point.x < GRIP; var right := point.x >= extent.x - GRIP
	var top := point.y < GRIP; var bottom := point.y >= extent.y - GRIP
	if top and left: return DisplayServer.WINDOW_EDGE_TOP_LEFT
	if top and right: return DisplayServer.WINDOW_EDGE_TOP_RIGHT
	if bottom and left: return DisplayServer.WINDOW_EDGE_BOTTOM_LEFT
	if bottom and right: return DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT
	if left: return DisplayServer.WINDOW_EDGE_LEFT
	if right: return DisplayServer.WINDOW_EDGE_RIGHT
	if top: return DisplayServer.WINDOW_EDGE_TOP
	if bottom: return DisplayServer.WINDOW_EDGE_BOTTOM
	return -1

func _input(event: InputEvent) -> void:
	if shell.immersive or get_window().mode != Window.MODE_WINDOWED or shell.edge_reveal.popup_active(shell.viewer): return
	if not event is InputEventMouseButton: return
	var edge := resize_edge(event.position, shell.get_viewport().get_visible_rect().size)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and edge >= 0:
		if DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG):
			start_resize.call(edge, get_window().get_window_id())
			get_viewport().set_input_as_handled()

func request_close() -> void:
	# File → Exit and the window close button share normal SceneTree teardown.
	get_tree().quit()

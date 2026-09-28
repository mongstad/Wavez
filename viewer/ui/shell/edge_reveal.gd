extends Node
## Session-only chrome persistence. Never serialized into scientific/view state.
const DWELL := 0.5
const GRACE := 0.35
const VERTICAL_EDGE := 10.0
const RIGHT_EDGE := 10.0
var shell
var states := {
	"top": {"pinned":true, "visible":true, "dwell":0.0, "leave":0.0},
	"right": {"pinned":true, "visible":true, "dwell":0.0, "leave":0.0},
	"bottom": {"pinned":true, "visible":true, "dwell":0.0, "leave":0.0},
}
var pins := {}
var pointer_inside := true
var keyboard_navigation := false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: keyboard_navigation = true
	elif event is InputEventMouseButton and event.pressed: keyboard_navigation = false

func _ready() -> void:
	get_window().mouse_entered.connect(func(): pointer_inside = true)
	get_window().mouse_exited.connect(func(): pointer_inside = false)

func add_pin(parent: Node, side: String) -> void:
	var pin := Button.new()
	pin.toggle_mode = true; pin.button_pressed = true
	pin.custom_minimum_size = Vector2(32,32)
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(pin); pins[side] = pin
	pin.toggled.connect(func(value): set_pinned(side,value))
	update_pin(side)

func update_pin(side: String) -> void:
	var pin: Button = pins[side]
	pin.set_pressed_no_signal(states[side].pinned)
	pin.icon = preload("res://ui/shell/icons/pin.svg") if states[side].pinned else preload("res://ui/shell/icons/unpin.svg")
	pin.tooltip_text = ("Unpin " if states[side].pinned else "Pin ") + {"top":"top bar","right":"simulation panel","bottom":"playback and status"}[side]

func set_pinned(side: String, value: bool) -> void:
	states[side].pinned = value
	states[side].visible = true
	states[side].dwell = 0.0; states[side].leave = 0.0
	update_pin(side)
	if shell.bottom_strip != null: shell.layout()

func controls(side: String) -> Array:
	match side:
		"top": return [shell.bar]
		"right": return [shell.dock, shell.viewer.resize_handle]
	return [shell.transport, shell.status_ui]

func contains(side: String, point: Vector2) -> bool:
	for control in controls(side):
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false

func editing(side: String) -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if keyboard_navigation and focus != null:
		for control in controls(side):
			if control == focus or control.is_ancestor_of(focus): return true
	if focus is Slider and not (Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN)): return false
	if not (focus is LineEdit or focus is TextEdit or focus is Slider or focus is SpinBox): return false
	for control in controls(side):
		if control == focus or control.is_ancestor_of(focus): return true
	return false

func popup_active(node: Node) -> bool:
	for child in node.get_children(true):
		if child is Window and child.visible: return true
		if popup_active(child): return true
	return false

func _process(delta: float) -> void:
	if shell == null or shell.bottom_strip == null or shell.immersive or shell.viewer.offline_instance: return
	if states.top.pinned and states.right.pinned and states.bottom.pinned: return
	var point := get_viewport().get_mouse_position()
	var inside := pointer_inside and get_window().has_focus() and get_viewport().get_visible_rect().has_point(point)
	var busy: bool = popup_active(shell.viewer) or Input.get_mouse_button_mask() != 0 or shell.viewer.resizing_panel
	tick(delta, point, inside, busy)

func tick(delta: float, point: Vector2, inside: bool, busy: bool) -> void:
	if shell.immersive: return
	var extent := get_viewport().get_visible_rect().size
	var edges := {"top": point.y <= VERTICAL_EDGE, "right": point.x >= extent.x-RIGHT_EDGE, "bottom": point.y >= extent.y-VERTICAL_EDGE}
	var changed := false
	for side in states:
		var state: Dictionary = states[side]
		var was: bool = state.visible
		if state.pinned:
			state.visible = true; state.leave = 0.0; state.dwell = 0.0
		elif state.visible:
			if busy or editing(side) or (inside and contains(side,point)):
				state.leave = 0.0
			else:
				state.leave += delta
				if state.leave >= GRACE: state.visible = false; state.dwell = 0.0
		else:
			if inside and edges[side] and not busy:
				state.dwell += delta
				if state.dwell >= DWELL: state.visible = true; state.leave = 0.0
			else: state.dwell = 0.0
		changed = changed or was != state.visible
	if changed: shell.layout()

func is_viewport_point(point: Vector2) -> bool:
	if popup_active(shell.viewer): return false
	for side in states:
		if contains(side,point): return false
	# Scientific legends pass camera input through, but must not toggle fullscreen.
	for control in [shell.navigation, shell.empty, shell.open_error, shell.particle_legend_panel, shell.layer_legends]:
		if control != null and control.is_visible_in_tree():
			if control is Control and control.get_global_rect().has_point(point): return false
			for child in control.get_children():
				if child is Control and child.is_visible_in_tree() and child.get_global_rect().has_point(point): return false
	return true

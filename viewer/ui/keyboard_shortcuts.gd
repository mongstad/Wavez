extends RefCounted
## Application preferences only. No InputMap, scientific state or export serialization.
const PATH := "user://keyboard_shortcuts.cfg"
const MODIFIERS := KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_MASK_ALT | KEY_MASK_META
const ACTIONS := [
	["reset_camera", "Reset Camera", "Navigation", KEY_R],
	["auto_orbit", "Auto Orbit", "Navigation", KEY_O],
	["free_camera", "Free Camera", "Navigation", 0],
	["increase_camera_speed", "Increase Camera Movement Speed", "Navigation", KEY_PLUS],
	["decrease_camera_speed", "Decrease Camera Movement Speed", "Navigation", KEY_MINUS],
	["orbit_camera_left", "Orbit Camera Left", "Navigation", 0],
	["orbit_camera_right", "Orbit Camera Right", "Navigation", 0],
	["frame_scene", "Frame Scene", "Navigation", KEY_F],
	["navigate", "Navigate", "Navigation", KEY_N | KEY_MASK_ALT],
	["play_pause", "Play Pause", "Playback", KEY_SPACE],
	["previous_sample", "Previous Sample", "Playback", KEY_LEFT],
	["next_sample", "Next Sample", "Playback", KEY_RIGHT],
	["loop_playback", "Loop Playback", "Playback", 0],
	["open_capture", "Open File", "File", 0],
	["export_video", "Export Video", "File", 0],
	["save_image", "Save Image", "File", KEY_P],
	["derive_range", "Derive Range", "Tools", 0],
	["mapping", "Mapping", "Tools", 0],
	["recorded_history", "Recorded History", "Tools", KEY_T],
	["point_rendering", "Point Rendering", "Tools", KEY_V],
	["fullscreen", "Fullscreen", "Interface", KEY_F11],
	["fullscreen_alternate", "Fullscreen Alternate", "Interface", KEY_F11 | KEY_MASK_SHIFT],
	["pin_top", "Pin Top Bar", "Interface", 0],
	["pin_right", "Pin Right Panel", "Interface", 0],
	["pin_bottom", "Pin Bottom Bar", "Interface", 0],
	["next_category", "Next Simulation Category", "Interface", 0],
	["previous_category", "Previous Simulation Category", "Interface", 0],
]
var storage_path := PATH
var active := defaults()

static func defaults() -> Dictionary:
	var result := {}
	for action in ACTIONS: result[action[0]] = action[3]
	return result

static func valid_binding(value: Variant) -> bool:
	if not value is int or value < 0: return false
	if value == 0: return true
	var code: int = value & KEY_CODE_MASK
	if value & ~(KEY_CODE_MASK | MODIFIERS): return false
	# Escape is recovery. Tab remains focus traversal; modifiers alone are not keys.
	return code not in [0, KEY_ESCAPE, KEY_TAB, KEY_BACKTAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] and not OS.get_keycode_string(code).is_empty()

static func binding(event: InputEventKey) -> int:
	# Bind the produced +/- character, not a US physical key position. On a US
	# layout '+' is Shift+=; on Nordic layouts it may have its own key. Normalize
	# unmodified printable +/- so capture, conflict handling and runtime agree.
	if event.keycode != 0 and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
		if event.unicode == KEY_PLUS or (event.unicode == 0 and event.keycode == KEY_EQUAL and event.shift_pressed): return KEY_PLUS
		if event.unicode == KEY_MINUS: return KEY_MINUS
	var value := int(event.get_keycode_with_modifiers())
	return value if valid_binding(value) and event.keycode != 0 else 0

static func text(value: int) -> String:
	return "Unbound" if value == 0 else OS.get_keycode_string(value)

static func assign(map: Dictionary, action: String, value: int) -> void:
	if not map.has(action) or not valid_binding(value): return
	if value != 0:
		for other in map:
			if map[other] == value: map[other] = 0
	map[action] = value

static func normalized(map: Dictionary) -> Dictionary:
	var result := defaults()
	for action in ACTIONS:
		var value: Variant = map.get(action[0], action[3])
		if valid_binding(value): result[action[0]] = value
	# Deterministic last catalog entry wins for a manually edited duplicate profile.
	var seen := {}
	for action in ACTIONS:
		var value: int = result[action[0]]
		if value == 0: continue
		if seen.has(value): result[seen[value]] = 0
		seen[value] = action[0]
	return result

func load_preferences() -> Error:
	var config := ConfigFile.new()
	var error := config.load(storage_path)
	if error == ERR_FILE_NOT_FOUND: return OK
	if error != OK: return error
	var saved := {}
	for action in ACTIONS:
		saved[action[0]] = config.get_value("shortcuts", action[0], action[3])
	active = normalized(saved)
	return OK

func apply(map: Dictionary) -> Error:
	for action in ACTIONS:
		if not map.has(action[0]) or not valid_binding(map[action[0]]): return ERR_INVALID_DATA
	var candidate := normalized(map)
	var config := ConfigFile.new()
	for action in ACTIONS: config.set_value("shortcuts", action[0], candidate[action[0]])
	# Do not activate a map that could not be persisted; keep the prior file intact.
	var temporary := storage_path + ".tmp"
	var error := config.save(temporary)
	if error != OK: return error
	error = DirAccess.rename_absolute(temporary, storage_path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return error
	active = candidate
	return OK

func match_action(event: InputEventKey) -> String:
	if not event.pressed or event.echo: return ""
	var value := binding(event)
	if value == 0: return ""
	for action in ACTIONS:
		if active[action[0]] == value: return action[0]
	return ""

func hint(action: String) -> String:
	var value: int = active[action]
	return "" if value == 0 else " [" + text(value) + "]"

func event_for(action: String) -> InputEventKey:
	var value: int = active[action]
	var event := InputEventKey.new()
	event.keycode = value & KEY_CODE_MASK
	event.ctrl_pressed = bool(value & KEY_MASK_CTRL)
	event.shift_pressed = bool(value & KEY_MASK_SHIFT)
	event.alt_pressed = bool(value & KEY_MASK_ALT)
	event.meta_pressed = bool(value & KEY_MASK_META)
	return event

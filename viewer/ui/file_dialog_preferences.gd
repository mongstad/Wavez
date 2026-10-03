extends Node
## Persist Godot's shared navigation lists, never scientific/view-preset state.
const PATH := "user://file_dialog_preferences.cfg"
const MAX_RECENTS := 20
var storage_path := PATH
var _capture_recent_before := PackedStringArray()
var _capture_pending := false

func _ready() -> void:
	var config := ConfigFile.new()
	var error := config.load(storage_path)
	if error == ERR_FILE_NOT_FOUND: return
	if error != OK:
		push_warning("Could not load file dialog preferences: " + error_string(error))
		return
	FileDialog.set_favorite_list(_directories(config.get_value("navigation", "favorites", [])))
	FileDialog.set_recent_list(_directories(config.get_value("navigation", "recent", [])).slice(0, MAX_RECENTS))

func attach(dialog: FileDialog, capture_open := false) -> void:
	if capture_open:
		dialog.about_to_popup.connect(func():
			_capture_recent_before = FileDialog.get_recent_list()
			_capture_pending = true)
		# Godot records the directory before file_selected, before WVZ1 validation.
		# Connect before the loader so even its asynchronous busy display sees only
		# approved history. Successful loading commits the actual selected directory.
		dialog.file_selected.connect(func(_path: String):
			if _capture_pending: FileDialog.set_recent_list(_capture_recent_before)
			_capture_pending = false)
	# Deferred: built-in hide precedes file_selected. Save after the rollback.
	dialog.visibility_changed.connect(func():
		if not dialog.visible: save_preferences(), CONNECT_DEFERRED)

func capture_opened(path: String) -> void:
	var directory := ProjectSettings.globalize_path(path).get_base_dir().simplify_path()
	if not DirAccess.dir_exists_absolute(directory): return
	if not directory.ends_with("/"): directory += "/"
	var recent := FileDialog.get_recent_list()
	var index := recent.find(directory)
	if index >= 0: recent.remove_at(index)
	recent.insert(0, directory)
	FileDialog.set_recent_list(recent.slice(0, MAX_RECENTS))
	save_preferences()

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("navigation", "favorites", FileDialog.get_favorite_list())
	config.set_value("navigation", "recent", FileDialog.get_recent_list())
	var error := config.save(storage_path)
	if error != OK:
		push_warning("Could not save file dialog preferences: " + error_string(error))

func _exit_tree() -> void:
	save_preferences()

func _directories(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if not (value is Array or value is PackedStringArray): return result
	for path in value:
		if not path is String or not path.is_absolute_path(): continue
		var directory: String = path.simplify_path()
		if not directory.ends_with("/"): directory += "/"
		if not result.has(directory): result.append(directory)
	return result

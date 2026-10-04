extends Node
## One persistent home for application file-location choices. Empty directories
## retain the existing per-export picker and Godot user://logs defaults.
signal changed
const STORAGE_PATH := "user://preferences.cfg"
const Job = preload("res://video/render_job.gd")
const DIRECTORY_KEYS := ["video_dir", "image_dir", "log_dir"]
var storage_path := STORAGE_PATH
var settings: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"ffmpeg_mode":"auto", "ffmpeg_path":"", "video_dir":"", "image_dir":"", "log_dir":""}

func _ready() -> void:
	reload()

func reload() -> void:
	settings = defaults()
	var config := ConfigFile.new()
	var error := config.load(storage_path)
	if error == ERR_FILE_NOT_FOUND: return
	if error != OK:
		push_warning("Could not load File Locations preferences: " + error_string(error))
		return
	var mode = config.get_value("file_locations", "ffmpeg_mode", "auto")
	if mode is String and mode in ["auto", "custom"]: settings.ffmpeg_mode = mode
	for key in ["ffmpeg_path"] + DIRECTORY_KEYS:
		var value = config.get_value("file_locations", key, "")
		if value is String and (value.is_empty() or value.is_absolute_path()): settings[key] = value

func snapshot() -> Dictionary:
	return settings.duplicate()

func save(next: Dictionary) -> String:
	if next.get("ffmpeg_mode") not in ["auto", "custom"]: return "Choose Auto-detect or a custom FFmpeg executable."
	if next.get("ffmpeg_mode") == "custom":
		var ffmpeg_error := Job.ffmpeg_problem(str(next.get("ffmpeg_path", "")))
		if not ffmpeg_error.is_empty(): return ffmpeg_error
	for key in DIRECTORY_KEYS:
		if not next.get(key, "") is String: return "Choose an absolute directory."
		var error := directory_problem(next[key], true)
		if not error.is_empty(): return error
	var config := ConfigFile.new()
	config.set_value("file_locations", "ffmpeg_mode", next.ffmpeg_mode)
	config.set_value("file_locations", "ffmpeg_path", next.ffmpeg_path if next.ffmpeg_mode == "custom" else "")
	for key in DIRECTORY_KEYS: config.set_value("file_locations", key, next[key])
	var saved := config.save(storage_path)
	if saved != OK: return "Could not save File Locations preferences: " + error_string(saved)
	settings = next.duplicate()
	if settings.ffmpeg_mode == "auto": settings.ffmpeg_path = ""
	changed.emit()
	return ""

func ffmpeg_status() -> Dictionary:
	var custom: bool = settings.ffmpeg_mode == "custom"
	var path: String = settings.ffmpeg_path if custom else Job.find_ffmpeg()
	if path.is_empty():
		return {"path":"", "error":"Custom FFmpeg path is empty." if custom else "Not found on PATH."}
	var problem := Job.ffmpeg_problem(path)
	return {"path":path if problem.is_empty() else "", "error":problem}

func log_directory() -> String:
	return settings.log_dir if not settings.log_dir.is_empty() else ProjectSettings.globalize_path("user://logs")

static func directory_problem(path: String, create := false) -> String:
	if path.is_empty(): return ""
	if not path.is_absolute_path(): return "Choose an absolute directory: " + path
	if create:
		var created := DirAccess.make_dir_recursive_absolute(path)
		if created != OK: return "Cannot create directory: " + path + " (" + error_string(created) + ")"
	if not DirAccess.dir_exists_absolute(path): return "Directory is unavailable: " + path
	var probe := path.path_join(".wavez-write-check-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null: return "Directory is not writable: " + path
	file.close()
	DirAccess.remove_absolute(probe)
	return ""

extends SceneTree
## Offline PCK resource check only: no Main scene, renderer or UI is started.
func _initialize() -> void:
	var pack := ""
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): pack = argument.trim_prefix("--pack=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if pack.is_empty() or output.is_empty() or not ProjectSettings.load_resource_pack(pack):
		push_error("Could not mount package for offline notice verification")
		quit(1); return
	var notices = load("res://ui/about/notices.tres")
	if notices == null or not notices.has_meta("notices"):
		push_error("Exported About notices are missing")
		quit(1); return
	var texts: Dictionary = notices.get_meta("notices")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Could not write notice verification result")
		quit(1); return
	file.store_string(JSON.stringify(texts, "  "))
	print("Offline exported About notices: ", texts.size(), " texts loaded")
	quit()

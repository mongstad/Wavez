extends RefCounted
# Exported Python cannot read res:// directly. Materialize the first-party archive
# into this worker's private job directory; no repository or installed Wavez module
# is used by a template build. Python and NumPy remain external dependencies.
const ARCHIVE := "res://analysis/python_runtime.zip"
static func prepare(directory: String) -> Dictionary:
	if OS.has_feature("editor"):
		return {"script":ProjectSettings.globalize_path("res://../tools/analyze_selection.py"), "error":""}
	var zip := ZIPReader.new()
	if zip.open(ARCHIVE) != OK:
		return {"script":"", "error":"This Wavez package is missing required analysis resources. Install a complete Wavez package."}
	var base := directory.path_join("python-runtime")
	var files: Array[String] = []
	for path in zip.get_files():
		if path.is_absolute_path() or ".." in path.split("/") or not (path.ends_with(".py") or path == "viewer/colormaps.json"):
			zip.close()
			return {"script":"", "error":"Invalid packaged Wavez analysis resource."}
		var destination := base.path_join(path)
		if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
			zip.close()
			return {"script":"", "error":"Cannot create private packaged-analysis directory."}
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null:
			zip.close()
			return {"script":"", "error":"Cannot write packaged Wavez analysis resource."}
		file.store_buffer(zip.read_file(path))
		files.append(destination)
		var problem := file.get_error()
		file.close()
		if problem != OK:
			zip.close()
			return {"script":"", "error":"Cannot finish packaged Wavez analysis resource."}
	zip.close()
	var script := base.path_join("tools/analyze_selection.py")
	return {"script":script, "files":files, "error":"" if FileAccess.file_exists(script) else "Packaged Wavez analysis entry point is missing."}

static func cleanup(files: Array[String], directory: String) -> void:
	# Only remove files we materialized, never members/results or user inputs.
	var base := directory.path_join("python-runtime")
	var folders: Array[String] = []
	for path in files:
		DirAccess.remove_absolute(path)
		var folder := path.get_base_dir()
		while folder.begins_with(base):
			if folder not in folders:folders.append(folder)
			if folder == base:break
			folder = folder.get_base_dir()
	folders.sort_custom(func(a,b):return a.length()>b.length())
	for folder in folders:DirAccess.remove_absolute(folder)

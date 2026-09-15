extends RefCounted
# Never parse high-resolution timestamps as floats. No shell is involved.
const LOCAL_FS := ["btrfs","ext2/ext3","xfs","tmpfs","overlayfs"]
static func supported(path: String) -> bool:
	if OS.get_name() != "Linux" or not FileAccess.file_exists("/usr/bin/stat"): return false
	var output: Array = []
	if OS.execute("/usr/bin/stat",PackedStringArray(["-f","--printf=%T","--",path]),output) != 0: return false
	return not output.is_empty() and str(output[0]).strip_edges() in LOCAL_FS

static func read(path: String) -> Dictionary:
	var output: Array = []
	if OS.get_name() != "Linux" or not FileAccess.file_exists("/usr/bin/stat"): return {}
	if OS.execute("/usr/bin/stat",PackedStringArray(["-L","--printf=%d\n%i\n%s\n%.9Y\n%.9Z","--",path]),output) != 0 or output.is_empty(): return {}
	var parts := str(output[0]).strip_edges().replace(",",".").split("\n")
	if parts.size() != 5: return {}
	for i in range(3):
		if not parts[i].is_valid_int() or int(parts[i]) < 0: return {}
	for i in [3,4]:
		var fields := parts[i].split(".")
		if fields.size() != 2 or not fields[0].is_valid_int() or fields[1].length() != 9 or not fields[1].is_valid_int(): return {}
	# Coarse timestamps cannot guard equal-size writes in the same second.
	if parts[4].ends_with(".000000000"): return {}
	return {"device":parts[0],"inode":parts[1],"size":parts[2],"mtime":parts[3],"ctime":parts[4]}

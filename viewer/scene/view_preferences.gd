extends RefCounted
## Transactional application preferences, independent of capture/view recipes.
const STORAGE_PATH := "user://view_preferences.json"
const MAX_BYTES := 65536
const PRESETS := ["Cinematic", "Scientific", "Temperature", "Density", "Velocity", "Minimal / Presentation"]
const BLOOM_MAX := 2.0
const BLOOM_DEFAULT := 0.30 # 15% of the existing 0–2 slider range; step is 0.02.
var storage_path := STORAGE_PATH
var settings := defaults()

static func defaults() -> Dictionary:
	var bloom := {}
	for preset in PRESETS: bloom[preset] = {"enabled":preset == "Cinematic", "intensity":BLOOM_DEFAULT}
	return {"preset":"Scientific", "bloom":bloom}

static func problem(candidate) -> String:
	if not candidate is Dictionary or candidate.size() != 2 or candidate.get("preset") not in PRESETS:
		return "Invalid viewing preset preference."
	var bloom = candidate.get("bloom")
	if not bloom is Dictionary or bloom.size() != PRESETS.size(): return "Invalid Bloom preferences."
	for preset in PRESETS:
		var entry = bloom.get(preset)
		if not entry is Dictionary or entry.size() != 2 or not entry.get("enabled") is bool:
			return "Invalid Bloom preference for " + preset + "."
		var intensity = entry.get("intensity")
		if not (intensity is int or intensity is float) or not is_finite(intensity) or intensity < 0 or intensity > BLOOM_MAX:
			return "Invalid Bloom intensity for " + preset + "."
	return ""

func reload() -> String:
	if not FileAccess.file_exists(storage_path): return ""
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null: return "Could not read viewing preferences."
	if file.get_length() > MAX_BYTES: file.close(); return "Viewing preferences exceed 64 KiB."
	var text := file.get_as_text(); file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary or not (parser.data.get("version") is int or parser.data.get("version") is float) or parser.data.get("version") != 1:
		return "Malformed viewing preferences."
	var candidate = parser.data.get("settings")
	var error := problem(candidate)
	if not error.is_empty(): return error
	settings = candidate.duplicate(true)
	return ""

func save(candidate: Dictionary) -> String:
	var error := problem(candidate)
	if not error.is_empty(): return error
	var text := JSON.stringify({"version":1, "settings":candidate})
	var path := ProjectSettings.globalize_path(storage_path)
	var temporary := path + ".tmp-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return "Could not save viewing preferences; the current session still uses your choices."
	file.store_string(text); file.flush()
	var result := file.get_error(); file.close()
	if result == OK: result = DirAccess.rename_absolute(temporary, path)
	if result != OK:
		DirAccess.remove_absolute(temporary)
		return "Could not save viewing preferences; the current session still uses your choices."
	settings = candidate.duplicate(true)
	return ""

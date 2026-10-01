extends RefCounted
## Authoritative identity lives in project.godot and travels with exported settings.
const SETTING := "application/config/version"

static func read() -> Dictionary:
	var value = ProjectSettings.get_setting(SETTING)
	if not value is String:
		return {"error":"Missing or non-string application/config/version in project settings."}
	var pattern := RegEx.new()
	pattern.compile("\\Av(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.([1-9][0-9]*)\\z")
	var matched := pattern.search(value)
	if matched == null:
		return {"error":"Invalid application/config/version: expected vMAJOR.MINOR.PATCH.BUILD with canonical non-negative release numbers and a positive BUILD."}
	return {"full":value,"release":"v%s.%s.%s" % [matched.get_string(1),matched.get_string(2),matched.get_string(3)],"build":matched.get_string(4)}

static func details() -> String:
	var identity := read()
	if identity.has("error"):return "WAVEZ version unavailable.\n\n"+identity.error
	return "WAVEZ "+identity.full

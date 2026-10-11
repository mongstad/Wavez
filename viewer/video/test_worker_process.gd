extends RefCounted
# Presentation tests need an owned child PID for the native process-running gate.
static func start() -> int:
	return OS.create_process("/bin/sleep",PackedStringArray(["120"]))
static func stop(dialog) -> void:
	if dialog.pid > 0: OS.kill(dialog.pid)
	dialog.pid = -1

extends RefCounted
## Presentation only: consumes the dialog's published snapshot, never worker files.
const TERMINAL := ["complete", "frames_ready", "failed", "cancelled"]
const ETA_INTERVAL_MS := 500
const RATE_WINDOW_SECONDS := 5.0

# One estimator per export dialog, shared by its status and Jobs Details.
# No timer/process loop: callers already refresh the published snapshot.
var _job := ""
var _stage := ""
var _frame := 0.0
var _seconds := 0.0
var _total := 0.0
var _seconds_per_frame := 0.0
var _next_eta_ticks := 0
var _remaining := ""

func present(state: Dictionary, now: int, for_dialog := false) -> String:
	var job := str(state.get("job", ""))
	var stage := str(state.get("stage", ""))
	if job != _job or stage != _stage:
		_reset_rate()
		_job = job; _stage = stage
	if stage != "rendering": return format(state, now, for_dialog)
	var data: Dictionary = state.get("progress", {})
	var current := float(data.get("current_frame", 0))
	var total := float(data.get("total_frames", 0))
	var seconds := float(data.get("elapsed_seconds", 0))
	if not (is_finite(current) and is_finite(total) and total > 0 and current >= 0 and current <= total and current == floor(current) and total == floor(total) and is_finite(seconds) and seconds >= 0):
		_reset_rate()
		return format(state, now, for_dialog, "Unavailable")
	var age := maxf(0, (now - int(state.get("progress_ticks", now))) / 1000.0)
	if age > maxf(10, 3 * seconds / maxf(1, current)):
		_reset_rate()
		return format(state, now, for_dialog, "Unavailable — no recent frame progress")
	if current < 2 or seconds < 1 or current >= total:
		_reset_rate()
		return format(state, now, for_dialog, "Waiting for render progress")
	if total != _total or current < _frame or seconds < _seconds:
		_reset_rate()
	if _seconds_per_frame == 0:
		_seconds_per_frame = seconds / current
		_frame = current; _seconds = seconds; _total = total
	elif current > _frame and seconds > _seconds:
		var interval := seconds - _seconds
		var observed_rate := interval / (current - _frame)
		# Time-weighted smoothing responds equally across fast/slow publication rates.
		_seconds_per_frame = lerpf(_seconds_per_frame, observed_rate, 1 - exp(-interval / RATE_WINDOW_SECONDS))
		_frame = current; _seconds = seconds
	if _remaining.is_empty() or now >= _next_eta_ticks:
		_remaining = duration(ceil(_seconds_per_frame * (total - current)))
		_next_eta_ticks = now + ETA_INTERVAL_MS
	return format(state, now, for_dialog, _remaining)

func _reset_rate() -> void:
	_frame = 0; _seconds = 0; _total = 0; _seconds_per_frame = 0
	_next_eta_ticks = 0; _remaining = ""

static func duration(seconds: float) -> String:
	var whole := int(maxf(0, seconds))
	return "%02d:%02d:%02d" % [whole / 3600, (whole / 60) % 60, whole % 60]

static func format(state: Dictionary, now: int, for_dialog := false, remaining_override := "") -> String:
	if state.is_empty(): return "No video export in this session."
	var stage := str(state.get("stage", "starting"))
	var data: Dictionary = state.get("progress", {})
	var current := float(data.get("current_frame", 0))
	var total := float(data.get("total_frames", 0))
	var valid: bool = is_finite(current) and is_finite(total) and total > 0 and current >= 0 and current <= total and current == floor(current) and total == floor(total)
	var age := maxf(0, (now - int(state.get("snapshot_ticks", now))) / 1000.0)
	var elapsed := float(state.get("elapsed_seconds", 0))
	if stage not in TERMINAL: elapsed += age
	var valid_elapsed := is_finite(elapsed) and elapsed >= 0
	var summary := stage.replace("_", " ").capitalize()
	if valid:
		var percent := int(floor(100.0 * current / total))
		if stage == "rendering": summary = "Rendering frame %d / %d (%d%%)" % [current, total, percent]
		else: summary += " — %d / %d frames rendered (%d%%)" % [current, total, percent]
	elif stage == "rendering": summary += " — frame count unavailable"
	var remaining := "Unavailable"
	if stage == "complete" or stage == "frames_ready": remaining = "00:00:00"
	elif stage == "cancelling": remaining = "Unavailable while cancelling"
	elif stage == "encoding": remaining = "Unavailable while encoding"
	elif stage == "rendering" and valid and valid_elapsed:
		var progress_age := maxf(0, (now - int(state.get("progress_ticks", now))) / 1000.0)
		var observed_elapsed := float(data.get("elapsed_seconds", 0))
		if progress_age > maxf(10, 3 * observed_elapsed / maxf(1, current)):
			remaining = "Unavailable — no recent frame progress"
		elif current >= 2 and elapsed >= 1 and current < total:
			remaining = duration(ceil(elapsed * (total - current) / current))
		else: remaining = "Waiting for render progress"
	if not remaining_override.is_empty(): remaining = remaining_override
	var lines := [summary, "Elapsed: " + (duration(elapsed) if valid_elapsed else "Unavailable"), "Estimated remaining: " + remaining]
	if stage in ["failed", "cancelled"]:
		var detail := str(state.get("detail", ""))
		# Keep refusal/diagnostic content, referencing the single labeled path below.
		var directory := str(state.get("directory", ""))
		if not directory.is_empty(): detail = detail.replace(directory, "[Temporary files]")
		if not detail.is_empty(): lines.append(detail)
	elif stage == "frames_ready": lines.append("FFmpeg unavailable. PNG frames and encoding instructions retained.")
	elif stage == "cancelling": lines.append("Cancellation requested; waiting for worker acknowledgement.")
	var paths := [["Output", "output"], ["Temporary files", "directory"]]
	if for_dialog:
		paths = [["Temporary files", "directory"]] if stage in ["failed", "cancelled", "frames_ready"] else []
	for entry in paths:
		var path := str(state.get(entry[1], ""))
		if not path.is_empty(): lines.append(entry[0] + ": " + path)
	return "\n".join(lines)

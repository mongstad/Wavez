extends RefCounted
## Opt-in diagnostic counters for the native resize regression harness.
static var enabled := false
static var totals := {}
static var counts := {}
static var maxima := {}

static func reset() -> void:
	totals.clear()
	counts.clear()
	maxima.clear()

static func stamp() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func record(label: String, started: int) -> void:
	if not enabled: return
	var elapsed := Time.get_ticks_usec() - started
	totals[label] = totals.get(label, 0) + elapsed
	counts[label] = counts.get(label, 0) + 1
	maxima[label] = maxi(maxima.get(label, 0), elapsed)

static func report() -> Dictionary:
	var result := {}
	for label in counts:
		result[label] = {"calls":counts[label], "total_ms":totals[label]/1000.0, "max_ms":maxima[label]/1000.0}
	return result

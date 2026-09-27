extends RefCounted
# Main-thread policy. Pure observations/decisions; never owns jobs or cache data.
var cap := 1
var automatic := true
var active := 1
var changed_at := 0.0
var blocked_until := 0.0
var rate := 0.0
var measured_seconds := 0.0
var previous := {}
var frame_pressure := 0
var events: Array = []
var last := {}
func setup(maximum: int, dynamic: bool) -> void:
	cap = maximum;automatic = dynamic;active = mini(2,cap) if automatic else cap
func reset_rates(metrics: Dictionary) -> void:
	rate = 0;measured_seconds = 0;previous = metrics.duplicate(true)
func _change(now: float, count: int, reason: String) -> void:
	count = clampi(count,1,cap)
	if count == active:return
	events.append({"seconds":now,"from":active,"to":count,"reason":reason,"producer":rate,"consumer":last.get("consumer",0),"ahead_seconds":last.get("ahead_seconds",0)})
	if events.size() > 256:events.pop_front()
	active = count;changed_at = now;rate = 0;measured_seconds = 0
func tick(now: float, sample: Dictionary) -> int:
	last = sample.duplicate();last.erase("rates")
	var metrics: Dictionary = sample.get("rates",{})
	var key := str(active);var current: Dictionary = metrics.get(key,{})
	var old: Dictionary = previous.get(key,{})
	var seconds := float(current.get("seconds",0))-float(old.get("seconds",0))
	if seconds >= .5:
		var observed := (float(current.get("samples",0))-float(old.get("samples",0)))/seconds
		rate = observed if measured_seconds == 0 else lerpf(rate,observed,.35)
		measured_seconds += seconds;previous = metrics.duplicate(true)
	if not automatic:return active
	var pressure := ""
	if sample.get("swap",0) > 0:pressure = "process_swap"
	elif sample.get("memory_pressure",false):pressure = "memory_headroom"
	elif sample.get("admission_pressure",false):pressure = "admission_pressure"
	frame_pressure = frame_pressure+1 if sample.get("frame_p95_ms",0) > 66.667 else 0
	if pressure.is_empty() and frame_pressure >= 2:pressure = "presentation_pressure"
	if not pressure.is_empty():
		blocked_until = now+10
		_change(now,1 if pressure != "presentation_pressure" else active-1,pressure)
		previous = metrics.duplicate(true);return active
	if not sample.get("demand",false):return active # Sleeping semaphores use no CPU.
	if now < blocked_until or now-changed_at < 3:return active
	var ahead := float(sample.get("ahead_seconds",0));var consumer := float(sample.get("consumer",0))
	if ahead >= 30 and not sample.get("waiting",false):
		_change(now,active-1,"comfortable_lead");blocked_until = now+10
	elif measured_seconds >= 2 and sample.get("can_grow",false):
		if rate < consumer*1.15 and ahead < 15:
			_change(now,active+1,"producer_below_margin")
		elif sample.get("waiting",false) and ahead < 3:
			_change(now,active+1,"startup_or_seek")
	previous = metrics.duplicate(true) if now == changed_at else previous
	return active
func gate(consumer: float, ahead_seconds: float, all_ready: bool) -> Dictionary:
	var ratio := rate/consumer if consumer > 0 else 0.0
	var lead := 3.0 if ratio >= 1.10 else 8.0
	var confident := measured_seconds >= 3 and ratio >= .95
	return {"ready":all_ready or (confident and ahead_seconds >= lead),"producer":rate,"consumer":consumer,"ratio":ratio,"measured_seconds":measured_seconds,"required_lead_seconds":lead if confident else -1.0,"reason":"admitted_window" if all_ready else ("faster_producer" if confident and ratio >= 1.10 else ("near_parity" if confident else "conservative_window"))}
func report() -> Dictionary:
	return {"mode":"auto" if automatic else "fixed","cap":cap,"active_limit":active,"producer":rate,"measured_seconds":measured_seconds,"blocked_until":blocked_until,"events":events.duplicate(true),"signals":last.duplicate(true)}

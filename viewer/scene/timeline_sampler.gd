extends RefCounted
# Shared physical-time sampler for UI, inspection and offline video.
var times := PackedFloat64Array()
var error := ""
var viewer
var cached_index := -1
var valid_axis := false
var source_generation := -1

func build(scene) -> bool:
	viewer = scene
	source_generation = scene.capture_generation
	valid_axis = false
	error = ""
	cached_index = -1
	times.clear()
	if scene.frame_count == 0:
		error = "No complete frames to export."
		return false
	for i in range(scene.frame_count):
		var t: float = scene.generic_reader.frames[i].time
		if not is_finite(t) or (i > 0 and t <= times[i-1]):
			error = "Physical time requires strictly increasing finite timestamps (frame %d); use frame-index mode." % i
			return false
		times.append(t)
	valid_axis = true
	return true

func bracket(time: float) -> Dictionary:
	if times.is_empty() or not valid_axis or not is_finite(time) or time < times[0] or time > times[-1]: return {}
	var lo := 0
	var hi := times.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if times[mid] < time: lo = mid + 1
		else: hi = mid
	if lo < times.size() and times[lo] == time:
		return {"a":lo,"b":lo,"alpha":0.0,"requested_time":time,"status":"exact"}
	var a := maxi(0,lo-1)
	return {"a":a,"b":lo,"alpha":(time-times[a])/(times[lo]-times[a]),"requested_time":time,"status":"interpolated"}

func sample(time: float) -> Dictionary:
	if viewer.scene_layers == null:
		error = "Open a SIMSCP3 scene before sampling."
		return {}
	var result: Dictionary = viewer.scene_layers.sample(time)
	error = viewer.scene_layers.error
	return result

static func camera_at(state: Dictionary, video_time: float, orbit: bool, speed: float) -> Transform3D:
	var util = preload("res://scene/visual_state.gd")
	var a: Array = state.camera_transform
	var initial := Transform3D(Basis(util.vector(a[0]), util.vector(a[1]), util.vector(a[2])), util.vector(a[3]))
	if not orbit: return initial
	var target: Vector3 = util.vector(state.camera_target)
	var rotation := Basis(Vector3.UP, speed * video_time)
	return Transform3D(rotation * initial.basis, target + rotation * (initial.origin - target))

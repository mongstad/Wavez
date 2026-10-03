extends Node
# One internal source-analysis worker. No listener; all work belongs to this viewer.
signal completed(result: Dictionary)
signal failed(message: String)
signal background_completed(result: Dictionary)
signal background_failed(message: String)
signal background_progress(value: Dictionary)
const MAX_CONTROL := 1048576
const Buffer = preload("res://layers/playback_buffer.gd")
const Profile = preload("res://scene/playback_profile.gd")
var directory := ""
var member_directory := ""
var worker_pid := -1
var serial := 0
var current_id := ""
var scene_revision := 0
var selection_revision := 0
var pending := false
var worker_ready := false
var error := ""
var last_poll := 0.0
var last_lease := 0.0
var memory_bytes := 512*1048576
var last_result := {}
var member_pins: Array = []
var result_pins: Array = []
var background_error_code := "" # Presentation-only availability for Resolve input.
var background_pending := false
var background_id := ""
var background_scene := 0
var background_selection := 0
var analysis_revision := 0
var background_operation := ""
var background_cancel_id := ""
var background_cancel_time := 0.0
var playback_owner
var playback_pressure := false
var foreground_cancel_id := ""
var foreground_cancel_time := 0.0

func _ready() -> void:
	set_process(false)

func start(cache_root := "") -> bool:
	if worker_pid > 0 and OS.is_process_running(worker_pid): return true
	if not directory.is_empty():shutdown()
	var headroom := Buffer.memory_headroom()
	if headroom.available_physical < headroom.reserve+memory_bytes+256*1048576:
		error = "Analysis paused to preserve physical RAM headroom.";failed.emit(error);return false
	var base: String = cache_root if not cache_root.is_empty() else ProjectSettings.globalize_path("res://../.wavez-cache/analysis-workers")
	directory = base.path_join("%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		error = "Cannot create private analysis job directory.";failed.emit(error);return false
	_write("lease.json",{"owner":OS.get_process_id()})
	if member_directory.is_empty():member_directory = directory.path_join("members")
	var script := ProjectSettings.globalize_path("res://../tools/analyze_selection.py")
	worker_pid = OS.create_process("/usr/bin/env",PackedStringArray(["python3",script,"--directory",directory,"--owner-pid",str(OS.get_process_id()),"--assets-root",member_directory]),false)
	worker_ready = false;error = "";last_result = {}
	playback_pressure = false;foreground_cancel_id = ""
	if worker_pid <= 0:
		error = "Cannot start Python/NumPy analysis worker.";failed.emit(error);return false
	set_process(true)
	return true

func request(source: Dictionary, operation: String, arguments: Dictionary, source_revision: int, selection_version: int, analysis_version := 0) -> String:
	if worker_pid <= 0 or not OS.is_process_running(worker_pid):
		if not start(): return ""
	serial += 1
	current_id = "%d-%d" % [OS.get_process_id(),serial]
	scene_revision = source_revision;selection_revision = selection_version
	var job := {"version":1,"id":current_id,"scene_revision":scene_revision,"selection_revision":selection_revision,"analysis_revision":analysis_version,"source":source.duplicate(true),"operation":operation,"arguments":arguments.duplicate(true),"budget":{"memory_bytes":memory_bytes},"member_pins":member_pins,"result_pins":result_pins}
	if not _write("request.json",job):
		error = "Invalid or oversized analysis request.";pending = false;failed.emit(error);return ""
	pending = true;error = ""
	return current_id

func request_background(source: Dictionary, operation: String, arguments: Dictionary, source_revision: int, selection_version: int, analysis_version: int, budget_override: Dictionary = {}) -> String:
	if worker_pid <= 0 or not OS.is_process_running(worker_pid):
		if not start():return ""
	background_error_code = ""
	serial += 1;background_id = "%d-b%d" % [OS.get_process_id(),serial]
	background_scene = source_revision;background_selection = selection_version;analysis_revision = analysis_version;background_operation = operation
	var job := {"version":1,"id":background_id,"scene_revision":source_revision,"selection_revision":selection_version,"analysis_revision":analysis_version,"source":source.duplicate(true),"operation":operation,"arguments":arguments.duplicate(true),"budget":{"memory_bytes":memory_bytes},"member_pins":member_pins,"result_pins":result_pins}
	job.budget.merge(budget_override,true)
	if not _write("background_request.json",job):
		error = "Invalid or oversized interval request.";background_pending = false;background_failed.emit(error);return ""
	background_pending = true;background_cancel_id = "";error = ""
	return background_id

func cancel_background() -> void:
	if background_pending and not background_id.is_empty():
		_write("background_cancel.json",{"id":background_id})
		background_cancel_id = background_id;background_cancel_time = Time.get_ticks_msec()/1000.0
	background_pending = false;background_id = ""

func busy() -> bool:
	return pending or background_pending or not background_cancel_id.is_empty()

func cancel() -> void:
	if pending and not current_id.is_empty():
		_write("cancel.json",{"id":current_id})
		if foreground_cancel_id.is_empty():foreground_cancel_id = current_id;foreground_cancel_time = Time.get_ticks_msec()/1000.0
	pending = false;current_id = "";serial += 1

func shutdown() -> void:
	cancel();cancel_background();background_cancel_id = "";foreground_cancel_id = ""
	if not directory.is_empty(): _write("close",{})
	# No UI join. Native process termination also handles a stuck bounded call.
	if worker_pid > 0 and OS.is_process_running(worker_pid): OS.kill(worker_pid)
	worker_pid = -1;worker_ready = false;set_process(false)
	# Transport is a fixed set of small files. Never recurse through user paths.
	if not directory.is_empty():
		for name in ["lease.json","request.json","cancel.json","close","ready.json","result.json","progress.json","stopped.json","background_request.json","background_cancel.json","background_result.json","background_progress.json","playback_pressure.json"]:
			for suffix in ["", ".tmp"]:
				var path: String = directory.path_join(name+suffix)
				if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(directory.path_join("members")) # Remove only when empty.
		DirAccess.remove_absolute(directory)
		directory = ""

func _exit_tree() -> void:
	shutdown()

func _process(_delta: float) -> void:
	var started := Profile.begin()
	_poll()
	Profile.end("g4_worker_poll",started)

func _poll() -> void:
	var now := Time.get_ticks_msec()/1000.0
	if now-last_lease >= 1.0:
		_write("lease.json",{"owner":OS.get_process_id()});last_lease = now
	if now-last_poll < .05: return
	last_poll = now
	if worker_pid <= 0: return
	if not OS.is_process_running(worker_pid):
		worker_pid = -1;worker_ready = false
		if pending: error = "Analysis worker stopped before completing the request.";pending = false;failed.emit(error)
		if background_pending:error = "Interval worker stopped before completing the request.";background_pending = false;background_failed.emit(error)
		background_cancel_id = "";foreground_cancel_id = ""
		return
	var underflow := false
	if background_pending and is_instance_valid(playback_owner) and playback_owner.playing and playback_owner.scene_layers != null:
		underflow = playback_owner.scene_layers.is_buffering()
	if underflow != playback_pressure:
		if _write("playback_pressure.json",{"underflow":underflow}):playback_pressure = underflow
	if not worker_ready: worker_ready = not _read("ready.json").is_empty()
	if not foreground_cancel_id.is_empty():
		var acknowledgement := _read("result.json")
		var progress := _read("progress.json")
		if acknowledgement.get("id") == foreground_cancel_id or (not current_id.is_empty() and (acknowledgement.get("id") == current_id or progress.get("id") == current_id)):foreground_cancel_id = ""
		elif now-foreground_cancel_time > 2.0:
			shutdown();error = "Worker terminated after selection cancellation grace period.";failed.emit(error);return
	if pending:
		var result := _read("result.json")
		if result.get("id") == current_id and result.get("scene_revision") == scene_revision and result.get("selection_revision") == selection_revision:
			pending = false;last_result = result
			if result.get("ok",false):completed.emit(result)
			else:error = result.get("error","Analysis failed.");failed.emit(error)
	if not background_cancel_id.is_empty():
		if _read("background_result.json").get("id") == background_cancel_id:background_cancel_id = ""
		elif now-background_cancel_time > 2.0:
			shutdown();background_failed.emit("Worker terminated after cancellation grace period.");return
	if background_pending:
		var result := _read("background_result.json")
		if result.get("id") == background_id and result.get("scene_revision") == background_scene and result.get("selection_revision") == background_selection and result.get("analysis_revision") == analysis_revision:
			background_pending = false
			if result.get("ok",false):background_completed.emit(result)
			else:
				background_error_code = result.get("code","")
				error = result.get("error","Interval analysis failed.");background_failed.emit(error)
		else:
			var progress := _read("background_progress.json")
			if progress.get("id") == background_id:background_progress.emit(progress)

func _write(name: String, value: Dictionary) -> bool:
	if directory.is_empty(): return false
	var text := JSON.stringify(value,"",true,true)
	if text.to_utf8_buffer().size() > MAX_CONTROL: return false
	var path := directory.path_join(name)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(text);file.close()
	return DirAccess.rename_absolute(path+".tmp",path) == OK

func _read(name: String) -> Dictionary:
	var file := FileAccess.open(directory.path_join(name),FileAccess.READ)
	if file == null or file.get_length() > MAX_CONTROL: return {}
	var result = JSON.parse_string(file.get_as_text())
	return result if result is Dictionary else {}

extends Node
signal job_failed(message: String)
const UI = preload("res://analysis/ui_controls.gd")
# Explicit two-run preparation and sequential reuse of the existing renderer.
const State = preload("res://analysis/inspection_v3.gd")
const Job = preload("res://video/render_job.gd")
var temporal
var viewer
var panel: VBoxContainer
var status: Label
var sides: Array = []
var common: Dictionary = {}
var prepared := {}
var pid := -1
var index := 0
var active_path := ""
var stopping := false
var poll := 0.0
var preparing := false

func field(label: String, value: String) -> LineEdit:
	var text := Label.new();text.text = label;panel.add_child(text)
	var edit := LineEdit.new();edit.text = value;panel.add_child(edit);return edit

func setup(control) -> void:
	temporal = control;viewer = control.viewer;panel = viewer._section("Matched runs")
	status = Label.new();status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;panel.add_child(status)
	status.text = "Compare two saved scenes with the current camera and a shared scalar range. Confirm their coordinates and time mapping."
	for label in ["Left","Right"]:
		var side := {"recipe":{},"path":"","sha256":""}
		viewer._button(panel,label+" recipe…",func():choose_recipe(side))
		side.keys = field(label+" selection keys","")
		side.object = field(label+" layer ID","");side.channel = field(label+" scalar channel","")
		for key in ["time_scale","time_offset","value_scale","value_offset"]:side[key] = field(label+" "+key.replace("_"," "),"1" if key.ends_with("scale") else "0")
		side.origin = field(label+" time-offset reason","declared native origin")
		sides.append(side)
	for item in [["time_units","Aligned time units","s"],["time_reference","Common time reference","declared common origin"],["value_units","Common scalar units","unknown"],["value_reference","Common scalar quantity","declared scalar"],["coordinate_units","World coordinate units","m"],["coordinate_reference","World origin and axes",""],["lower","Shared range minimum","0"],["upper","Shared range maximum","1"],["colormap","Shared colormap","viridis"],["start_time","Aligned start","0"],["end_time","Aligned end (same = snapshot)","0"],["fps","FPS","24"],["playback_rate","Aligned time per video second","1"],["width","Width","640"],["height","Height","360"],["quota_bytes","Pair output limit (MiB)","1024"],["folder","New comparison folder","matched-runs"]]:
		common[item[0]] = field(item[1],item[2])
	viewer._button(panel,"Prepare matched views…",choose_prepare)
	viewer._button(panel,"Render matched views",start_pair)
	viewer._button(panel,"Cancel matched views",cancel)
	for n in range(sides.size()):
		var side: Dictionary = sides[n]
		UI.hint(side.keys,"Comma-separated selection keys from this recipe. Identical IDs in different captures are not automatically matched.")
		UI.hint(side.time_offset,"Aligned time = raw time × scale − offset. Describe the offset; no automatic event alignment is performed.")
		UI.hint(side.value_scale,"Scene color scales must be positive. Common bounds are converted to source bounds; source values are unchanged.")
		UI.group(panel,side.time_scale,side.origin,"Advanced • "+("Left" if n == 0 else "Right")+" mapping")
	UI.hint(common.coordinate_reference,"Declare compatible world origin, axes and units. Matched rendering does not register or rescale geometry.")
	UI.group(panel,common.playback_rate,common.quota_bytes,"Advanced • Video and output limits")
	UI.fit(panel)
	temporal.jobs.background_completed.connect(completed)
	temporal.jobs.background_failed.connect(func(message):
		if preparing:preparing = false;status.text = message)
	set_process(false)

func choose_recipe(side: Dictionary) -> void:
	var dialog := FileDialog.new();dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE;dialog.access = FileDialog.ACCESS_FILESYSTEM;dialog.filters = PackedStringArray(["*.json ; G4 inspection"])
	dialog.use_native_dialog = true;dialog.mode_overrides_title = false;dialog.title = "Load inspection"
	add_child(dialog);dialog.file_selected.connect(func(path):select_recipe(side,path);dialog.queue_free());dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)

func select_recipe(side: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 983040:status.text = "Choose a valid inspection recipe.";return false
	var recipe = JSON.parse_string(file.get_as_text())
	if not recipe is Dictionary or recipe.get("version") != 3 or not recipe.get("source") is Dictionary:status.text = "Expected G4 inspection version 3.";return false
	side.recipe = recipe;side.path = path;side.sha256 = FileAccess.get_sha256(path)
	var payload = State.unpack(recipe.get("payload",{}));var keys: Array = []
	if payload is Dictionary:
		for definition in payload.get("selections",{}).get("definitions",[]):keys.append(definition.get("key",""))
	status.text = "Selected %s\nAvailable keys: %s\nExplicitly select its capture through Analysis export and state if it has not been opened." % [path,", ".join(keys)]
	return true

func choose_prepare() -> void:
	if not common.folder.text.is_valid_filename():status.text = "Choose a new comparison folder name.";return
	var dialog := FileDialog.new();dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR;dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true;dialog.mode_overrides_title = false;dialog.title = "Choose comparison folder"
	add_child(dialog);dialog.dir_selected.connect(func(parent):prepare_to(parent.path_join(common.folder.text));dialog.queue_free());dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)

func prepare_to(destination: String) -> void:
	if preparing or pid > 0:status.text = "Finish or cancel current matched work first.";return
	if temporal.jobs.background_operation == "spatial_spectrum" and (temporal.jobs.background_pending or not temporal.jobs.background_cancel_id.is_empty()):status.text = "Finish or cancel Spatial spectrum before preparing matched views.";return
	var arguments := {"destination":destination,"opened_paths":temporal.durable.opened_paths.duplicate()}
	for n in range(2):
		var side: Dictionary = sides[n]
		if side.recipe.is_empty():status.text = "Select both inspections and enter their selection correspondence.";return
		var item := {"source":side.recipe.source,"recipe_path":side.path,"recipe_sha256":side.sha256,"selection_keys":Array(side.keys.text.split(",",false)),"object":side.object.text,"channel":side.channel.text}
		for i in item.selection_keys.size():item.selection_keys[i] = item.selection_keys[i].strip_edges()
		for part in ["time","value"]:
			for suffix in ["scale","offset"]:
				if not temporal._valid_number(side[part+"_"+suffix]):status.text = "Mappings require finite numbers.";return
			item[part] = State.pack({"units":common[part+"_units"].text,"reference":common[part+"_reference"].text,"scale":side[part+"_scale"].text.to_float(),"offset":side[part+"_offset"].text.to_float(),"origin":side.origin.text if part == "time" else "explicit user value conversion"})
		arguments["left" if n == 0 else "right"] = item
	var settings := {"camera":{},"coordinates":{"units":common.coordinate_units.text,"reference":common.coordinate_reference.text},"range":[],"colormap":common.colormap.text,"timing":{},"quality":"high"}
	var visual := Job.snapshot(viewer)
	for key in ["camera_transform","camera_target","camera","camera_distance","yaw","pitch"]:settings.camera[key] = visual[key]
	for key in ["lower","upper","start_time","end_time","playback_rate"]:
		if not temporal._valid_number(common[key]):status.text = "Shared bounds and times require finite numbers.";return
	settings.range = [common.lower.text.to_float(),common.upper.text.to_float()]
	for key in ["start_time","end_time","playback_rate"]:settings.timing[key] = common[key].text.to_float()
	for key in ["fps","width","height","quota_bytes"]:
		if not common[key].text.is_valid_int():status.text = "Dimensions, FPS and quota require integers.";return
		if key == "fps":settings.timing.fps = common[key].text.to_int()
		else:settings[key] = common[key].text.to_int()*(1048576 if key == "quota_bytes" else 1)
	arguments.common = State.pack(settings);prepared = {};preparing = true;temporal.revision += 1
	temporal._launch("prepare_matched_render",arguments,temporal.selections.source)
	status.text = "Verifying both explicit sources, selections and mappings before publishing the pair."

func completed(result: Dictionary) -> void:
	if temporal.jobs.background_operation != "prepare_matched_render":return
	preparing = false
	if int(result.scene_revision) != viewer.capture_generation or int(result.selection_revision) != temporal.selections.state.revision or int(result.analysis_revision) != temporal.revision:return
	prepared = result.data.matched_render
	status.text = "Matched views ready: %s\n%d frames per view." % [prepared.path,prepared.frames]

func start_pair() -> void:
	if pid > 0 or prepared.is_empty():status.text = "Prepare a new matched pair first.";return
	stopping = false;index = 0;launch_next()

func launch_next() -> void:
	if stopping:return
	if index >= 2:
		status.text = "Matched pair complete: "+prepared.path;set_process(false)
		if viewer.session_log != null: viewer.session_log.record("JOB", "Matched views completed: " + str(prepared.path), true)
		return
	var entry: Dictionary = prepared.jobs[index];active_path = entry.path
	if FileAccess.get_sha256(active_path) != entry.sha256:status.text = "Prepared job changed; render refused.";job_failed.emit(status.text);return
	var job = JSON.parse_string(FileAccess.get_file_as_string(active_path))
	if not job is Dictionary:status.text = "Invalid prepared job.";job_failed.emit(status.text);return
	var args := Job.launch_arguments(active_path,int(job.fps))
	pid = OS.create_process(OS.get_executable_path(),args)
	if pid <= 0:status.text = "Could not launch matched renderer.";job_failed.emit(status.text);return
	if viewer.session_log != null: viewer.session_log.record("JOB", "Matched views started: %s path=%s" % ["left" if index == 0 else "right", active_path], true)
	status.text = "Rendering the %s view…" % ("left" if index == 0 else "right");set_process(true)

func cancel() -> void:
	if (preparing or pid > 0) and viewer.session_log != null: viewer.session_log.record("JOB", "Matched views cancellation requested", true)
	stopping = true
	if preparing:
		if temporal.jobs.background_operation == "prepare_matched_render":temporal.jobs.cancel_background()
		preparing = false
	if pid > 0:
		var file := FileAccess.open(active_path.get_base_dir().path_join("cancel"),FileAccess.WRITE)
		if file != null:file.store_string("cancel");file.close()
	status.text = "Cancellation requested; completed output is retained."

func _process(delta: float) -> void:
	poll += delta
	if pid <= 0 or poll < .2:return
	poll = 0
	var progress_path := active_path.get_base_dir().path_join("progress.json")
	var progress = JSON.parse_string(FileAccess.get_file_as_string(progress_path)) if FileAccess.file_exists(progress_path) else {}
	if OS.is_process_running(pid):
		if progress is Dictionary and not progress.is_empty():status.text = "%s input: %s" % ["Left" if index == 0 else "Right",progress.get("message","")]
		return
	OS.get_process_exit_code(pid);pid = -1
	if stopping or not progress is Dictionary or progress.get("stage") != "complete":
		status.text = "Matched rendering stopped; partial output retained: "+active_path.get_base_dir()
		if stopping and viewer.session_log != null: viewer.session_log.record("JOB", "Matched views cancelled: " + active_path, true)
		if not stopping: job_failed.emit(status.text)
		set_process(false);return
	index += 1;launch_next()

func _exit_tree() -> void:
	if pid > 0 or preparing:cancel()

extends Node
const UI = preload("res://analysis/ui_controls.gd")
# Numerical output and validated portable inspection state.
const State = preload("res://analysis/inspection_v3.gd")
var temporal
var viewer
var panel: VBoxContainer
var status: Label
var folder_name: LineEdit
var quota: LineEdit
var cpu_limit: LineEdit
var wall_limit: LineEdit
var include_members: CheckButton
var last_export := {}
var last_recipe := {}
var opened_paths: Array = []
var bundle_results: CheckButton
var pending_fingerprint := ""

func setup(controller) -> void:
	temporal = controller;viewer = temporal.viewer;panel = viewer._section("Analysis export and state")
	status = Label.new();status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;panel.add_child(status)
	status.text = "Export complete values or save the view with selections and analysis."
	folder_name = field("New folder name","wavez-analysis")
	quota = field("Output limit (MiB)","256")
	cpu_limit = field("CPU time limit (seconds)","120");wall_limit = field("Elapsed time limit (seconds)","150")
	include_members = viewer._check(panel,"Include selection members",true,func(_v):pass)
	viewer._button(panel,"Export numerical data…",choose_export)
	bundle_results = viewer._check(panel,"Include completed results in recipe",true,func(_v):pass)
	viewer._button(panel,"Save inspection recipe…",choose_save)
	viewer._button(panel,"Load inspection recipe…",choose_load)
	viewer._button(panel,"Locate referenced input…",choose_input)
	viewer._button(panel,"Recompute selected analysis",recompute)
	UI.hint(include_members,"Include exact selection-member files in the numerical export. Omitting them leaves external references; values.csv still contains every result row.")
	UI.hint(bundle_results,"Include completed numerical results for portable restore. Without them, restore requires the original cached result files.")
	UI.hint(quota,"Finite output limit in MiB. Requests refuse if complete output cannot fit; scientific rows are never silently dropped.")
	UI.group(panel,quota,include_members,"Advanced • Export limits and members")
	UI.fit(panel)
	temporal.jobs.background_completed.connect(completed)

func field(label: String, initial: String) -> LineEdit:
	var title := Label.new();title.text = label;panel.add_child(title)
	var edit := LineEdit.new();edit.text = initial;panel.add_child(edit);return edit

func choose_export() -> void:
	if temporal.current_result.is_empty():status.text = "Select a complete numerical result first.";return
	if not folder_name.text.is_valid_filename():status.text = "Choose a valid new folder name.";return
	var dialog := FileDialog.new();dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR;dialog.access = FileDialog.ACCESS_FILESYSTEM;dialog.title = "Choose parent directory for the new numerical export"
	dialog.use_native_dialog = true;dialog.mode_overrides_title = false
	add_child(dialog);dialog.dir_selected.connect(func(parent):export_to(parent.path_join(folder_name.text));dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)

func export_to(destination: String) -> void:
	if temporal.current_result.is_empty():status.text = "Select a complete numerical result first.";return
	if not quota.text.is_valid_int() or not temporal._valid_number(cpu_limit) or not temporal._valid_number(wall_limit):status.text = "Use an integer quota and finite deadlines.";return
	if quota.text.to_int() < 1 or quota.text.to_int() > 65536:status.text = "Output quota must be 1–65536 MiB.";return
	var arguments := {"result":temporal.current_result,"destination":destination,"quota_bytes":quota.text.to_int()*1048576,"include_members":include_members.button_pressed}
	temporal.revision += 1;last_export = {}
	temporal._launch("export_analysis",arguments,temporal.current_source,{"cpu_seconds":cpu_limit.text.to_float(),"wall_seconds":wall_limit.text.to_float()})
	status.text = "Exporting complete values and provenance…"

func completed(result: Dictionary) -> void:
	if int(result.scene_revision) != viewer.capture_generation or int(result.selection_revision) != temporal.selections.state.revision or int(result.analysis_revision) != temporal.revision:return
	match temporal.jobs.background_operation:
		"export_analysis":
			last_export = result.data.export
			status.text = "Export complete: %s\n%d data rows with exact IDs, times and provenance." % [last_export.path,int(last_export.row_count)]
		"save_recipe":
			last_recipe = result.data.saved_recipe;status.text = "Saved portable inspection: "+last_recipe.path
		"load_recipe":
			if pending_fingerprint != fingerprint():status.text = "View changed during validation; no recipe state was applied. Load again when ready.";return
			if result.data.source_stamp != preload("res://data/source_stamp.gd").read(viewer.capture_path):status.text = "Source changed after validation; no state was applied.";return
			var payload = State.unpack(result.data.recipe.payload)
			if not payload is Dictionary:status.text = "Invalid validated state payload.";return
			var problem := State.apply_verified(temporal,payload)
			if not problem.is_empty():status.text = problem;return
			last_recipe = {"restored":true,"sha256":result.data.recipe_sha256};status.text = "Restored selections, groups and analysis. Playback is paused; choose a plot or recompute when ready."

func remember_path(path: String) -> void:
	if path.is_absolute_path() and path not in opened_paths and opened_paths.size() < 128:opened_paths.append(path)

func fingerprint() -> String:
	return JSON.stringify([preload("res://scene/visual_state.gd").snapshot(viewer),viewer.committed_sample,temporal.selections.state.snapshot(),temporal.revision],"",true,true)

func choose_input() -> void:
	var dialog := FileDialog.new();dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE;dialog.access = FileDialog.ACCESS_FILESYSTEM;dialog.title = "Locate a referenced capture, CSV or surface"
	dialog.use_native_dialog = true;dialog.mode_overrides_title = false
	add_child(dialog);dialog.file_selected.connect(func(path):remember_path(path);status.text = "Referenced input selected: "+path;dialog.queue_free());dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)

func choose_save() -> void:
	if not folder_name.text.is_valid_filename():status.text = "Choose a valid new bundle folder name.";return
	var dialog := FileDialog.new();dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR;dialog.access = FileDialog.ACCESS_FILESYSTEM;dialog.title = "Choose parent for the new recipe bundle"
	dialog.use_native_dialog = true;dialog.mode_overrides_title = false
	add_child(dialog);dialog.dir_selected.connect(func(parent):save_to(parent.path_join(folder_name.text+".inspection"));dialog.queue_free());dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)

func save_to(destination: String, scene_only := false, output_quota := -1) -> void:
	var recipe := State.scene_snapshot(temporal) if scene_only else State.snapshot(temporal,bundle_results.button_pressed)
	if recipe.is_empty():status.text = "Bind the current source before saving G4 state.";return
	if not quota.text.is_valid_int() or not temporal._valid_number(cpu_limit) or not temporal._valid_number(wall_limit):status.text = "Choose a finite quota and deadlines.";return
	var payload = State.unpack(recipe.payload);var problem := State.preflight(viewer,payload)
	if not problem.is_empty():status.text = problem;return
	last_recipe = {};temporal.revision += 1
	temporal._launch("save_recipe",{"recipe":recipe,"destination":destination,"quota_bytes":quota.text.to_int()*1048576 if output_quota < 0 else output_quota,"opened_paths":opened_paths.duplicate()},temporal.selections.source,{"cpu_seconds":cpu_limit.text.to_float(),"wall_seconds":wall_limit.text.to_float()})
	status.text = "Verifying state and streaming a new portable recipe bundle."

func choose_load() -> void:
	var dialog := FileDialog.new();dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE;dialog.access = FileDialog.ACCESS_FILESYSTEM;dialog.title = "Load G4 inspection or frame state";dialog.filters = PackedStringArray(["*.json ; G4 inspection or frame state"])
	dialog.use_native_dialog = true;dialog.mode_overrides_title = false
	add_child(dialog);dialog.file_selected.connect(func(path):load_from(path);dialog.queue_free());dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)

func load_from(path: String) -> void:
	if viewer.inspection_busy or not temporal.selections.source.has("sha256"):status.text = "Bind the opened source and finish any image capture before restore.";return
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 983040:status.text = "Missing or oversized recipe.";return
	var recipe = JSON.parse_string(file.get_as_text())
	if not recipe is Dictionary or recipe.get("version") != 3 or not recipe.get("payload") is Dictionary:status.text = "Choose a version 3 inspection bundle.";return
	var payload = State.unpack(recipe.payload)
	if not payload is Dictionary:status.text = "Malformed recipe payload.";return
	var problem := State.preflight(viewer,payload)
	if not problem.is_empty():status.text = problem;return
	last_recipe = {};temporal.revision += 1;pending_fingerprint = fingerprint()
	temporal._launch("load_recipe",{"path":path,"opened_paths":opened_paths.duplicate()},temporal.selections.source)
	status.text = "Validating the complete source, selection and asset state before restore."

func recompute() -> void:
	var index: int = temporal.result_list.selected
	if index < 0 or index >= temporal.summaries.size():status.text = "Choose a saved analysis request.";return
	var saved: Dictionary = temporal.summaries[index]
	temporal.submit(saved.operation,saved.request.duplicate(true),saved.source.duplicate(true),saved.label+" recomputed")

func capture_to(path: String, viewport_only: bool = false) -> Error:
	if not viewport_only: viewer.shell.dismiss_orbit_editor()
	if viewer.inspection_busy:return ERR_BUSY
	if temporal.jobs.is_spectral_operation(temporal.jobs.background_operation) and (temporal.jobs.background_pending or not temporal.jobs.background_cancel_id.is_empty()):status.text = "Finish or cancel the active spectral tool before capturing analysis state.";return ERR_BUSY
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):status.text = "Choose a new PNG filename.";return ERR_ALREADY_EXISTS
	var destination := path.get_basename()+".inspection"
	if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):status.text = "Choose a new PNG/bundle name.";return ERR_ALREADY_EXISTS
	if not temporal.selections.source.has("sha256"):status.text = "Bind the selection source before capturing state.";return ERR_UNAVAILABLE
	viewer.inspection_busy = true
	if viewer.scene_layers != null and not await viewer.scene_layers.wait_for_surface():viewer.inspection_busy = false;return ERR_CANT_CREATE
	var stable := false
	for attempt in range(8):
		if not await temporal.selections.await_committed_overlay():viewer.inspection_busy = false;status.text = "Exact selection overlay was unavailable; no PNG published.";return ERR_BUSY
		var before := fingerprint()
		await get_tree().process_frame
		# A paused low-processor viewer need not schedule another frame itself.
		RenderingServer.force_draw(false)
		if before == fingerprint():stable = true;break
	if not stable:viewer.inspection_busy = false;return ERR_BUSY
	var image: Image = viewer._save_image_viewport() if viewport_only else viewer.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():viewer.inspection_busy = false;return ERR_CANT_CREATE
	var recipe := State.snapshot(temporal,true);var payload: Dictionary = State.unpack(recipe.payload)
	payload.base.render = {"selection_frame":temporal.selections.frame_evidence(),"backend":RenderingServer.get_current_rendering_method(),"dimensions":[image.get_width(),image.get_height()]};recipe.payload = State.pack(payload)
	var staging := path+".partial-%d-%d.png" % [OS.get_process_id(),Time.get_ticks_usec()]
	var access := DirAccess.open(staging.get_base_dir())
	if access == null or FileAccess.file_exists(staging) or access.is_link(staging.get_file()):viewer.inspection_busy = false;return ERR_ALREADY_EXISTS
	var written: Error = image.save_png(staging)
	if written != OK:viewer.inspection_busy = false;return written
	last_recipe = {};temporal.revision += 1
	temporal._launch("save_recipe",{"recipe":recipe,"destination":destination,"quota_bytes":quota.text.to_int()*1048576,"opened_paths":opened_paths.duplicate(),"image":{"path":staging}},temporal.selections.source)
	var began := Time.get_ticks_msec()
	while temporal.jobs.busy() and Time.get_ticks_msec()-began < 150000:await get_tree().create_timer(.02).timeout
	if temporal.jobs.busy():temporal.jobs.cancel_background()
	viewer.inspection_busy = false
	if not last_recipe.get("image") is Dictionary:status.text = "PNG/state publication failed; staged image retained: "+staging;return ERR_CANT_CREATE
	if FileAccess.get_sha256(staging) != last_recipe.image.sha256:status.text = "Staged PNG changed; verified bundle retained: "+destination;return ERR_BUSY
	var published: Error = preload("res://video/render_job.gd").publish(staging,path)
	status.text = "Saved PNG and verified state bundle: "+destination if published == OK else "Verified image/state bundle retained; requested PNG filename could not be claimed: "+destination
	viewer.status_label.text = status.text
	return published

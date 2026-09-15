extends SceneTree
const Viewer = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []
var out := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)

func _initialize() -> void:call_deferred("run")

func wait_worker(control) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 20000:
		await create_timer(.02).timeout
		if not control.jobs.busy():return control.jobs.error.is_empty()
	return false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--diagnostics-fixture="):out = arg.trim_prefix("--diagnostics-fixture=")
	if out.is_empty():quit(1);return
	var viewer := Viewer.new();viewer.offline_instance = true;root.add_child(viewer);await process_frame
	viewer._open_capture(out.path_join("run-a.ssc"));viewer.playing = false;viewer.orbit_enabled = false
	var control = viewer.selection_controller;var temporal = control.temporal;var diagnostics = temporal.diagnostics
	control.bind_source();check(await wait_worker(control),"first run bound")
	diagnostics.csv_path.text = out.path_join("a.csv");diagnostics.csv_units.text = "s";diagnostics.csv_value_units.text = "K";diagnostics.import_csv()
	check(await wait_worker(control),"CSV imported and native preview ready")
	check(temporal.summaries.size()==1 and int(temporal.plot.data.get("count",0))==4,"four CSV observations on independent clock")
	if temporal.plot.data.is_empty():viewer.queue_free();await process_frame;quit(1);return
	check(temporal.plot.data.x_range==["0","3"],"irregular diagnostic times preserved")
	diagnostics.time_units.text = "s";diagnostics.value_units.text = "K";diagnostics.time_reference.text = "manual experiment start";diagnostics.value_reference.text = "declared temperature correspondence"
	diagnostics.bind_side("left");diagnostics.label_input.text = "Run A supplied temperature";diagnostics.add_series()
	check(await wait_worker(control),"first linked series ready")
	viewer._seek_time(.125);await process_frame;await process_frame;diagnostics.bookmark()
	check(diagnostics.bookmarks.size()==1,"manual bookmark saved without event inference")
	var token: Dictionary = diagnostics.bookmarks[0].raw_time
	check(PackedFloat64Array([float(token.text)]).to_byte_array().hex_encode()==token.f64_le_hex,"bookmark decimal and binary time agree")
	var previous_source: Dictionary = control.source.duplicate(true)
	viewer._open_capture(out.path_join("run-b.ssc"));viewer.playing = false;control.bind_source();check(await wait_worker(control),"second run bound after source switch")
	check(temporal.summaries.size()==1 and temporal.summaries[0].source==previous_source,"historical result retains first run identity")
	diagnostics.csv_path.text = out.path_join("b.csv");diagnostics.import_csv();check(await wait_worker(control),"second run CSV imported")
	diagnostics.time_offset.text = "10";diagnostics.offset_origin.text = "manual second-run start";diagnostics.bind_side("right")
	check(diagnostics.left.source.uuid != diagnostics.right.source.uuid,"same object IDs across runs have separate source bindings")
	diagnostics.label_input.text = "Run B supplied temperature";diagnostics.add_series();check(await wait_worker(control),"two-run overlay ready")
	check(diagnostics.overlay.plots.size()==2,"distinct native series share explicit mapped axes")
	if diagnostics.overlay.plots.size()==2:
		check(diagnostics.overlay.plots[0].clock != diagnostics.overlay.plots[1].clock,"overlay preserves both clock identities")
		check(float(diagnostics.overlay.plots[1].x_range[0])==0 and float(diagnostics.overlay.plots[1].x_range[1])==3,"manual offset aligns display only")
	diagnostics.compare();check(await wait_worker(control),"explicit difference result ready")
	check(temporal.plot.data.y_range==["1","4"],"comparison difference matches hand oracle")
	temporal.page_offset = 0;temporal.request_page();check(await wait_worker(control),"comparison full numerical rows available")
	if DisplayServer.get_name() != "headless":
		diagnostics.panel.visible = true;temporal.panel.visible = false;control.panel.visible = false
		var scroll: ScrollContainer = viewer.inspector_box.get_parent()
		await process_frame;await process_frame
		scroll.scroll_vertical = maxi(0,int(diagnostics.overlay.global_position.y)-60+scroll.scroll_vertical)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image();check(not image.is_empty(),"actual renderer produces linked diagnostic image");image.save_png(out.path_join("diagnostics.png"))
	diagnostics.csv_path.text = out.path_join("period.csv");diagnostics.import_csv();check(await wait_worker(control),"steady-signal diagnostic imported")
	temporal.start_time.text = "0";temporal.end_time.text = "6";diagnostics.lag_low.text = "0.5";diagnostics.lag_high.text = "1.5";diagnostics.separation.text = "0.5";diagnostics.prominence.text = "0.5";diagnostics.estimate_period()
	check(await wait_worker(control),"exploratory full-input/window period result ready")
	check(temporal.summaries[-1].operation=="estimate_period","period evidence is a separately named result")
	check(temporal.plot.data.y_range != null and abs(float(temporal.plot.data.y_range[0])-1)<1e-12,"steady signal period matches analytic one-second oracle")
	var pid: int = control.jobs.worker_pid
	viewer.queue_free();await process_frame;await create_timer(.1).timeout;check(not DirAccess.dir_exists_absolute("/proc/%d" % pid),"source-switch worker and final worker reaped")
	var report := {"checks":checks,"failures":failures,"backend":RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(out.path_join("diagnostics.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t",true,true));file.close()
	print("G4 DIAGNOSTICS: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

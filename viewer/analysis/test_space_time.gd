extends SceneTree
const Viewer = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []
var out := ""

func check(ok: bool,label: String) -> void:
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
		if arg.begins_with("--space-time-fixture="):out = arg.trim_prefix("--space-time-fixture=")
	if out.is_empty():quit(1);return
	var viewer := Viewer.new();viewer.offline_instance = true;root.add_child(viewer);await process_frame
	viewer._open_capture(out.path_join("pulse.ssc"));viewer.playing = false;viewer.orbit_enabled = false
	var control = viewer.selection_controller;var temporal = control.temporal;var spatial = temporal.space_time
	control.bind_source();check(await wait_worker(control),"pulse capture bound asynchronously")
	control.target.select(1);temporal.start_time.text = "0";temporal.end_time.text = "4";temporal.max_gap.text = "1"
	spatial.start.text = "-0.125,0,0";spatial.end.text = "5.125,0,0";spatial.bins.text = "21";spatial.units.text = "m";spatial.space.select(1)
	spatial.run_analysis();check(await wait_worker(control),"native field line job and heatmap ready")
	check(not spatial.plot.data.is_empty(),"heatmap published after source job")
	if spatial.plot.data.is_empty():push_error(temporal.status.text);viewer.queue_free();await process_frame;quit(1);return
	check(spatial.plot.data.native_rows.size()==5,"five source field times; no union-clock repetitions")
	check(spatial.plot.data.native_rows.map(func(r):return r.first_time)==["0","0.25","1","2.5","4"],"nonuniform raw times preserved")
	check(spatial.plot.data.native_rows.map(func(r):return int(r.row))==[0,4,16,40,63],"physical spacing preserves time gaps")
	check(int(spatial.plot.data.full_bin_values)==105,"full 21 bins by five native times retained")
	var raw: PackedByteArray = spatial.plot.pixels
	for pair in [[0,0],[4,1],[16,4],[40,10],[63,16]]:
		var best := -1.0;var peak := -1
		for x in range(21):
			var value := raw.decode_float((int(pair[0])*21+x)*16+4)
			if value > best:best = value;peak = x
		check(peak==int(pair[1]),"traveling pulse follows analytic path at native row %d" % pair[0])
	check(raw.decode_u32((10*21)*16+8)==0,"unobserved time row is empty")
	var mixed: Dictionary = spatial.plot.data.duplicate(true);var cells: PackedByteArray = spatial.plot.pixels.duplicate()
	cells.encode_u32(8,1);cells.encode_u32(12,1);mixed.pixels = cells.hex_encode()
	var temporary := preload("res://analysis/space_time_plot.gd").new()
	check(temporary.publish(mixed),"mixed finite/missing support preview accepted")
	check(temporary.texture.get_image().get_pixel(0,0).is_equal_approx(Color(1,.2509804,.6509804,1)),"mixed support has a visible pink warning color")
	temporary.free()
	temporal.page_offset = 0;temporal.request_page();check(await wait_worker(control),"full spatial bins page asynchronously")
	check("bin:20" in temporal.table.text,"source bin addresses in full table")
	if DisplayServer.get_name() != "headless":
		spatial.panel.visible = true;temporal.panel.visible = false;control.panel.visible = false
		viewer.shell.refresh_export()
		var scroll: ScrollContainer = viewer.shell.scroll
		await process_frame;await process_frame
		scroll.scroll_vertical = maxi(0,int(spatial.plot.global_position.y)-70+scroll.scroll_vertical)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image();check(not image.is_empty(),"actual renderer produces source heatmap");image.save_png(out.path_join("space-time.png"))
	control.target.select(0);spatial.mode.select(3);spatial.start.text = "0,0,0";spatial.end.text = "5,0,0";spatial.bins.text = "10";spatial.run_analysis()
	check(await wait_worker(control),"tracer histogram ready")
	check("tracer samples/estimate" in spatial.plot.data.value_origin,"tracer plot distinguished from direct field density")
	check(spatial.plot.data.native_rows.size()==4,"tracer histogram retains its own four native records")
	spatial.mode.select(5);temporal.weight_channel.text = "weight";temporal.weight_units.text = "1";spatial.sampling_population.text = "Each synthetic tracer represents two source population members";spatial.run_analysis()
	check(await wait_worker(control),"explicitly declared tracer sampling-weight job ready")
	check(temporal.summaries[-1].request.weight.override.quantity=="sampling_weight","sampling interpretation retained in request provenance")
	temporal.durable.export_to(out.path_join("analysis-export"))
	check(await wait_worker(control),"full numerical export completes through private worker")
	check(int(temporal.durable.last_export.get("row_count",0))==40,"export includes all requested tracer bins and native records")
	check(FileAccess.file_exists(out.path_join("analysis-export/values.csv")) and FileAccess.file_exists(out.path_join("analysis-export/analysis.json")),"portable numerical CSV and manifest published together")
	control._request("define_selection",{"key":"saved-cohort","object":"p","kind":"particle_ids","selector":{"ids":["0","1"]}})
	check(await wait_worker(control),"recipe cohort defined from exact IDs")
	control.state.group("Saved cohort group",[control.state.active]);temporal.diagnostics.bookmark()
	var saved_time: float = control._time();var saved_definitions: Array = control.state.definitions.duplicate(true)
	preload("res://video/render_job.gd").write_json(out.path_join("recipe-draft.json"),preload("res://analysis/inspection_v3.gd").snapshot(temporal,true))
	temporal.durable.save_to(out.path_join("recipe.inspection"))
	check(await wait_worker(control),"v3 recipe save validates complete state off the UI thread")
	check(temporal.durable.last_recipe.has("path"),"portable recipe published after final source verification")
	if not temporal.durable.last_recipe.has("path"):push_error(temporal.status.text+" / "+temporal.durable.status.text)
	control.state.remove("saved-cohort");control._changed();viewer._seek_time(1.5)
	temporal.durable.load_from(out.path_join("recipe.inspection/inspection.json"))
	check(await wait_worker(control),"v3 recipe restore worker validation completes")
	check(temporal.durable.last_recipe.get("restored",false),"validated v3 state atomically applied")
	if not temporal.durable.last_recipe.get("restored",false):push_error(temporal.status.text+" / "+temporal.durable.status.text)
	check(control.state.definitions==saved_definitions and control.state.groups.size()==1,"selection definitions and group revisions restored")
	check(control._time()==saved_time and not viewer.playing,"exact saved cursor restored with playback paused")
	check(temporal.summaries.size()==3 and temporal.diagnostics.bookmarks.size()==1,"analysis requests and manual bookmark restored")
	var unchanged := JSON.stringify([preload("res://scene/visual_state.gd").snapshot(viewer),control.state.snapshot(),viewer.committed_sample],"",true,true)
	var malformed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("recipe.inspection/inspection.json")))
	malformed.unsupported = true
	DirAccess.make_dir_recursive_absolute(out.path_join("bad.inspection"));preload("res://video/render_job.gd").write_json(out.path_join("bad.inspection/inspection.json"),malformed)
	temporal.durable.load_from(out.path_join("bad.inspection/inspection.json"));await wait_worker(control)
	check(not temporal.durable.last_recipe.get("restored",false),"unsupported v3 field refused")
	check(unchanged==JSON.stringify([preload("res://scene/visual_state.gd").snapshot(viewer),control.state.snapshot(),viewer.committed_sample],"",true,true),"failed v3 restore leaves visual sample and selection state unchanged")
	var pid: int = control.jobs.worker_pid
	viewer.queue_free();await process_frame;await create_timer(.1).timeout;check(not DirAccess.dir_exists_absolute("/proc/%d" % pid),"spatial worker reaped on close")
	var report := {"checks":checks,"failures":failures,"backend":RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(out.path_join("space-time.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t",true,true));file.close()
	print("G4 SPACE TIME: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

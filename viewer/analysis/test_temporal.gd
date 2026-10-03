extends SceneTree
const Viewer = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []
var out := ""

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)

func _initialize() -> void:call_deferred("run")

func wait_selection(control) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 10000:
		await create_timer(.02).timeout
		if not control.jobs.pending and control.operation.is_empty():return control.jobs.error.is_empty()
	return false

func wait_plot(control) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 15000:
		await create_timer(.02).timeout
		if not control.temporal.plot.data.is_empty() and not control.jobs.background_pending:return true
	return false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--temporal-fixture="):out = arg.trim_prefix("--temporal-fixture=")
	if out.is_empty():quit(1);return
	var viewer := Viewer.new();viewer.offline_instance = true;root.add_child(viewer);await process_frame
	viewer._open_capture(out.path_join("fixture.wvz"));viewer.playing = false;viewer.orbit_enabled = false
	var control = viewer.selection_controller;var temporal = control.temporal
	check(control.jobs.worker_pid < 0,"G4-idle starts no worker")
	control.bind_source();check(await wait_selection(control),"source bound asynchronously")
	control.kind.select(0);control.members_input.text = "7,9007199254740993";control.create_definition()
	check(await wait_selection(control),"source cohort created")
	temporal.full_range();check(temporal.end_time.text == "3","analysis full range uses particle native endpoint")
	temporal.run_analysis();check(control.jobs.background_pending,"fixed job starts on independent lane")
	check(await wait_plot(control),"native trace reaches bounded plot")
	if temporal.plot.data.is_empty():
		push_error(temporal.status.text);viewer.queue_free();await process_frame;quit(1);return
	check(temporal.summaries.size()==1 and int(temporal.summaries[0].rows)==8,"full trace contains 2 members by 4 native observations")
	check(int(temporal.plot.data.count)==4,"plot does not count union-clock held repeats")
	check(int(temporal.plot.data.missing)==2,"death produces missing plot observations")
	check(temporal.series_list.item_count==2,"exact members remain separate series")
	temporal.page_offset = 0;temporal.request_page();check(await wait_selection(control),"full result page reads asynchronously")
	check("9007199254740993" in temporal.table.text,"full table preserves exact ID")
	check("absent_at_sample" in temporal.table.text,"full table displays explicit missing reason")
	viewer.scene_layers.sample(.75);await process_frame;await process_frame
	check(int(temporal.plot.data.count)==4,"scrubbing only moves cursor; scientific observations unchanged")
	# Start another fixed job, then edit selection state before it publishes.
	temporal.run_analysis();control.state.rename_active("changed after launch");control._changed()
	var start := Time.get_ticks_msec()
	while temporal.summaries.size()<2 and Time.get_ticks_msec()-start<10000:await create_timer(.02).timeout
	check(temporal.summaries.size()==2,"fixed interval finishes as named result despite newer selection")
	check(temporal.plot.data.is_empty(),"late interval cannot replace newer selection's active plot")
	temporal._select_result(1);check(await wait_plot(control),"historical named result requires explicit inspection")
	# Source grid selection has an independent native axis and direct quadrature.
	control.target.select(1);control.kind.select(8);control.first_input.text = "-100,-100,-100";control.second_input.text = "100,100,100";control.create_definition()
	check(await wait_selection(control),"source geometric ROI created")
	temporal.mode.select(3);temporal.channel.text = "constant";temporal.full_range();temporal.run_analysis()
	check(await wait_plot(control),"direct-grid integral reaches native plot")
	check(temporal.plot.data.y_range==["72","72"],"node integral matches independent full-cell oracle")
	check(int(temporal.plot.data.count)==3 and temporal.plot.data.x_range==["0","4"],"field plot uses its three native samples")
	temporal.page_offset = 0;temporal.request_page();check(await wait_selection(control),"integral source rows inspectable")
	var report := {"checks":checks,"failures":failures,"backend":RenderingServer.get_current_rendering_method(),"native_rows":temporal.plot.data.count,"integral_range":temporal.plot.data.y_range,"named_results":temporal.summaries.size()}
	if DisplayServer.get_name() != "headless":
		temporal.panel.visible = true;control.panel.visible = false
		viewer.shell.refresh_export()
		var scroll: ScrollContainer = viewer.shell.scroll
		await process_frame;await process_frame
		scroll.scroll_vertical = maxi(0,int(temporal.plot.global_position.y)-80+scroll.scroll_vertical)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(not image.is_empty(),"actual renderer produces temporal inspector image")
		image.save_png(out.path_join("temporal.png"))
	var pid: int = control.jobs.worker_pid
	viewer.queue_free();await process_frame;await create_timer(.1).timeout
	check(not DirAccess.dir_exists_absolute("/proc/%d" % pid),"close reaps analysis worker")
	report.checks = checks;report.failures = failures
	var file := FileAccess.open(out.path_join("temporal.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t",true,true));file.close()
	print("G4 TEMPORAL: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

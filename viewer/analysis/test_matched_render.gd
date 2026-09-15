extends SceneTree
const Viewer = preload("res://main.gd")
var folder := ""
var render_pair := false
func _initialize() -> void:run.call_deferred()
func wait_jobs(control) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 30000:
		await create_timer(.01).timeout
		if not control.jobs.busy():return control.jobs.error.is_empty()
	return false
func fail(message: String) -> void:push_error(message);quit(1)
func run() -> void:
	create_timer(150).timeout.connect(func():fail("Matched test timed out"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matched-fixture="):folder = arg.trim_prefix("--matched-fixture=")
		if arg == "--render-pair":render_pair = true
	if folder.is_empty():fail("Missing fixture");return
	var viewer := Viewer.new();viewer.offline_instance = true;root.add_child(viewer);await process_frame
	viewer._open_capture(folder.path_join("left-input/pulse.ssc"));viewer.playing = false;viewer.orbit_enabled = false
	var control = viewer.selection_controller;control.bind_source()
	if not await wait_jobs(control):fail(control.status.text);return
	var temporal = control.temporal
	temporal.durable.load_from(folder.path_join("left-input/recipe.inspection/inspection.json"))
	if not await wait_jobs(control) or not temporal.durable.last_recipe.get("restored",false):fail(temporal.durable.status.text);return
	temporal.durable.remember_path(folder.path_join("right-input/pulse.ssc"))
	var matched = temporal.matched
	for n in range(2):
		var side: Dictionary = matched.sides[n]
		if not matched.select_recipe(side,folder.path_join(("left-input" if n==0 else "right-input")+"/recipe.inspection/inspection.json")):fail(matched.status.text);return
		side.keys.text = "endpoints";side.object.text = "p";side.channel.text = "value"
	matched.sides[1].time_scale.text = "0.5";matched.sides[1].time_offset.text = "5"
	matched.common.coordinate_reference.text = "same Cartesian origin and axes"
	matched.common.end_time.text = "0.75";matched.common.fps.text = "4";matched.common.quota_bytes.text = "256"
	matched.prepare_to(folder.path_join("pair"))
	if not await wait_jobs(control) or matched.prepared.is_empty():fail(matched.status.text+" / "+temporal.status.text);return
	if preload("res://video/render_job.gd").write_json(folder.path_join("prepared.json"),matched.prepared) != OK:fail("Could not write prepared test record");return
	if render_pair:
		matched.start_pair()
		while matched.pid > 0:await create_timer(.05).timeout
		if matched.index != 2:fail(matched.status.text);return
	viewer.queue_free();await process_frame;quit()

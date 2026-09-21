extends SceneTree
## Final UX3 workflow/profile probe. Reports measurements, not universal budgets.
const Visual = preload("res://scene/visual_state.gd")
const Profile = preload("res://scene/playback_profile.gd")
const Job = preload("res://video/render_job.gd")

class ObservedViewer extends "res://main.gd":
	var measuring := false
	var callbacks: Array = []
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super(delta)
		if measuring: callbacks.append((Time.get_ticks_usec()-started)/1000.0)

var checks := 0
var failures: Array[String] = []
var output := ""
var view
var measurements: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
func ready() -> void:
	var deadline := Time.get_ticks_msec()+30000
	while view.scene_layers.is_buffering() and Time.get_ticks_msec()<deadline:
		view.scene_layers.tick(0); await process_frame
	check(not view.scene_layers.is_buffering(), "Published preparation completes")
	view.shell.transport.refresh()
func science() -> Dictionary:
	var state := Visual.snapshot(view)
	for key in ["panel_width", "overlay_visible"]: state.erase(key)
	return state
func memory() -> Dictionary:
	var rss := 0
	var file := FileAccess.open("/proc/self/status", FileAccess.READ)
	if file != null:
		for line in file.get_buffer(65536).get_string_from_utf8().split("\n"):
			if line.begins_with("VmRSS:"): rss = int(line.substr(6).strip_edges().split(" ", false)[0])*1024
	return {"rss_bytes":rss, "godot_static_bytes":OS.get_static_memory_usage(),
		"gpu_buffer_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		"gpu_texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)}
func stats(values: Array) -> Dictionary:
	var sorted := values.duplicate(); sorted.sort()
	if sorted.is_empty(): return {}
	var total := 0.0
	for value in sorted: total += value
	return {"count":sorted.size(), "mean_ms":total/sorted.size(), "p95_ms":sorted[ceili(sorted.size()*.95)-1], "max_ms":sorted[-1]}
func measure(name: String, playing: bool, dock: bool, target: float) -> void:
	view.playing = false
	view._seek_time(target); await ready()
	if view.overlay_visible != dock: view.shell.toggle_dock()
	# Replay intentionally pauses inspection. Resume through the real transport,
	# rather than setting `playing` while leaving its inspection guard active.
	view.play_button.pressed.emit()
	if not playing: view.play_button.pressed.emit()
	await settle()
	var start_memory := memory()
	var start_count: int = view.shell.status_ui.refresh_count
	var frames: Array = []
	view.callbacks.clear(); Profile.reset(); Profile.enabled = true
	view.measuring = true; view.set_process(true)
	var start := Time.get_ticks_usec(); var last := start
	while Time.get_ticks_usec()-start < 2000000:
		await process_frame
		var now := Time.get_ticks_usec(); frames.append((now-last)/1000.0); last = now
	view.measuring = false; view.set_process(false)
	if view.playing: view.play_button.pressed.emit()
	var activity := Profile.report(); Profile.enabled = false
	var seconds := (Time.get_ticks_usec()-start)/1000000.0
	var refreshes: int = view.shell.status_ui.refresh_count-start_count
	check(refreshes <= ceili(seconds*5)+1, name+": status observes at most 5 Hz")
	check(view.scene_layers.error.is_empty(), name+": no scene error")
	if playing: check(float(view.committed_sample.requested_time) > target, name+": recorded playback advances")
	else: check(view.committed_sample.requested_time == target, name+": idle does not seek")
	measurements.append({"case":name,"seconds":seconds,"source_start":target,"source_end":view.committed_sample.requested_time,
		"callbacks":stats(view.callbacks),"frame_intervals":stats(frames),"status_refreshes":refreshes,
		"memory_before":start_memory,"memory_after":memory(),"activity":activity})

func run() -> void:
	var source := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--integration-output="): output = arg.trim_prefix("--integration-output=")
		if arg.begins_with("--integration-source="): source = arg.trim_prefix("--integration-source=")
	if source.is_empty() or output.is_empty(): quit(1); return
	view = ObservedViewer.new(); view.playing = false; view.orbit_enabled = false
	root.add_child(view); view.set_process(false)
	view._open_capture(source); view.playing = false
	check(view.generic_reader != null, "Source opens in production shell")
	if view.generic_reader == null: view.free(); quit(1); return
	# Bound the optional real-capture probe using an existing user-selectable policy.
	view.scene_layers.playback.set_policy("512")
	await ready(); await settle()
	var first: float = view.generic_reader.frames[0].time
	var last: float = view.generic_reader.frames[-1].time
	var target: float = first+(last-first)*.25
	var seeks := []
	for i in 2:
		var started := Time.get_ticks_usec()
		check(view._seek_time(target), "Seek accepted")
		var submit_ms := (Time.get_ticks_usec()-started)/1000.0
		await ready()
		seeks.append({"pass":i,"submit_ms":submit_ms,"ready_ms":(Time.get_ticks_usec()-started)/1000.0})
		check(view.committed_sample.requested_time == target, "Seek commits exact requested target")
	for speed in [.5,1.0,2.0,-.5]:
		view._seek_time(target); await ready()
		view.physical_rate = speed; view.playing = true; view.scene_layers.tick(.1)
		await ready(); view.playing = false
		check(is_equal_approx(view.committed_sample.requested_time,target+.1*speed), "Canonical recorded-time speed "+str(speed))
	view.physical_rate = 1.0; view._seek_time(target); await ready()
	var layers = view.scene_layers
	check(not layers.selected_volume.is_empty(), "Combined capture exposes a source probe")
	var grid = layers.views[layers.selected_volume]
	var point: Vector3 = grid.world_to_grid.affine_inverse()*((grid.bounds_min+grid.bounds_max)*.5)
	for i in 3: layers.probe_spins[i].value = point[i]
	layers.probe_selected_volume()
	check(layers.probe_marker_valid and layers.probe_label.text != "Unavailable", "Source probe returns a supported value")
	var probe: String = layers.probe_label.text
	var before := science(); var sample: Dictionary = view.committed_sample.duplicate(true)
	Profile.reset(); Profile.enabled = true
	var started := Time.get_ticks_usec()
	for i in 100:
		view.shell.select_workspace(i%4); view.shell.layout()
		view.shell.transport.refresh(); view.shell.status_ui.refresh()
	var refresh_ms := (Time.get_ticks_usec()-started)/1000.0
	var refresh_activity := Profile.report(); Profile.enabled = false
	check(refresh_activity.stages.is_empty() and refresh_activity.counters.is_empty(), "Workspace/layout/status/transport refresh performs no instrumented scientific work")
	check(science() == before and view.committed_sample == sample, "Workspace churn preserves camera, volume mappings, layer visibility and sample")
	check(layers.probe_label.text == probe and layers.probe_marker_valid, "Workspace churn preserves the explicit probe result")
	view.shell.select_workspace(0); await settle()
	var node_count := get_node_count(); var stable_memory := memory()
	for cycle in 5:
		for i in 20: view.shell.select_workspace(i%4)
		view.shell.select_workspace(0); await settle()
	check(get_node_count() == node_count, "Settled workspace switching does not retain duplicate nodes")
	var churn_memory := memory()
	check(view._save_inspection(output.path_join("scene.json")) == OK, "Current scene recipe saves")
	check(view._load_inspection(output.path_join("scene.json")).is_empty(), "Current scene recipe restores")
	await ready(); await settle()
	check(science() == before and layers.probe_label.text == probe, "Recipe restore keeps scientific state and session probe")
	for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
		root.size = dimensions; await settle(); view.shell.layout(); await settle()
		check(view.shell.transport.is_visible_in_tree() and view.shell.status_ui.is_visible_in_tree(), "Persistent controls visible at "+str(dimensions))
		root.get_texture().get_image().save_png(output.path_join("workflow-"+str(dimensions.x)+".png"))
	root.size = Vector2i(1440,900); await settle()
	check(await view._capture_inspection_png(output.path_join("workflow.png"),false) == OK, "Current viewport PNG succeeds")
	# Equivalent source, rate, visible layers and window; only dock visibility varies.
	for pair in [["idle-dock",false,true],["idle-hidden",false,false],["play-dock",true,true],["play-hidden",true,false],["idle-repeat",false,true]]:
		await measure(pair[0],pair[1],pair[2],target)
	var backend := RenderingServer.get_current_rendering_method()
	view.free(); await settle()
	view = ObservedViewer.new(); view.scene_prebuffer_enabled = false; view.playing = false; view.orbit_enabled = false
	root.add_child(view); view.set_process(false); view._open_capture(source); view.playing = false; await settle()
	check(view.generic_reader != null and view.shell.bar.visible and view.shell.transport.is_visible_in_tree(), "Fresh viewer after normal shutdown opens source and recovers shell")
	check(view.shell.status_ui.failures.is_empty() and not view.video_dialog.visible, "Fresh session has no stale failures or job dialog")
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"backend":backend,
		"source":source,"seeks":seeks,"refresh_100_ms":refresh_ms,"refresh_activity":refresh_activity,
		"workspace_memory_before":stable_memory,"workspace_memory_after":churn_memory,"measurements":measurements})
	view.free(); await process_frame
	print("UX3 INTEGRATION: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

extends SceneTree
# Exercise the actual Range control and live layer refresh, not a mock sampler.
var checks: Array = []
var states: Array = []
var out := ""
var config: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, name: String) -> void:
	checks.append({"name":name,"ok":ok})
	print("PASS " if ok else "FAIL ",name)
func write_prefix(path: String, end: int, append: bool) -> void:
	var src := FileAccess.open(config.complete,FileAccess.READ)
	var dst := FileAccess.open(path,FileAccess.READ_WRITE if append else FileAccess.WRITE)
	var start := dst.get_length() if append else 0
	dst.seek(start);src.seek(start)
	while start < end:
		var block := src.get_buffer(mini(8*1048576,end-start));dst.store_buffer(block);start += block.size()
	dst.flush();dst.close()
func record(viewer, label: String) -> void:
	states.append({"label":label,"requested_time":viewer.requested_time,"committed_time":viewer.committed_sample.get("requested_time"),"frame_count":viewer.frame_count,"current_index":viewer.current_index,"slider_max":viewer.timeline.max_value,"slider_value":viewer.timeline.value,"slider_ratio":viewer.timeline.ratio,"layers":viewer.scene_layers.layer_samples.duplicate(true)})
func settle(viewer) -> void:
	var start := Time.get_ticks_msec()
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec()-start<10000:
		viewer.scene_layers.tick(0);await process_frame
func held_time(times: Array, time: float) -> float:
	var held: float = times[0]
	for t in times:
		if t <= time:held = t
	return held
func check_sample(viewer, time: float) -> void:
	check(is_equal_approx(viewer.committed_sample.requested_time,time),"physical time remains requested time")
	for layer in viewer.scene_layers.layer_samples:
		if layer.id == config.volume:
			check(is_equal_approx(layer.source_time,held_time(config.volume_times,time)),"volume holds its own source time")
		if layer.id == config.particle:
			check(is_equal_approx(layer.scalar_time,held_time(config.particle_times,time)),"particle scalars hold their own source time")
	if config.analytic:
		check(is_equal_approx(viewer.current_mm.get_instance_transform(0).origin.x,time),"ID-matched particle position interpolation unchanged")
func run() -> void:
	if DisplayServer.get_name() == "headless":push_error("Requires rendered UI");quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--timeline-fixture="):out = arg.trim_prefix("--timeline-fixture=")
	config = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
	var live := out.path_join("live.wvz")
	write_prefix(live,int(config.initial_end),false)
	var viewer = load("res://main.gd").new();viewer.capture_path = live;viewer.playing = false;viewer.orbit_enabled = false
	root.add_child(viewer);viewer.set_process(false)
	viewer.set_process_unhandled_input(false)
	check(viewer.scene_layers != null and viewer.frame_a != null,"open committed layered prefix")
	var initial_count: int = viewer.frame_count
	check(initial_count == 2 and viewer.timeline.max_value == 1,"initial union clock and slider agree")
	# Incomplete append must not add an uncommitted timestamp to the slider.
	write_prefix(live,int(config.initial_end)+40,true)
	viewer.scene_layers.sample(.25)
	check(viewer.frame_count == initial_count and viewer.timeline.max_value == initial_count-1,"incomplete record leaves clock and slider extent unchanged")
	var full := FileAccess.open(config.complete,FileAccess.READ)
	write_prefix(live,full.get_length(),true);full.close()
	# Exercise the layer refresh path used by native playback.
	var point: Dictionary = viewer.scene_layers.sample(config.requested)
	check(not point.is_empty(),"sample after committed append")
	check(viewer.frame_count == config.times.size(),"union includes independent particle and volume times")
	check(viewer.timeline.max_value == config.times.size()-1,"slider range grows with committed union clock")
	check(viewer.timeline.value == viewer.current_index and viewer.timeline.ratio < 1,"mid-capture slider is not pegged at 100 percent")
	check_sample(viewer,config.requested);record(viewer,"after append")
	# Render the actual playback panel, including the native slider thumb.
	var control: Node = viewer.timeline
	while control != null and not control is ScrollContainer:control = control.get_parent()
	for i in range(4):await process_frame
	if control is ScrollContainer:control.ensure_control_visible(viewer.timeline)
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("timeline.png"))
	viewer.playing = true;viewer.physical_rate = 1;viewer.scene_layers.tick(.1)
	check_sample(viewer,config.requested+.1)
	check(viewer.timeline.value == viewer.current_index,"playing updates thumb in union-index space")
	viewer.playing = false;viewer.scene_layers.tick(.1)
	check(is_equal_approx(viewer.requested_time,config.requested+.1),"pause leaves physical time unchanged")
	# Native value_changed signal must seek the union timestamp, not a layer index.
	viewer.timeline.value = 2
	await settle(viewer)
	check(is_equal_approx(viewer.requested_time,config.times[2]),"slider seek uses union timestamps")
	check(viewer._seek_time(config.requested),"fractional physical-time seek succeeds")
	await settle(viewer)
	check_sample(viewer,config.requested)
	check(viewer.timeline.value == viewer.current_index,"physical-time seek restores correct thumb")
	viewer.timeline.value = 0;await settle(viewer);viewer._step_frame(1);await settle(viewer)
	check(viewer.current_index == 1 and is_equal_approx(viewer.requested_time,config.times[1]),"union-index navigation and next-step semantics unchanged")
	viewer._seek_frame(config.times.size()-1)
	await settle(viewer)
	check(viewer.timeline.ratio == 1 and viewer.current_index == config.times.size()-1,"100 percent only at last union timestamp")
	# Shrinking the source updates the range without a recursive slider seek.
	write_prefix(live,int(config.initial_end),false)
	viewer.scene_layers.sample(.25)
	check(viewer.frame_count == 2 and viewer.timeline.max_value == 1,"truncation shrinks slider extent")
	check(is_equal_approx(viewer.requested_time,.25) and not viewer._timeline_guard,"range clamp preserves requested time and releases guard")
	record(viewer,"after truncation")
	var failures := 0
	for c in checks:
		if not c.ok:failures += 1
	preload("res://video/render_job.gd").write_json(out.path_join("results.json"),{"checks":checks,"failures":failures,"states":states,"source":config.source})
	viewer.free();await process_frame
	print("G3 TIMELINE: ",checks.size()," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

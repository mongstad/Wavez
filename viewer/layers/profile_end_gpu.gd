extends SceneTree
## Observe the real interactive process and draw callbacks across recorded end.
const Profile = preload("res://scene/playback_profile.gd")
const Memory = preload("res://layers/playback_memory.gd")
const Hash = preload("res://data/capture_index.gd")
var view
var output: FileAccess
var phase := "open"
var next_log := 0
var last_draw := 0
var last_wall := 0
var render_gpu: Array = []
var render_cpu: Array = []
func _initialize() -> void:run.call_deferred()
func draw_observed() -> void:
	render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
func distribution(values: Array) -> Dictionary:
	if values.is_empty():return {}
	values.sort();var total := 0.
	for x in values:total += x
	return {"count":values.size(),"mean_ms":total/values.size(),"p95_ms":values[mini(values.size()-1,ceili(values.size()*.95)-1)],"max_ms":values[-1]}
func snapshot() -> Dictionary:
	var now := Time.get_ticks_msec();var draws := Engine.get_frames_drawn()
	var row := {"event":"sample","phase":phase,"wall":now/1000.,"draws":draws,"draw_fps":(draws-last_draw)*1000./maxi(1,now-last_wall),"callbacks":Engine.get_process_frames(),"playing":view.playing,"time":view.requested_time,"committed":view.committed_sample.get("requested_time"),"low_processor":OS.low_processor_usage_mode,"max_fps":Engine.max_fps,"orbit":view.orbit_enabled,"camera":str(view.camera.transform),"memory":Memory.snapshot(),"gpu_render":distribution(render_gpu),"cpu_render":distribution(render_cpu),"texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"buffer_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)}
	if view.scene_layers != null:
		var layers = view.scene_layers;var ps: Dictionary = layers.playback.worker.status();var fs: Dictionary = layers.field_playback.worker.status()
		view.timeline.refresh(view)
		row.merge({"reason":layers.transport_wait_reason,"error":layers.error,"coverage":view.timeline.coverage.duplicate(true),"particle":{"completed":ps.completed,"evictions":ps.prepared_evictions,"misses":ps.prepared_misses,"resident":ps.prepared_pairs,"desired":ps.desired.size(),"active":ps.worker_active,"decoded_bytes":ps.decoded_bytes,"prepared_bytes":ps.prepared_bytes,"failures":ps.failures,"decoded_limit":layers.playback.decoded_limit,"prepared_limit":layers.playback.prepared_limit},"field":{"completed":fs.completed,"bytes":fs.bytes,"limit":fs.limit,"active_jobs":fs.active_jobs,"staged":layers.field_playback.staged.size(),"uploads":layers.field_playback.uploads,"session":fs.session},"particle_mm_bytes_sha256":Hash.digest(view.current_mm.buffer.to_byte_array())})
	last_draw = draws;last_wall = now;render_gpu = [];render_cpu = []
	return row
func log_sample() -> void:
	var row := snapshot();output.store_line(JSON.stringify(row));output.flush()
	print("GPU sample ",phase," time=",row.time," playing=",row.playing," draws/s=",row.draw_fps)
func change_phase(name: String) -> void:
	phase = name;next_log = 0;render_gpu = [];render_cpu = [];last_draw = Engine.get_frames_drawn();last_wall = Time.get_ticks_msec()
	output.store_line(JSON.stringify({"event":"phase","phase":phase,"wall":last_wall/1000.}));output.flush();print("PHASE ",phase)
func observe(seconds: float) -> void:
	var until := Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:
		await process_frame
		if Time.get_ticks_msec()>=next_log:log_sample();next_log = Time.get_ticks_msec()+1000
func settled() -> bool:
	if view.scene_layers.is_buffering():return false
	var ps: Dictionary = view.scene_layers.playback.worker.status();var fs: Dictionary = view.scene_layers.field_playback.worker.status()
	return not ps.worker_active and ps.desired.all(func(i):return ps.ready_indices.has(i)) and fs.active_jobs == 0 and fs.session.get("state") == "ready"
func ready() -> void:
	var until := Time.get_ticks_msec()+180000
	while not settled() and Time.get_ticks_msec()<until:await observe(1)
	await observe(2)
func run() -> void:
	var args := OS.get_cmdline_user_args();output = FileAccess.open(args[1],FileAccess.WRITE)
	Profile.enabled = true;Profile.reset()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	RenderingServer.frame_post_draw.connect(draw_observed)
	view = load("res://main.gd").new();view.capture_path = args[0];view.orbit_enabled = false
	root.add_child(view);root.title = "Wavez #382 end-of-playback GPU investigation"
	view.scene_loop_playback = false;view.physical_rate = 1.
	for id in view.scene_layers.states:
		if view.generic_reader.objects[id].kind == "volume":view.scene_layers.states[id].step = .25
	view.scene_layers.resample()
	output.store_line(JSON.stringify({"event":"settings","renderer":RenderingServer.get_current_rendering_method(),"viewport":root.size,"vsync":DisplayServer.window_get_vsync_mode(),"fields":view.scene_layers.snapshot(),"version":ProjectSettings.get_setting("application/config/version"),"source":args[0]}))
	change_phase("paused_preparation");await ready()
	change_phase("paused_start");await observe(5)
	view.play_button.pressed.emit();change_phase("playback")
	var last: float = view.generic_reader.frames[-1].time;var until := Time.get_ticks_msec()+240000
	while float(view.committed_sample.get("requested_time",-1))<last and Time.get_ticks_msec()<until:await observe(.25)
	var reached: bool = float(view.committed_sample.get("requested_time",-1))>=last
	change_phase("natural_end");await observe(float(args[2]))
	var before := snapshot();before.event = "before_manual_pause";output.store_line(JSON.stringify(before))
	if view.playing:view.play_button.pressed.emit()
	change_phase("manual_pause_same_end");await observe(15)
	var paused := snapshot();paused.event = "after_manual_pause";output.store_line(JSON.stringify(paused))
	# Same held endpoint, reverse direction and restart must remain functional.
	view.physical_rate = -1.;view.play_button.pressed.emit();change_phase("reverse_from_end");await observe(3)
	if view.playing:view.play_button.pressed.emit()
	view.physical_rate = 1.;view._seek_time(last*.5);change_phase("scrub_away");await ready();await observe(10)
	change_phase("paused_orbit");view.orbit_enabled = true;await observe(5);view.orbit_enabled = false
	var closed: bool = view._close_capture()
	change_phase("capture_closed");await observe(20)
	output.store_line(JSON.stringify({"event":"final","reached_end":reached,"capture_closed":closed,"error":view.scene_layers.error if view.scene_layers != null else "","profile":Profile.report()}));output.close()
	RenderingServer.frame_post_draw.disconnect(draw_observed);view.free();await process_frame;quit(0 if reached and closed else 1)

extends SceneTree
const Profile = preload("res://scene/playback_profile.gd")
const Grid = preload("res://layers/grid_view.gd")
const Visual = preload("res://scene/visual_state.gd")
var view
func _initialize() -> void:run.call_deferred()
func memory() -> Dictionary:
	var result := {}
	var f := FileAccess.open("/proc/self/status",FileAccess.READ)
	if f != null:
		for line in f.get_buffer(65536).get_string_from_utf8().split("\n"):
			var parts := line.replace("\t"," ").split(" ",false)
			if parts.size()>1 and parts[0].strip_edges() in ["VmRSS:","VmHWM:","VmSwap:"]:result[parts[0].strip_edges().trim_suffix(":")] = int(parts[1])*1024
	return result
func snapshot() -> Dictionary:
	return {"memory":memory(),"field":view.scene_layers.field_playback.profile_report(),"particle":view.scene_layers.playback.worker.status(),"time":view.requested_time,"gpu_texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"gpu_buffer_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)}
func save(path: String, result: Dictionary) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t",false,true));f.close()
func distribution(values: Array) -> Dictionary:
	var v := values.duplicate();v.sort()
	if v.is_empty():return {}
	return {"n":v.size(),"p50":v[int((v.size()-1)*.5)],"p95":v[int((v.size()-1)*.95)],"p99":v[int((v.size()-1)*.99)],"max":v[-1]}
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var wall_limit_us := int(float(args[3])*1000000) if args.size()>3 else 1200000000
	Engine.max_fps = 60
	view = load("res://main.gd").new();view.capture_path = args[0];view.playing = false;view.orbit_enabled = false
	var began := Time.get_ticks_usec();root.add_child(view)
	await process_frame
	await RenderingServer.frame_post_draw
	var report := {"capture":args[0],"open_first_draw_ms":(Time.get_ticks_usec()-began)/1000.0,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"target_rate":1.0,"paused_warmup_ms":2000,"display_target_ms":1000.0/30,"draw_target_ms":1000.0/60,"viewport":root.size,"visual":Visual.snapshot(view),"runs":[]}
	if view.scene_layers == null:report.error = "open failed";save(args[1],report);quit(1);return
	var first: float = view.generic_reader.frames[0].time;var last: float = view.generic_reader.frames[-1].time
	report.first = first;report.last = last
	for attempt in range(int(args[2]) if args.size()>2 else 2):
		view.playing = false
		if attempt>0:view.scene_layers.seek(first)
		while view.scene_layers.is_buffering():await process_frame
		# Identical short paused warmup; product Play determines any extra preparation.
		await create_timer(2).timeout
		var start := Time.get_ticks_usec();var prior := start;var last_commit_wall := start
		var previous_time: float = view.committed_sample.get("requested_time",first)
		var started_playback := false;var ready := start;var in_prepare := false;var event := {};var interruptions: Array = [];var frames: Array = [];var commits: Array = [];var rows: Array = [];var next_log := start;var snapshots: Array = [];var seen := {};var prep_profile := {}
		Profile.enabled = true;Profile.reset()
		view.physical_rate = 1.0;view.scene_loop_playback = false;view.play_button.pressed.emit()
		while Time.get_ticks_usec()-start < wall_limit_us:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec();var current: float = view.committed_sample.get("requested_time",first)
			var buffering: bool = view.scene_layers.is_buffering()
			if not started_playback and current>first:
				started_playback = true;ready = prior;last_commit_wall = prior;prep_profile = Profile.report();Profile.reset()
			if started_playback:
				frames.append((now-prior)/1000.0)
				if buffering and not in_prepare:event = {"wall_ms":(now-ready)/1000.0,"time":current,"start_us":now};in_prepare = true
				if not buffering and in_prepare:event.duration_ms = (now-event.start_us)/1000.0;interruptions.append(event);in_prepare = false
				if current != previous_time:commits.append((now-last_commit_wall)/1000.0);last_commit_wall = now
				rows.append([float(now-ready)/1000000.0,current,buffering])
			for id in view.scene_layers.views:
				var layer = view.scene_layers.views[id]
				if layer is Grid and not layer.data.is_empty():
					if not seen.has(id):seen[id] = {}
					seen[id][str(layer.data.source_index)] = true
			previous_time = current;prior = now
			if now>=next_log:
				var snap := snapshot();snap.wall_s = (now-start)/1000000.0;snapshots.append(snap);next_log = now+1000000
				print("PROGRESS ",attempt," ",current,"/",last," ",snap.wall_s," ",buffering)
			if current>=last:break
			if not view.playing and not buffering:break
		view.playing = false
		var result := {"complete":previous_time>=last,"preparation_ms":(ready-start)/1000.0,"wall_s":(Time.get_ticks_usec()-ready)/1000000.0,"advanced":previous_time-first,"frame_ms":distribution(frames),"commit_ms":distribution(commits),"interruptions":interruptions,"timeline":rows,"snapshots":snapshots,"profile":Profile.report(),"preparation_profile":prep_profile,"field_samples_presented":seen,"error":view.scene_layers.error}
		report.runs.append(result);save(args[1],report);print("COMPLETE ",JSON.stringify({"complete":result.complete,"wall_s":result.wall_s,"frame_ms":result.frame_ms,"interruptions":interruptions.size()}))
	view.free();await process_frame;quit()

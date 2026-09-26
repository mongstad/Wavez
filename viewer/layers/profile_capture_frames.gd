extends SceneTree
const Hash = preload("res://data/capture_index.gd")
const Grid = preload("res://layers/grid_view.gd")
const Visual = preload("res://scene/visual_state.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args := OS.get_cmdline_user_args();var out := args[1]
	var view = load("res://main.gd").new();view.capture_path = args[0];view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	for child in view.get_children():
		if child is CanvasLayer:child.visible = false
	var report := {"visual":Visual.snapshot(view),"frames":[]}
	var times: Array = [0.0,float(view.generic_reader.frames[-1].time)*.5,float(view.generic_reader.frames[-1].time)]
	if args[2] == "after":
		var control = view.scene_layers.field_playback
		control.request(0,view.scene_layers.field_budget())
		var jobs: Array = []
		for id in view.scene_layers.states:
			if view.scene_layers.views[id] is Grid and view.scene_layers.states[id].visible:
				for t in times:
					var index: int = view.generic_reader.bracket(id,t).a
					jobs.append(control._job(id,index,view.scene_layers.field_budget()))
		control.worker.prepare_session(control.token,jobs)
		var limit := Time.get_ticks_msec()+30000
		while control.worker.status().session.get("state") in ["planning","preparing"] and Time.get_ticks_msec()<limit:await process_frame
		report.preparation = control.worker.status().session
		if report.preparation.get("state") != "ready":
			push_error("Frame comparison requires completed field preparation.");quit(1);return
	for t in times:
		var started := Time.get_ticks_msec();var sample: Dictionary = {}
		while Time.get_ticks_msec()-started < 30000:
			sample = view.scene_layers.sample(t,true)
			if not sample.has("pending"):break
			await process_frame
		if sample.is_empty() or sample.has("pending"):push_error("Failed sample "+str(t));quit(1);return
		for i in range(10):await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image();image.save_png(out.path_join("frame-%s.png" % t))
		var frame := {"requested_time":t,"pixels":Hash.digest(image.get_data()),"metadata":view.committed_sample,"fields":{}}
		for id in view.scene_layers.views:
			var field = view.scene_layers.views[id]
			if field is Grid and not field.data.is_empty():
				var data := {"channels":{},"lod":field.lod,"statistics":field.color_stats,"source_time":field.data.time}
				for c in field.data.channels:data.channels[c] = Hash.digest(field.data.channels[c].to_byte_array())
				frame.fields[id] = data
		report.frames.append(frame)
	var file := FileAccess.open(out.path_join("frames.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t",false,true));file.close()
	view.free();await process_frame;quit()

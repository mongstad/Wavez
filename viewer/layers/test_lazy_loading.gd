extends "res://layers/test_scene_playback.gd"
const Reader = preload("res://layers/scene_reader.gd")
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	for kind in ["particles","volume","mesh"]:
		for fault in ["payload","descriptor","commit","shape","header"]:
			var path := out.path_join(kind+"-"+fault+".ssc")
			var reader := Reader.new()
			if fault == "header":
				check(not reader.open(path),kind+" unsafe fixed-header allocation rejected at open")
				reader.close();continue
			check(reader.open(path),kind+" future "+fault+" does not block open")
			check(reader.records.all(func(row):return row.descriptor.is_empty()),"no eager descriptors")
			check(not reader.read_sample("object",0).is_empty(),"first valid sample available")
			check(reader.read_sample("object",3).is_empty(),"requested corrupt sample rejected")
			check("object sample 3 (record 3)" in reader.error and "Reopen" in reader.error,"actionable record identity")
			check(not reader.read_sample("object",4).is_empty(),"valid later sample readable")
			reader.close()
			var view = load("res://main.gd").new();view.capture_path = path;view.playing = false;view.orbit_enabled = false
			root.add_child(view);view.set_process(false)
			check(not view.committed_sample.is_empty() and view.requested_time == 0,"initial visible scene committed")
			check(not view.play_button.disabled and not view.scene_layers.is_buffering(),"initial controls do not wait for lookahead")
			var controller = view.scene_layers.playback if kind == "particles" else (view.scene_layers.field_playback if kind == "volume" else view.scene_layers.mesh_playback)
			var began := Time.get_ticks_msec()
			while controller.worker.status().failures.is_empty() and Time.get_ticks_msec()-began < 10000:
				view.scene_layers.tick(0);await process_frame
			check(not controller.worker.status().failures.is_empty(),"background discovered corrupt future sample")
			check(not view.scene_layers.is_buffering() and view.scene_layers.error.is_empty(),"future corruption does not block valid resident scene")
			view.play_button.pressed.emit();check(view.playing,"Play remains responsive before corrupt sample")
			view.play_button.pressed.emit()
			check(not view.scene_layers.sample(0,true).has("pending"),"current sample survives bad lookahead")
			check(view.generic_reader.records[19].descriptor.is_empty(),"far descriptor remains lazy")
			if kind == "particles":check(controller.worker.status().desired.size()<=8 and not controller.full_preload,"bounded particle window")
			elif kind == "volume":check(controller.worker.status().bytes<=controller.worker.status().limit,"RAM-bounded automatic field cache")
			else:check(controller.worker.status().frames<=5,"bounded mesh window")
			view.playing = true;view.scene_layers.seek(3)
			began = Time.get_ticks_msec()
			while view.scene_layers.error.is_empty() and Time.get_ticks_msec()-began < 10000:
				view.scene_layers.tick(0);await process_frame
			check(not view.playing and "object sample 3 (record 3)" in view.scene_layers.error,"requested failure pauses with record error")
			check(view.committed_sample.requested_time == 0,"corrupt sample never published")
			check(await sample(view,4,true),"seek past rejected sample recovers")
			view.free();await process_frame
	# A later schema is discovered only when used, including explicit recipe restore.
	var source := out.path_join("channels.ssc")
	var reference = await make_schema_view(source,false)
	check(await sample(reference,5,false),"later schema reference")
	reference.scene_layers.states.field.channel = "later";reference.scene_layers.resample()
	var recipe := Inspection.snapshot(reference)
	var view = await make_schema_view(source,true)
	check(view.generic_reader.records[5].descriptor.is_empty(),"recipe target remains unresolved at open")
	check(Inspection.restore(view,recipe).is_empty(),"recipe resolves requested-time channel without scanning other descriptors")
	check(view.scene_layers.views.field.data.channels.later[0] == 3,"recipe preserves later f64 value")
	check(view.generic_reader.records[2].descriptor.is_empty(),"recipe does not inspect unrelated descriptors")
	view.free();reference.free();await process_frame
	view = await make_schema_view(source,true)
	check(await sample(view,5,true),"asynchronous later schema available")
	view.scene_layers.refresh_probe_channels()
	var channels := []
	for i in view.scene_layers.probe_channel_choice.item_count:channels.append(view.scene_layers.probe_channel_choice.get_item_text(i))
	check(channels.has("later"),"worker-discovered channel remains in probe choices")
	view.free();await process_frame
	view = load("res://main.gd").new();view.capture_path = out.path_join("hidden.ssc");view.playing = false
	root.add_child(view);view.set_process(false)
	await settle_draw()
	check(not view.committed_sample.is_empty() and view.scene_layers.error.is_empty(),"malformed hidden layer does not block first display")
	check(view.generic_reader.records[1].descriptor.is_empty(),"hidden layer descriptor remains unresolved")
	view.scene_layers.states.visible.visible = false;view.scene_layers.states.hidden.visible = true
	check(view.scene_layers.sample(0).is_empty() and "hidden sample 0 (record 1)" in view.scene_layers.error,"revealing hidden malformed sample reports contextual error")
	view.free();await process_frame
	# Let queued GPU frees complete before the native renderer is torn down.
	for i in range(5):await process_frame
	if DisplayServer.get_name() != "headless":await RenderingServer.frame_post_draw
	Job.write_json(out.path_join("checks.json"),{"checks":checks,"failures":failures})
	print("LAZY LOADING: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func make_schema_view(path: String, asynchronous: bool):
	var view = load("res://main.gd").new();view.capture_path = path;view.playing = false;view.orbit_enabled = false
	view.scene_prebuffer_enabled = asynchronous
	root.add_child(view);view.set_process(false)
	await settle_draw()
	return view

func settle_draw() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":await RenderingServer.frame_post_draw

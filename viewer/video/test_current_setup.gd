extends SceneTree
const Job = preload("res://video/render_job.gd")
var checks: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void: checks.append({"ok":ok,"label":label})
func run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	for name in ["particles","late-particles","field","mesh","mixed","late","overflow","budget","production"]:
		if name == "production" and not FileAccess.file_exists(directory.path_join("production-path.txt")):continue
		var view = load("res://main.gd").new()
		view.scene_prebuffer_enabled = false;view.playing = false;view.orbit_enabled = false
		view.capture_path = FileAccess.get_file_as_string(directory.path_join("production-path.txt")) if name == "production" else directory.path_join(name+".ssc")
		root.add_child(view);view.set_process(false)
		await process_frame
		RenderingServer.force_draw(false)
		check(view.frame_a != null,name+": current viewer opens SIMSCP4")
		view._apply_preset("Scientific")
		var time := .1 if name == "production" else .75
		view.scene_layers.sample(time)
		var action: Dictionary = view.shell.commands.video
		action.popup.id_pressed.emit(action.index)
		check(view.video_dialog.visible,name+": File / Export / Video opens current dialog")
		view.video_dialog.range_choice.select(1)
		check(is_equal_approx(view.video_dialog.settings().start_time,time),name+": current-position export uses committed scene clock")
		view.video_dialog.hide()
		view.requested_time = time+.1
		view.video_dialog.open()
		check(is_equal_approx(view.video_dialog.settings().start_time,time),name+": uncommitted target does not change export start")
		view.video_dialog.hide();view.requested_time = time
		var committed: Dictionary = view.committed_sample
		view.committed_sample = {};view.video_dialog.open()
		check(not view.video_dialog.can_start,name+": missing committed sample refuses export")
		view.video_dialog.hide();view.committed_sample = committed
		if not view.scene_layers.particle_id.is_empty():
			view.color_channel = "color_value" if name != "production" else "fixed"
			view.show_legend = true;view._restyle()
		for id in view.scene_layers.states:
			var state: Dictionary = view.scene_layers.states[id]
			if view.generic_reader.objects[id].kind == "volume":
				state.channel = "psi_imag";state.lower = -.5;state.upper = 1.;state.opacity = .4
				state.opacity_mapping = {"mode":"magnitude","lower":.15,"upper":.85}
				view.scene_layers.legend_visibility[id] = true
			elif view.generic_reader.objects[id].kind == "mesh":state.channel = "scalar"
		if name == "budget":view.scene_layers.gpu_budget_mib = 1
		view.scene_layers.resample()
		Job.write_json(directory.path_join(name+"-state.json"),Job.snapshot(view))
		view.free();await process_frame
	Job.write_json(directory.path_join("setup.json"),{"checks":checks})
	quit()

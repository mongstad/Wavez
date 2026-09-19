extends SceneTree
const Worker = preload("res://video/render_worker.gd")
const Job = preload("res://video/render_job.gd")
class ControlledWorker extends Worker:
	var scenario := "visible"
	var changed := false
	var cover: Window
	var observations: Array = []
	func _configure_window() -> void:
		if scenario in ["background","cancel"]:super._configure_window()
	func _process(_delta: float) -> void:
		if completed >= 10 and not changed:
			changed = true
			if scenario == "minimized":get_tree().root.mode = Window.MODE_MINIMIZED
			if scenario in ["unfocused","obscured"]:
				get_tree().root.gui_embed_subwindows = false
				cover = Window.new();cover.title = "Export regression cover";cover.size = get_tree().root.size
				cover.position = get_tree().root.position if scenario == "obscured" else get_tree().root.position+Vector2i(700,0)
				cover.always_on_top = true;add_child(cover)
				var panel := ColorRect.new();panel.color = Color(.1,.1,.1);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);cover.add_child(panel)
				cover.show();cover.grab_focus()
			if scenario == "cancel":Job.write_json(directory.path_join("cancel"),{})
		if completed >= 10 and (observations.is_empty() or observations[-1].frame != completed):
			observations.append({"frame":completed,"mode":get_tree().root.mode,"focused":get_tree().root.has_focus(),"unfocusable":get_tree().root.unfocusable,"cover_visible":is_instance_valid(cover) and cover.visible})
	func finish(stage: String, message: String, code: int) -> void:
		Job.write_json(directory.path_join("window-observations.json"),{"scenario":scenario,"observations":observations,"final_mode":get_tree().root.mode,"stage":stage,"display":DisplayServer.get_name()})
		super.finish(stage,message,code)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var worker := ControlledWorker.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--job="):worker.job_path = arg.trim_prefix("--job=")
		if arg.begins_with("--scenario="):worker.scenario = arg.trim_prefix("--scenario=")
	if worker.job_path.is_empty():quit(1);return
	root.add_child(worker)

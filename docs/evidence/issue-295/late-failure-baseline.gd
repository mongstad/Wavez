extends SceneTree
const Viewer = preload("res://main.gd")
func _initialize(): run.call_deferred()
func run():
 var view = Viewer.new(); root.add_child(view); view.set_process(false); view.scene_prebuffer_enabled = false
 view._open_capture("/tmp/wavez-issue-295/valid.wvz")
 var reader = view.generic_reader
 var sample = view.committed_sample.duplicate(true)
 view._open_capture("/tmp/wavez-issue-295/duplicate.wvz")
 print("ACCEPTED_MAIN late sample failure: prior_reader_retained=",view.generic_reader == reader," prior_sample_retained=",view.committed_sample == sample," current_sample_empty=",view.committed_sample.is_empty())
 print("ACCEPTED_MAIN retained notices: ",view.shell.status_ui.failures)
 view._open_capture("/tmp/wavez-issue-295/valid.wvz")
 print("ACCEPTED_MAIN subsequent success: ",view.shell.status_ui.badge.label.text)
 view.queue_free()
 for i in 4: await process_frame
 quit()

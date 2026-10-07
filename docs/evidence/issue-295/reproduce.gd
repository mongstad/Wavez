extends SceneTree
const Viewer = preload("res://main.gd")
func _initialize(): run.call_deferred()
func run():
 var view = Viewer.new(); root.add_child(view); view.set_process(false)
 for path in ["invalid", "valid", "duplicate", "valid"]:
  view._open_capture("/tmp/wavez-issue-295/"+path+".wvz")
  for i in 10: await process_frame
  view.shell.status_ui.refresh()
  print("REPRO ",path," banner=",view.shell.error_details," failures=",view.shell.status_ui.failures," badge=",view.shell.status_ui.badge.label.text)
 view.queue_free()
 for i in 4: await process_frame
 quit()

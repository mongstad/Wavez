extends Node
var view
func _ready():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--wavez-render-job="):return
 run.call_deferred()
func settle():
 for i in 4: await get_tree().process_frame
func run():
 view=load("res://main.gd").new();get_tree().root.add_child(view);await settle()
 for i in 4:
  view._open_capture("/tmp/close-329-headless-final/mixed.wvz");await settle()
  var v=view.video_dialog;v.open();v.range_choice.select(2);v.update_range();v.set_range_times(0,1)
  v.rate.value=1;v.fps.value=6;v.width.value=256;v.height.value=256;v.overlays.button_pressed=false
  v.output.text="/tmp/close-329-baseline-package/control-%d.mp4"%i;v.start_export();v.hide()
  var end=Time.get_ticks_msec()+120000
  while v.pid>0 and Time.get_ticks_msec()<end:await get_tree().create_timer(.05).timeout
  if v.pid>0 or v.job_status.get("stage")!="complete":push_error("baseline video failed");get_tree().quit(1);return
  view.shell.status_ui.open_jobs();await settle();view.shell.status_ui.jobs_dialog.hide();await settle()
 var file=view.shell.menus.File.get_popup();file.popup();await settle();RenderingServer.force_draw(false);file.hide();await settle()
 view.queue_free();await settle()
 print("BASELINE VIDEO TEARDOWN: 4 exports complete");get_tree().quit()

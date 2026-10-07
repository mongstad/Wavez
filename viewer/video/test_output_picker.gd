extends SceneTree
# #283: real Browse controls and exports; native return edge cases are injected.
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
var view
var out: String
var checks: Array = []
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks.append({"ok":ok,"label":label})
	if not ok: push_error(label)
func settle():
	for i in 8: await process_frame
func run():
	out = OS.get_cmdline_user_args()[0]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
	create_timer(90).timeout.connect(func():push_error("Picker test timeout");quit(1))
	view=Viewer.new();view.capture_path=config.source;view.scene_prebuffer_enabled=false;view.playing=false;view.orbit_enabled=false
	root.add_child(view);await settle()
	var dialog=view.video_dialog
	var menu: Dictionary=view.shell.commands.video;menu.popup.id_pressed.emit(menu.index);await settle()
	check(OS.has_feature("editor") != config.packaged,"Expected development or packaged executable")
	check(not config.packaged or OS.has_feature("release"),"Packaged parent uses release template")
	check(dialog.visible and dialog.can_start,"Video Export ready on fresh launch")
	check(dialog.output.text.is_empty(),"Fresh preferences have no output path")
	check(view.open_dialog.use_native_dialog,"Capture picker still native")
	check(dialog.save_dialog.filters==PackedStringArray(["*.mp4 ; H.264 MP4"]),"Only MP4 is passed to native API")
	dialog.range_choice.select(2);dialog.update_range();dialog.start.value=0;dialog.end.value=.5
	dialog.width.value=320;dialog.height.value=180;dialog.fps.value=4
	dialog.ffmpeg="/usr/bin/ffmpeg"
	if config.get("native_review",false):
		dialog.save_dialog.current_dir=out
		dialog.browse_output()
		await create_timer(20).timeout
		Job.write_json(out.path_join("native-review.json"),{"pending":dialog.native_save_pending,"file":dialog.save_dialog.current_file,"filters":dialog.save_dialog.filters})
		view.queue_free();await process_frame;await process_frame;quit();return
	dialog.save_dialog.use_native_dialog=false
	dialog.save_dialog.current_dir=out
	for i in 2:
		# Drive production Browse and the actual embedded filename control.
		for button in dialog.find_children("*","Button",true,false):
			if button.text=="Browse…":button.pressed.emit()
		await settle()
		check(dialog.save_dialog.visible,"Browse opens save dialog "+str(i))
		check(dialog.save_dialog.current_file==(config.source.get_file().get_basename()+".mp4" if i==0 else "first.mp4"),"Browse seeds current filename "+str(i))
		var typed: String="first" if i==0 else "second.mp4"
		var filename: LineEdit=null
		for edit in dialog.save_dialog.find_children("*","LineEdit",true,false):
			if edit.text==dialog.save_dialog.current_file:filename=edit
		check(filename!=null,"Filename control found")
		filename.text=typed;filename.text_changed.emit(typed);await settle()
		var filter_found := false
		for option in dialog.save_dialog.find_children("*","OptionButton",true,false):
			if option.item_count==2 and option.get_item_text(0).contains("MP4"):
				filter_found = true
				check(option.selected==0,"Typing preserves embedded MP4 filter "+str(i))
		check(filter_found,"MP4 filter control found")
		dialog.save_dialog.get_ok_button().pressed.emit();await settle()
		var ancestor: Node=dialog.output.get_parent()
		while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(dialog.output)
		await settle()
		dialog.get_texture().get_image().save_png(out.path_join("chosen-"+str(i)+".png"))
		var expected:=out.path_join("first.mp4" if i==0 else "second.mp4")
		check(dialog.output.text==expected,"Directory, filename and extension round trip "+str(i))
		dialog.start_button.pressed.emit()
		var deadline:=Time.get_ticks_msec()+60000
		while dialog.preparing and Time.get_ticks_msec()<deadline:await create_timer(.01).timeout
		check(dialog.pid>0,"Start Export launches immediately "+str(i))
		while dialog.pid>0 and Time.get_ticks_msec()<deadline:await create_timer(.01).timeout
		check(dialog.job_status.stage=="complete" and FileAccess.file_exists(expected),"Real short export completes "+str(i))
		dialog.get_texture().get_image().save_png(out.path_join("complete-"+str(i)+".png"))
	var previous: String=dialog.output.text
	dialog.browse_output();await settle();dialog.save_dialog.get_cancel_button().pressed.emit();await settle()
	check(dialog.output.text==previous,"Browse Cancel preserves previous output")
	dialog._native_output_selected(false,PackedStringArray(),0)
	check(dialog.output.text==previous,"Native Cancel preserves previous output")
	for invalid in [out,out+"/","relative",""]:
		dialog._native_output_selected(true,PackedStringArray([invalid]),0)
		check(dialog.output.text==previous,"Native directory/relative/empty return rejected: "+invalid)
	dialog._native_output_selected(true,PackedStringArray([out.path_join("native-no-extension")]),0)
	check(dialog.output.text==out.path_join("native-no-extension.mp4"),"Native extensionless callback appends MP4")
	dialog._native_output_selected(true,PackedStringArray([out.path_join("native.mp4")]),0)
	check(dialog.output.text==out.path_join("native.mp4"),"Native explicit MP4 callback retained")
	for invalid in ["relative.mp4",out.path_join("wrong.txt")]:
		dialog.output.text=invalid;dialog.start_export();await settle()
		check(dialog.pid<=0 and dialog.message.text.contains("Choose an absolute .mp4 output path"),"Strict validation retained: "+invalid)
	Job.write_json(out.path_join("report.json"),{"checks":checks,"native_typing":"Not automated; embedded typing and native callback edges only"})
	view.queue_free();await process_frame;await process_frame
	quit(1 if checks.any(func(c):return not c.ok) else 0)

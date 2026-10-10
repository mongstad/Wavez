extends SceneTree
## Production Export Video display, precise settings and native keyboard audit.
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
const FloatText = preload("res://ui/components/float64_text.gd")
var checks := 0
var failures: Array[String] = []
var records := {}
var matrix: Array = []
var viewer
var output: String
var baseline := false
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label);push_error(label)
func settle():
	for i in 6: await process_frame
	RenderingServer.force_draw(false)
func picture(name: String):
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output.path_join(name+".png"))
func key(window: Window, code: Key):
	var event := InputEventKey.new();event.keycode=code;event.pressed=true;window.push_input(event)
	event=event.duplicate();event.pressed=false;window.push_input(event)
func edit(spin: SpinBox, value: String):
	var input := spin.get_line_edit();input.grab_focus();input.edit()
	await settle()
	input.edit()
	input.select_all()
	for character in value:
		var event := InputEventKey.new();event.unicode=character.unicode_at(0);event.pressed=true
		spin.get_window().push_input(event)
		event=event.duplicate();event.pressed=false;spin.get_window().push_input(event)
	key(spin.get_window(),KEY_ENTER);await settle()
func exact_range(dialog, first: float, last: float):
	# Restored selections supported by the previous four-decimal editor.
	if dialog.has_method("set_range_times"): dialog.set_range_times(snappedf(first,.0001),snappedf(last,.0001))
	else: dialog.start.value=first;dialog.end.value=last;dialog.update_estimate()
func arrow(spin: SpinBox, up: bool):
	var rect := spin.get_global_rect()
	var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	event.position=Vector2(rect.end.x-8,rect.position.y+rect.size.y*(.25 if up else .75))
	spin.get_window().push_input(event)
	event=event.duplicate();event.pressed=false;spin.get_window().push_input(event)
	await settle()
func review_controls(dialog, source: String):
	check(dialog.start.step==1 and dialog.end.step==1,"One-second control step: "+source)
	check(dialog.start_clock.text=="00:30" and dialog.end_clock.text=="01:00","Whole clock endpoints: "+source)
	check(dialog.estimate.text.begins_with("Duration: 00:30 · 900 frames"),"30–60 at 30 FPS / 1× is 900 frames")
	check(dialog.rate.get_line_edit().text.contains("1.0") and dialog.rate.suffix=="×","Playback rate formatting retained")
	var a: float=30.0003;var b: float=60.0003
	dialog.set_range_times(a,b);await settle()
	var saved: Dictionary=dialog.settings()
	check(dialog.start.value==30 and dialog.end.value==60,"Fractional endpoints project to whole seconds")
	check(dialog.start_clock.text=="≈00:30" and dialog.end_clock.text=="≈01:00" and dialog.precise_range.visible and dialog.precise_range.text.contains("00:30.0003") and dialog.precise_range.text.contains("01:00.0003"),"Exact fractional interval is visibly disclosed")
	check(not dialog.start.get_line_edit().text.contains(".") and not dialog.end.get_line_edit().text.contains("."),"Time controls have no decimal places")
	if source=="scene":picture("fractional-preserved")
	if source=="scene":
		for light in [false,true]:
			viewer.shell.appearance.light=light;viewer.shell.appearance.apply();await settle()
			for dimensions in [Vector2i(700,650),Vector2i(560,360)]:
				dialog.size=dimensions;await settle()
				check(dialog.precise_range.get_global_rect().end.y<=dialog.start_button.get_global_rect().position.y,"Exact fractional interval clears actions at "+str(dimensions))
				check(dialog.precise_range.get_global_rect().end.x<=dialog.summary_group.get_global_rect().end.x,"Exact fractional interval wraps within summary")
				picture("fractional-"+("light" if light else "dark")+"-"+str(dimensions.x))
		dialog.size=Vector2i(700,650);await settle()
	dialog.hide();dialog.open();await settle()
	check(dialog.settings()==saved,"Opening Custom preserves exact selection and output settings")
	dialog.start.get_line_edit().grab_focus();await settle();key(dialog,KEY_ENTER);await settle()
	dialog.end.get_line_edit().grab_focus();await settle();key(dialog,KEY_TAB);await settle()
	check(dialog.settings()==saved,"Unchanged Enter/Tab focus does not quantize endpoints")
	await arrow(dialog.start,true)
	check(dialog.settings().start_time==a+1 and dialog.settings().end_time==b,"Up arrow shifts only exact Start by one second")
	await arrow(dialog.start,false)
	check(dialog.settings()==saved,"Down arrow reverses Start step without losing its fraction")
	await arrow(dialog.end,false)
	check(dialog.settings().end_time==b-1 and dialog.settings().start_time==a,"Down arrow shifts only exact End by one second")
	await arrow(dialog.end,true)
	check(dialog.settings()==saved,"Up arrow reverses End step without losing its fraction")
	await edit(dialog.start,"30");await edit(dialog.end,"60")
	check(dialog.settings().start_time==30 and dialog.settings().end_time==60 and not dialog.precise_range.visible,"Explicit keyboard entry chooses whole seconds, including same displayed value")
	await edit(dialog.start,"30.25");await edit(dialog.end,"60.25")
	check(dialog.settings().start_time==30 and dialog.settings().end_time==60,"Explicit fractional keyboard entry rounds to nearest whole second")
	await edit(dialog.start,"30.75");await edit(dialog.end,"60.75")
	check(dialog.settings().start_time==31 and dialog.settings().end_time==61,"Fractional keyboard entry rounds upward only on explicit edit")
	dialog.set_range_times(59.9999,60.0001);await settle()
	check(dialog.settings().start_time==59.9999 and dialog.settings().end_time==60.0001 and Job.frame_total(dialog.settings())==1 and dialog.precise_range.visible,"Subsecond range crossing minute boundary is preserved, not collapsed")
	dialog.set_range_times(-.125,.125);await settle()
	var signed: Dictionary=dialog.settings()
	check(dialog.start_clock.text=="≈00:00" and dialog.precise_range.text.contains("-00:00.125"),"Signed near-zero source clock remains explicit")
	await arrow(dialog.start,true);await arrow(dialog.start,false)
	check(dialog.settings()==signed,"Signed fractional increment reverses exactly")
	await edit(dialog.start,"invalid")
	check(dialog.settings()==signed,"Invalid keyboard entry does not normalize fractional time")
	dialog.set_range_times(.5,2.5);await settle()
	await arrow(dialog.start,false)
	check(dialog.settings().start_time==-.5 and dialog.start.value==0 and dialog.start_clock.text=="≈00:00","Half-second tie steps consistently across zero")
	await arrow(dialog.start,true)
	check(dialog.settings().start_time==.5 and dialog.start.value==1,"Half-second tie step reverses without quantization")
	dialog.set_range_times(-1e31,1e31)
	check(dialog.settings().start_time==-1e30 and dialog.settings().end_time==1e30,"Programmatic Custom endpoints retain control bounds")
func record(name: String, dialog):
	var settings: Dictionary = dialog.settings()
	matrix.append({"case":name,"settings":settings,"frames":Job.frame_total(settings),"first_sample":Job.sample_time(settings,0),"last_sample":Job.sample_time(settings,Job.frame_total(settings)-1)})
	var data := {"start":FloatText.format_value(settings.start_time),"end":FloatText.format_value(settings.end_time),"rate":FloatText.format_value(settings.playback_rate),"summary":dialog.estimate.text}
	if not baseline: data.merge({"start_clock":dialog.start_clock.text,"end_clock":dialog.end_clock.text,"start_hint":dialog.start.tooltip_text,"end_hint":dialog.end.tooltip_text})
	if dialog.has_method("set_range_times"): data.precise_range=dialog.precise_range.text if dialog.precise_range.visible else ""
	records[name]=data
func run():
	output=OS.get_cmdline_user_args()[0];baseline=OS.get_cmdline_user_args().size()>1
	create_timer(100).timeout.connect(func():push_error("Time presentation audit timed out");quit(1))
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("config.json")))
	viewer=Viewer.new();viewer.scene_prebuffer_enabled=false;root.add_child(viewer);viewer.set_process(false)
	viewer.shell.edge_reveal.set_process(false);await settle()
	var clock=load("res://ui/shell/time_seek_popover.gd")
	for pair in [[0.,"00:00"],[.04,"00:00"],[59.9999,"00:59"],[60.,"01:00"],[210.,"03:30"],[3599.9999,"59:59"],[3600.,"01:00:00"],[3867.3,"01:04:27"],[36000.,"10:00:00"]]:
		check(clock.format_time(pair[0])==pair[1],"Accepted playback clock: "+str(pair[0]))
	if not baseline:
		for pair in [[.125,"00:00.125"],[59.9999,"00:59.9999"],[3601.125,"01:00:01.125"],[-1.125,"-00:01.125"],[.0000001,"00:00.0000001"]]:
			check(clock.format_time(pair[0],true)==pair[1],"Fractional/signed clock: "+str(pair[0]))
		check(clock.format_time(1e-30,true).contains(FloatText.format_value(1e-30)),"Extreme fraction keeps exact seconds visible")
		check(clock.format_time(59.999999,true,3)=="≈01:00","Rounded video duration carries at minute boundary")
		check(clock.format_time(108068./30.,true,3)=="≈01:00:02.267","Hour-plus rounded summary has no binary tail")
	for source in ["scene","hours","precise"]:
		viewer._open_capture(config[source]);viewer.playing=false;viewer.orbit_enabled=false
		check(not viewer.scene_layers.sample(viewer.requested_time,false).is_empty(),source+" has committed content")
		viewer._apply_preset("Scientific");viewer._sync_control_state();viewer.shell.refresh();await settle()
		var dialog=viewer.video_dialog
		dialog.range_choice.select(0);dialog.open();dialog.fps.value=30;dialog.rate.value=1;await settle()
		var first: float=viewer.generic_reader.frames[0].time;var last: float=viewer.generic_reader.frames[-1].time
		check(dialog.settings().start_time==first and dialog.settings().end_time==last,"Full preserves exact endpoints: "+source)
		var unchanged: Dictionary=dialog.settings().duplicate(true);dialog.update_estimate()
		check(dialog.settings()==unchanged,"Readout refresh preserves settings: "+source)
		record(source+"-full",dialog)
		if source=="scene":
			viewer.shell.transport.refresh()
			check(viewer.shell.transport.duration.text=="03:30","Playback total for 210-second scene")
			check(Job.frame_total(dialog.settings())==6300,"210 seconds at 30 FPS / 1× has 6300 frames")
			if not baseline:
				check(dialog.start_clock.text=="00:00" and dialog.end_clock.text=="03:30","Export endpoints agree with playback clock")
				check(dialog.estimate.text.begins_with("Duration: 03:30 · 6,300 frames"),"Unambiguous 210-second export summary")
				check(dialog.rate.suffix=="×" and dialog.start.suffix=="s" and dialog.end.suffix=="s","Times and playback multiplier have distinct units")
			for light in [false,true]:
				viewer.shell.appearance.light=light;viewer.shell.appearance.apply();await settle()
				for dimensions in [Vector2i(700,650),Vector2i(560,360)]:
					dialog.size=dimensions;await settle()
					var scroll:ScrollContainer=dialog.fields.get_parent();scroll.scroll_vertical=0;await settle()
					check(dialog.range_group.get_global_rect().end.x<=scroll.get_global_rect().end.x,"Range fits dialog "+str(dimensions))
					check(dialog.summary_group.get_global_rect().end.y<=dialog.start_button.get_global_rect().position.y,"Summary clears actions "+str(dimensions))
					picture(("light" if light else "dark")+"-"+str(dimensions.x))
					if not baseline:
						check(dialog.start.get_line_edit().size.x>=80,"Seconds editor remains usable "+str(dimensions))
						check(dialog.start_clock.get_global_rect().end.x<=dialog.start.get_global_rect().position.x,"Clock and editor do not overlap")
					dialog.range_choice.grab_focus();key(dialog,KEY_TAB);await settle()
					check(dialog.gui_get_focus_owner()!=null and dialog.gui_get_focus_owner()!=dialog.range_choice,"Native Tab advances settings focus")
					scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await settle()
					check(dialog.groups.Output.get_global_rect().end.y<=scroll.get_global_rect().end.y,"Output remains reachable by scrolling")
					scroll.scroll_vertical=0
			dialog.size=Vector2i(700,650);await settle()
		if not baseline and source=="precise":
			check(dialog.start.tooltip_text.contains(FloatText.format_value(first)) and dialog.end.tooltip_text.contains(FloatText.format_value(last)),"Precise preset seconds remain visible in hints")
			picture("precise-endpoints")
		if source=="hours":
			await settle();picture("hour-plus")
		var current:=first+(last-first)*.5
		viewer.scene_layers.sample(current,false);dialog.hide();dialog.range_choice.select(1);dialog.open();await settle()
		check(dialog.settings().start_time==current,"Current range uses committed source time: "+source)
		record(source+"-current",dialog)
		dialog.range_choice.select(2);dialog.update_range()
		# Intentional whole-second edits agree with the previous precision model.
		await edit(dialog.start,"30");await edit(dialog.end,"60")
		check(dialog.settings().start_time==30 and dialog.settings().end_time==60,"Whole-second keyboard entry: "+source)
		record(source+"-whole-keyboard",dialog)
		if dialog.has_method("set_range_times"):
			if source=="scene":picture("owner-30-60")
			await review_controls(dialog,source)
		exact_range(dialog,first+.125,first+.875)
		await settle()
		for speed in [.5,1.,2.5]:
			dialog.rate.value=speed
			for frequency in [24,30,60]:
				dialog.fps.value=frequency;dialog.update_estimate();record(source+"-custom-"+str(speed)+"-"+str(frequency),dialog)
		dialog.rate.value=.75;dialog.fps.value=4;dialog.update_estimate();record(source+"-fractional-job",dialog)
		if source=="scene":
			await settle()
			picture("fractional-custom")
			var job:Dictionary=dialog.configured_job();job.width=320;job.height=180;job.keep_frames=true;job.inspection_sidecars=false;job.ffmpeg_path="/usr/bin/ffmpeg"
			Job.write_json(output.path_join("export-settings.json"),job)
		exact_range(dialog,dialog.settings().start_time,dialog.settings().start_time)
		check(Job.frame_total(dialog.settings())==1,"Zero range still exports one frame")
		record(source+"-still",dialog)
		exact_range(dialog,dialog.settings().start_time,dialog.settings().start_time-.1)
		check(dialog.estimate.text=="End time must be at or after start time.","Inverted range validation retained")
		exact_range(dialog,dialog.settings().start_time,dialog.settings().start_time+.75);dialog.preparing=true;dialog._sync_action_buttons()
		check(not dialog.start.editable and not dialog.end.editable and dialog.range_choice.disabled,"Active export locks nested seconds editors")
		dialog.preparing=false;dialog._sync_action_buttons()
		check(dialog.start.editable and dialog.end.editable and not dialog.range_choice.disabled,"Idle custom range restores editor states")
		dialog.range_choice.select(0);dialog.update_range();dialog.preparing=true;dialog._sync_action_buttons();dialog.preparing=false;dialog._sync_action_buttons()
		check(not dialog.start.editable and not dialog.end.editable,"Idle Full restores read-only endpoint semantics")
		dialog.hide()
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"records":records,"matrix":matrix,"renderer":RenderingServer.get_current_rendering_method(),"baseline":baseline})
	viewer.queue_free();await process_frame;await process_frame
	print("VIDEO TIME: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

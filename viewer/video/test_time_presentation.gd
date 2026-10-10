extends SceneTree
## Production Export Video display, precise settings and native keyboard audit.
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
const FloatText = preload("res://ui/components/float64_text.gd")
var checks := 0
var failures: Array[String] = []
var records := {}
var matrix: Array = []
var hover_records: Array = []
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
func edit(spin: SpinBox, value: String, submit: Key = KEY_ENTER):
	var input := spin.get_line_edit();input.grab_focus();input.edit()
	await settle()
	input.edit()
	input.select_all()
	for character in value:
		var event := InputEventKey.new();event.unicode=character.unicode_at(0);event.pressed=true
		spin.get_window().push_input(event)
		event=event.duplicate();event.pressed=false;spin.get_window().push_input(event)
	if submit!=KEY_NONE: key(spin.get_window(),submit)
	await settle()
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
func tooltip_labels(node: Node) -> Array:
	var labels: Array = []
	if node is Label and node.theme_type_variation == "TooltipLabel" and node.is_visible_in_tree(): labels.append(node.text)
	for child in node.get_children(): labels.append_array(tooltip_labels(child))
	return labels
func hover_time(control: Control, point: Vector2, expected: Control, label: String, should_show := false):
	var window := control.get_window()
	var motion := InputEventMouseMotion.new(); motion.position = point
	if window.is_embedded():
		motion.position += Vector2(window.position)
		root.warp_mouse(motion.position)
		root.push_input(motion)
	else:
		window.warp_mouse(motion.position)
		window.push_input(motion)
	await create_timer(.8).timeout; await settle()
	var hovered := window.gui_get_hovered_control()
	check(hovered == expected if expected != null else hovered != null, label + ": native hover reaches target")
	var chain: Array = []
	var node: Node = control
	var hints: Array = []
	while node is Control:
		chain.append({"class":node.get_class(),"hint":node.get_tooltip()})
		if not node.get_tooltip().is_empty(): hints.append(node.get_tooltip())
		node = node.get_parent()
	var popups := tooltip_labels(root)
	check(not hints.is_empty() if should_show else hints.is_empty(), label + ": editor/control/ancestor tooltip contract")
	check(not popups.is_empty() if should_show else popups.is_empty(), label + ": visible delayed popup contract")
	hover_records.append({"target":label,"hovered":hovered.get_class() if hovered != null else "none","ancestors":chain,"popups":popups})
func review_time_hover(dialog, label: String):
	var saved: Dictionary = dialog.settings()
	var scroll: ScrollContainer = dialog.fields.get_parent()
	for pair in [[dialog.start,dialog.start_clock,"Start"],[dialog.end,dialog.end_clock,"End"]]:
		var spin: SpinBox = pair[0]; var clock: Label = pair[1]
		var row := spin.get_parent()
		var permanent: Label = row.get_parent().get_child(row.get_index()-1)
		scroll.ensure_control_visible(spin); await settle()
		check(permanent.text == pair[2] and permanent.is_visible_in_tree(), label + ": permanent " + pair[2] + " label")
		check(scroll.get_global_rect().encloses(spin.get_global_rect()) and scroll.get_global_rect().encloses(clock.get_global_rect()) and scroll.get_global_rect().encloses(permanent.get_global_rect()),label + ": " + pair[2] + " targets are inside scroll viewport")
		var rect := spin.get_global_rect()
		await hover_time(spin.get_line_edit(),spin.get_line_edit().get_global_rect().get_center(),spin.get_line_edit(),label+"-"+pair[2]+"-editor")
		await hover_time(spin,Vector2(rect.end.x-8,rect.position.y+rect.size.y*.25),spin,label+"-"+pair[2]+"-up")
		await hover_time(spin,Vector2(rect.end.x-8,rect.position.y+rect.size.y*.75),spin,label+"-"+pair[2]+"-down")
		await hover_time(clock,clock.get_global_rect().get_center(),null,label+"-"+pair[2]+"-clock")
		await hover_time(permanent,permanent.get_global_rect().get_center(),null,label+"-"+pair[2]+"-label")
	scroll.ensure_control_visible(dialog.range_choice); await settle()
	await hover_time(dialog.range_choice,dialog.range_choice.get_global_rect().get_center(),dialog.range_choice,label+"-Mode")
	check(dialog.settings() == saved, label + ": hover preserves exact range and job settings")
	check(not dialog.rate.tooltip_text.is_empty() and not dialog.estimate.tooltip_text.is_empty(),label+": existing speed/summary tooltips retained")
	scroll.ensure_control_visible(dialog.end); await settle()
	picture("tooltip-free-"+label)
func review_controls(dialog, source: String):
	var first: float=dialog.timeline.times[0];var last: float=dialog.timeline.times[-1]
	dialog.set_range_times(first+30,first+60);await settle()
	check(dialog.start.step==1 and dialog.end.step==1,"One-second control step: "+source)
	check(dialog.start_clock.text=="00:30" and dialog.end_clock.text=="01:00","Whole clock endpoints: "+source)
	check(dialog.estimate.text.begins_with("Duration: 00:30 · 900 frames"),"30–60 at 30 FPS / 1× is 900 frames")
	check(dialog.rate.get_line_edit().text.contains("1.0") and dialog.rate.suffix=="×","Playback rate formatting retained")
	var a: float=first+30.0003;var b: float=first+60.0003
	dialog.set_range_times(a,b);await settle()
	var saved: Dictionary=dialog.settings()
	check(dialog.start.value==30 and dialog.end.value==60,"Fractional endpoints project to whole seconds")
	check(dialog.start_clock.text=="≈00:30" and dialog.end_clock.text=="≈01:00" and dialog.precise_range.visible and dialog.precise_range.text.contains("00:30.0003") and dialog.precise_range.text.contains("01:00.0003"),"Exact fractional interval is visibly disclosed")
	check(not dialog.start.get_line_edit().text.contains(".") and not dialog.end.get_line_edit().text.contains("."),"Time controls have no decimal places")
	if source=="scene":picture("fractional-preserved")
	if source=="scene" and baseline:
		await hover_time(dialog.start.get_line_edit(),dialog.start.get_line_edit().get_global_rect().get_center(),dialog.start.get_line_edit(),"accepted-Start-editor",true)
		picture("accepted-time-tooltip")
		var rect: Rect2 = dialog.start.get_global_rect()
		await hover_time(dialog.start,Vector2(rect.end.x-8,rect.position.y+rect.size.y*.25),dialog.start,"accepted-Start-up",true)
	if source=="scene":
		for light in [false,true]:
			viewer.shell.appearance.light=light;viewer.shell.appearance.apply();await settle()
			for dimensions in [Vector2i(700,650),Vector2i(560,360)]:
				dialog.size=dimensions;await settle()
				check(dialog.precise_range.get_global_rect().end.y<=dialog.start_button.get_global_rect().position.y,"Exact fractional interval clears actions at "+str(dimensions))
				check(dialog.precise_range.get_global_rect().end.x<=dialog.summary_group.get_global_rect().end.x,"Exact fractional interval wraps within summary")
				picture("fractional-"+("light" if light else "dark")+"-"+str(dimensions.x))
				if not baseline: await review_time_hover(dialog,("light" if light else "dark")+"-"+str(dimensions.x))
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
	check(dialog.settings().start_time==first+30 and dialog.settings().end_time==first+60 and not dialog.precise_range.visible,"Explicit keyboard entry chooses whole seconds, including same displayed value")
	await edit(dialog.start,"30.25");await edit(dialog.end,"60.25")
	check(dialog.settings().start_time==first+30 and dialog.settings().end_time==first+60,"Explicit fractional keyboard entry rounds to nearest whole second")
	await edit(dialog.start,"30.75");await edit(dialog.end,"60.75")
	check(dialog.settings().start_time==first+31 and dialog.settings().end_time==first+61,"Fractional keyboard entry rounds upward only on explicit edit")
	dialog.set_range_times(first+59.9999,first+60.0001);await settle()
	check(dialog.settings().start_time==first+59.9999 and dialog.settings().end_time==first+60.0001 and Job.frame_total(dialog.settings())==1 and dialog.precise_range.visible,"Subsecond range crossing minute boundary is preserved, not collapsed")
	dialog.set_range_times(first+10.5,first+12.5);await settle()
	var half: Dictionary=dialog.settings()
	await arrow(dialog.start,false);await arrow(dialog.start,true)
	check(dialog.settings()==half,"Half-second step reverses without quantization")
	await edit(dialog.start,"invalid")
	check(dialog.settings()==half,"Invalid keyboard entry preserves exact endpoints")

	# Native numeric drafts and arrow buttons must enforce both source extent and order.
	dialog.set_range_times(a,b);await edit(dialog.end,"29")
	check(dialog.settings().end_time==a and dialog.end.value>=dialog.start.value,"End below fractional Start clamps to exact Start")
	check(Job.frame_total(dialog.settings())==1,"Equal clamped endpoints preserve still convention")
	await arrow(dialog.end,false);await arrow(dialog.start,true)
	check(dialog.settings().start_time==a and dialog.settings().end_time==a,"Arrows cannot cross equal fractional endpoints")
	dialog.set_range_times(a,b);await edit(dialog.start,"70")
	check(dialog.settings().start_time==b and dialog.settings().end_time==b,"Start beyond fractional End clamps to exact End")
	await edit(dialog.start,"-1",KEY_TAB)
	check(dialog.settings().start_time==first and dialog.start.value==0,"Negative Start clamps to simulation origin")
	await edit(dialog.end,"-1")
	check(dialog.settings().end_time==first and dialog.end.value==0,"Negative End clamps to Start at zero")
	await arrow(dialog.start,false);await arrow(dialog.end,false)
	check(dialog.settings().start_time==first and dialog.settings().end_time==first,"Arrows cannot cross zero")
	await edit(dialog.end,"999999")
	check(dialog.settings().end_time==last,"Oversized End clamps to exact final sample")
	check(dialog.end.value<=last-first and dialog.end.value>=0,"End display never exceeds simulation duration")
	dialog.set_range_times(first,first+floorf(last-first));await settle()
	await edit(dialog.end,str(int(floorf(last-first))))
	check(dialog.settings().end_time==last,"Final whole-second edit includes arbitrary fractional duration and source offset: "+source)
	await edit(dialog.start,"999999")
	check(dialog.settings().start_time==last and dialog.start.value<=last-first,"Oversized Start clamps to End and duration")
	await arrow(dialog.start,true);await arrow(dialog.end,true)
	check(dialog.settings().start_time==last and dialog.settings().end_time==last,"Arrows cannot cross final sample")
	await edit(dialog.start,"0");await edit(dialog.end,"0")
	check(dialog.settings().start_time==first and dialog.settings().end_time==first,"Elapsed zero maps to exact recorded origin")
	dialog.set_range_times(first,last-.125);await settle()
	await arrow(dialog.end,true)
	check(dialog.settings().end_time==last,"Up arrow reaches exact fractional upper boundary from its final projected bucket")
	dialog.set_range_times(first+.125,last);await settle()
	await arrow(dialog.start,false)
	check(dialog.settings().start_time==first,"Down arrow reaches exact lower boundary from its first projected bucket")
	dialog.set_range_times(-1e31,1e31)
	check(dialog.settings().start_time==first and dialog.settings().end_time==last,"Restored out-of-domain values clamp to source bounds")
	var full: Dictionary=dialog.settings();dialog.hide();dialog.open();await settle()
	check(dialog.settings()==full,"Reopening preserves exact fractional boundary timestamps")
	check(dialog.start.value>=0 and dialog.start.value<=dialog.end.value and dialog.end.value<=last-first,"Both displayed endpoints lie within elapsed simulation extent")
	if source!="scene":picture(source+"-bounded-full")
	dialog.set_range_times(b,a)
	check(dialog.settings().start_time==b and dialog.settings().end_time==b,"Restored inverted range cannot become an export selection")
	dialog.set_range_times(a,b);await settle()
	var bounded: Dictionary=dialog.settings()
	await arrow(dialog.start,true);await arrow(dialog.start,false);await arrow(dialog.end,false);await arrow(dialog.end,true)
	check(dialog.settings()==bounded,"Mutual bound refreshes preserve opposite endpoints and reversible steps")
	if source=="scene":picture("bounded-custom")

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
			check(dialog.start.tooltip_text.is_empty() and dialog.end.tooltip_text.is_empty() and dialog.precise_range.visible,"Precise endpoints retain visible Exact range without tooltips")
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
		check(dialog.settings().start_time==(first+30 if dialog.has_method("set_range_times") else 30.0) and dialog.settings().end_time==(first+60 if dialog.has_method("set_range_times") else 60.0),"Whole-second keyboard entry maps to recorded source: "+source)
		# Compare identical recorded intervals; the intentional elapsed-control mapping
		# for offset sources is checked separately above.
		exact_range(dialog,30,60)
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
		if not dialog.has_method("set_range_times"): check(dialog.estimate.text=="End time must be at or after start time.","Baseline rejected inverted range at export")
		else: check(dialog.settings().end_time==dialog.settings().start_time,"Invalid restored End is constrained before export")
		exact_range(dialog,dialog.settings().start_time,dialog.settings().start_time+.75);dialog.preparing=true;dialog._sync_action_buttons()
		check(not dialog.start.editable and not dialog.end.editable and dialog.range_choice.disabled,"Active export locks nested seconds editors")
		dialog.preparing=false;dialog._sync_action_buttons()
		check(dialog.start.editable and dialog.end.editable and not dialog.range_choice.disabled,"Idle custom range restores editor states")
		dialog.range_choice.select(0);dialog.update_range();dialog.preparing=true;dialog._sync_action_buttons();dialog.preparing=false;dialog._sync_action_buttons()
		check(not dialog.start.editable and not dialog.end.editable,"Idle Full restores read-only endpoint semantics")
		dialog.hide()
	# Owner's 92-second End must include the final .33 seconds, without padding.
	viewer._open_capture(config.tail);viewer.playing=false;await settle()
	var tail=viewer.video_dialog;tail.range_choice.select(0);tail.open();await settle()
	var tail_last: float=tail.timeline.times[-1]
	check(tail.settings().end_time==tail_last,"Full keeps 92.33-second exact endpoint")
	tail.range_choice.select(2);tail.update_range()
	exact_range(tail,91.875,92.33);tail.fps.value=4;tail.rate.value=1
	if not baseline:
		tail.set_range_times(91.875,92);await settle()
		var selected: Dictionary=tail.settings();tail.hide();tail.open();await settle()
		check(tail.settings()==selected and tail.settings().end_time==92,"Reopening existing End 92 does not silently include remainder")
		await edit(tail.end,"92")
		check(tail.settings().end_time==tail_last and tail.end.value==92 and tail.end_clock.text=="≈01:32" and tail.precise_range.text.contains("01:32.33"),"Explicit End 92 includes remaining .33 seconds with exact readout")
		tail.set_range_times(91,91);await arrow(tail.end,true)
		check(tail.settings().end_time==tail_last,"End step into final whole second includes remaining .33 seconds")
		tail.set_range_times(91.875,92);await edit(tail.end,"92",KEY_TAB)
		check(tail.settings().end_time==tail_last,"Tab commits the same final-fraction policy")
		tail.set_range_times(91.875,92);await edit(tail.end,"92",KEY_NONE)
		tail.end.commit_edit();await settle()
		check(tail.settings().end_time==tail_last,"Export submission flushes pending same-value draft before job settings")
		check(tail.end_clock.text=="≈01:32" and tail.precise_range.text.contains("01:32.33") and tail.estimate.text.contains("2 frames"),"Final-fraction display and summary match submitted job")
		picture("final-fraction-92")
	check(Job.frame_total(tail.settings())==2 and Job.sample_time(tail.settings(),1)==92.125,"Final remaining fraction contributes its actual output frame")
	var tail_job: Dictionary=tail.configured_job();tail_job.width=320;tail_job.height=180;tail_job.keep_frames=true;tail_job.inspection_sidecars=false;tail_job.ffmpeg_path="/usr/bin/ffmpeg"
	Job.write_json(output.path_join("tail-settings.json"),tail_job);tail.hide()
	if not baseline:
		for source in ["short","still"]:
			viewer._open_capture(config[source]);viewer.playing=false
			await settle()
			var dialog=viewer.video_dialog
			dialog.range_choice.select(0);dialog.open();await settle()
			var first: float=dialog.timeline.times[0];var last: float=dialog.timeline.times[-1]
			check(dialog.settings().start_time==first and dialog.settings().end_time==last,"Full retains exact subsecond/zero-length source: "+source)
			check(dialog.start.value==0 and dialog.end.value==0,"Subsecond/zero-length whole controls stay within duration: "+source)
			dialog.range_choice.select(2);dialog.update_range();await settle()
			var unchanged: Dictionary=dialog.settings()
			dialog.hide();dialog.open();await settle();dialog.start.get_line_edit().grab_focus();await settle();key(dialog,KEY_ENTER);await settle()
			check(dialog.settings()==unchanged,"Reopening short Custom does not collapse exact endpoints: "+source)
			await edit(dialog.end,"-1",KEY_TAB)
			check(dialog.settings().end_time==first,"Negative End respects zero and Start for "+source)
			await edit(dialog.end,"10")
			check(dialog.settings().end_time==last and dialog.end.value==0,"Oversized End selects exact subsecond/zero boundary: "+source)
			await edit(dialog.end,"0")
			check(dialog.settings().end_time==last,"End zero includes all of a subsecond simulation: "+source)
			if source=="short":
				dialog.set_range_times(first,last-.125);await arrow(dialog.end,true)
				check(dialog.settings().end_time==last,"Subsecond upper boundary reachable by clamped one-second button")
			await edit(dialog.start,"10")
			check(dialog.settings().start_time==last and Job.frame_total(dialog.settings())==1,"Oversized Start respects short End and still count: "+source)
			await edit(dialog.start,"-1")
			check(dialog.settings().start_time==first,"Negative Start selects exact short origin: "+source)
			picture(source+"-bounded");dialog.hide()
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"records":records,"matrix":matrix,"renderer":RenderingServer.get_current_rendering_method(),"baseline":baseline,"hover":hover_records})
	viewer.queue_free();await process_frame;await process_frame
	print("VIDEO TIME: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

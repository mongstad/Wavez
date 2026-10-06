extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Profile = preload("res://scene/playback_profile.gd")
var checks := 0
var failures: Array = []
var output := ""
var layouts: Array = []
var request_delay_observed_ms := 0
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle():
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
func ready(viewer):
	var deadline := Time.get_ticks_msec()+15000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec()<deadline:
		viewer.scene_layers.tick(0); await process_frame
	viewer.shell.transport.refresh()
	check(not viewer.scene_layers.is_buffering(),"Preparation completes")
func picture(name: String): root.get_texture().get_image().save_png(output.path_join(name+".png"))
func go(ui, text: String):
	# Scientific-controller coverage intentionally includes fractional targets that
	# the normal whole-clock editor no longer accepts. Native UI is tested separately.
	ui.reset_requested(); check(ui.viewer._seek_time(text.to_float()), "Scientific seek accepts " + text); ui.refresh()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--transport-output="): output = arg.trim_prefix("--transport-output=")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("config.json")))
	var viewer = Viewer.new(); viewer.playing = false; viewer.orbit_enabled = false; root.add_child(viewer); viewer.set_process(false)
	var ui = viewer.shell.transport
	check(ui.displayed.get_theme_font("font") == ui.duration.get_theme_font("font"),"Both playback readouts resolve the same font resource")
	check(ui.displayed.get_theme_font_size("font_size") == ui.duration.get_theme_font_size("font_size") and ui.duration.get_theme_font_size("font_size") == viewer.shell.style_slice.theme.get_font_size("font_size","NumericValue"),"Both playback readouts use the shared numeric size")
	for row in [[0.0,"00:00"],[0.04,"00:00"],[43.7,"00:43"],[59.9,"00:59"],[59.94,"00:59"],[59.96,"00:59"],[60.0,"01:00"],[72.4,"01:12"],[763.6,"12:43"],[3599.9,"59:59"],[3599.94,"59:59"],[3599.96,"59:59"],[3600.0,"01:00:00"],[3867.3,"01:04:27"],[36000.0,"10:00:00"]]:
		check(ui.format_duration(row[0]) == row[1],"Whole-clock duration formatting: "+str(row[0]))
		check(ui.format_duration(row[0],true) == ("-"+row[1] if row[1] != "00:00" else "00:00"),"Remaining formatting and zero: "+str(row[0]))
	check(viewer.play_button.disabled and ui.rate.disabled,"Empty transport explains unavailable playback")
	viewer._open_capture(config.source); viewer.playing = false; await ready(viewer); await settle()
	await delay_checks(viewer,ui)
	check(ui.is_ancestor_of(viewer.play_button) and ui.is_ancestor_of(viewer.timeline),"Canonical playback controls owned by persistent transport")
	check(not viewer.sections.has("Playback") and not viewer.visual_sliders.has("Physical time units / second"),"Retired playback controls are not constructed")
	var before: Dictionary = viewer.committed_sample.duplicate(true)
	ui.open_seek(); ui.seek_dialog.editor.text = "2.25"; ui.refresh()
	check(viewer.committed_sample == before and ui.requested.text.is_empty(),"Unsubmitted draft changes neither displayed nor requested time")
	ui.seek_dialog.hide()
	check(viewer.committed_sample == before and ui.pending_time() == null,"Cancel submits nothing")
	ui.open_seek(); ui.seek_dialog.editor.text = "NaN"; ui.submit_seek()
	check(ui.seek_dialog.visible and ui.seek_dialog.error_label.visible and viewer.committed_sample == before,"Invalid target retains draft and scene")
	ui.seek_dialog.editor.text = "99:00"; ui.submit_seek()
	check(ui.seek_dialog.error_label.visible and viewer.committed_sample == before,"Out of range target refused")
	ui.seek_dialog.hide(); viewer._seek_time(1.0000000000000002); await ready(viewer); ui.open_seek()
	check(ui.seek_dialog.editor.text == "00:01", "Precise scientific clock prefills whole seconds")
	# Native keyboard delivery is covered by test_violet_round2; this suite
	# stresses rapid same-frame requests through the production submit signal.
	ui.seek_dialog.editor.text_submitted.emit(ui.seek_dialog.editor.text); await settle()
	await ready(viewer)
	check(viewer.committed_sample.requested_time == 1.0000000000000002 and not ui.seek_dialog.visible,"Accepting unchanged whole-clock prefill preserves exact float64 target")
	ui.open_seek()
	ui.seek_dialog.editor.text = "2.5"
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	ui.seek_dialog.editor.gui_input.emit(escape)
	check(not ui.seek_dialog.visible and viewer.committed_sample.requested_time == 1.0000000000000002,"Escape dismisses without applying")
	ui.seek_dialog.hide()
	for time in [1.0,1.234567891234,2.25]:
		go(ui,ui.FloatText.format_value(time)); await ready(viewer)
		check(viewer.committed_sample.requested_time == time,"Go commits exact or fractional target " + str(time))
		check(ui.requested.text.is_empty() and ui.displayed.text == ui.format_duration(time),"Elapsed playback uses whole seconds from precise committed sample")
		check(ui.displayed.get_tooltip().is_empty() and ui.duration.get_tooltip().is_empty(),"Committed clocks remain tooltip-free")
	check(viewer.scene_layers.current.field.a.time == 1,"Sparse field holds independent source time at fractional seek")
	for index in [0,viewer.frame_count-1]:
		viewer.timeline.value = index;await ready(viewer);ui.refresh()
		check(viewer.current_index == index and viewer.committed_sample.requested_time == viewer.generic_reader.frames[index].time,"Endpoint seeks preserve exact recorded time/index")
	await media_checks(viewer,ui,config)
	go(ui,"2.25"); await ready(viewer)
	var camera: Transform3D = viewer.camera.transform
	ui.open_seek(); ui.seek_dialog.editor.grab_focus()
	for code in [KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_R]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = true; root.push_input(event)
	check(not viewer.playing and viewer.committed_sample.requested_time == 2.25 and viewer.camera.transform == camera,"Focused target suppresses viewport playback/camera shortcuts")
	ui.seek_dialog.hide()
	ui.refresh()
	ui.rate.item_selected.emit(ui.SPEEDS.find(2.0))
	check(viewer.physical_rate == 2,"Playback speed routes to canonical recorded-time rate")
	viewer.timeline.value = 1; await ready(viewer)
	check(viewer.current_index == 1 and viewer.committed_sample.requested_time == .5,"Slider selects a union timestamp")
	check(viewer.timeline.tooltip_text.contains("Sample index 2 / 8\n") and not ui.index_hint.visible,"Index count is available on hover without a persistent label")
	viewer.timeline.drag_started.emit(); ui.refresh(); await settle()
	check(ui.index_hint.visible and ui.index_hint.text == "Sample index 2 / 8","Dragging exposes the index hint")
	picture("index-drag")
	viewer.timeline.drag_ended.emit(false)
	check(not ui.index_hint.visible,"Index hint disappears on drag end")
	ui.actions.get_child(2).pressed.emit(); await ready(viewer)
	check(viewer.committed_sample.requested_time == 1,"Next selects next union sample")
	ui.actions.get_child(0).pressed.emit(); await ready(viewer)
	check(viewer.committed_sample.requested_time == .5,"Previous selects previous union sample")
	viewer.play_button.pressed.emit(); check(viewer.playing,"Play invokes existing controller")
	viewer.play_button.pressed.emit(); check(not viewer.playing,"Pause invokes existing controller")
	ui.refresh(); viewer.physical_rate = -.5; ui.refresh()
	check(viewer.physical_rate == -.5,"Recorded rate supports existing reverse behavior")
	go(ui,"2.25"); await ready(viewer); viewer.playing = true; viewer.scene_layers.tick(.1); await ready(viewer); viewer.playing = false
	check(viewer.committed_sample.requested_time < 2.25,"Reverse recorded playback moves backwards")
	ui.loop.button_pressed = true
	check(viewer.scene_loop_playback,"Loop control consumes existing loop behavior")
	viewer.physical_rate = 1; go(ui,"5.9"); await ready(viewer); viewer.playing = true; viewer.scene_layers.tick(.2); await ready(viewer); viewer.playing = false
	check(is_equal_approx(viewer.committed_sample.requested_time,.1),"Loop wraps recorded interval")
	ui.loop.button_pressed = false
	# Hold a real worker completion to prove draft/request/display separation and stale rejection.
	go(ui,"0"); await ready(viewer)
	var worker = viewer.scene_layers.playback.worker
	var gate := Semaphore.new(); worker.test_barrier = gate
	viewer.scene_layers.playback.invalidate(); viewer.manual_max += 1
	go(ui,"2.25123456789")
	var request_started := Time.get_ticks_msec()
	var deadline := Time.get_ticks_msec()+10000
	while not worker.status().get("test_barrier_waiting",false) and Time.get_ticks_msec()<deadline: await process_frame
	check(worker.status().get("test_barrier_waiting",false),"Real cold-seek publication barrier reached")
	viewer.playing = true
	for controller in [viewer.scene_layers.playback,viewer.scene_layers.field_playback,viewer.scene_layers.mesh_playback]:
		controller._update_ui()
		check(not viewer.play_button.disabled,"Layer readiness updates preserve active Pause while buffering")
	ui.refresh()
	check(not viewer.play_button.disabled and viewer.play_button.text == "Ⅱ" and viewer.play_button.tooltip_text == "Pause","Transport keeps Pause active while awaiting frames")
	viewer.play_button.pressed.emit(); ui.refresh()
	check(not viewer.playing and viewer.play_button.disabled,"Pause works during buffering; paused Play still waits for readiness")
	viewer._toggle_playback()
	check(not viewer.playing,"Buffered paused state cannot resume before readiness")
	ui.refresh()
	while not ui.requested.visible and Time.get_ticks_msec()-request_started < 2000: await process_frame
	request_delay_observed_ms = Time.get_ticks_msec()-request_started
	check(ui.requested.visible and request_delay_observed_ms >= ui.REQUESTED_DELAY_MS and request_delay_observed_ms < 1000,"Long real cold seek reveals status promptly after delay")
	check(ui.displayed.text == "00:00" and ui.playback_timing().elapsed == 0 and viewer.committed_sample.requested_time == 0 and ui.requested.text == "Requested time 00:02" and viewer.play_button.disabled,"Pending seek leaves displayed scene committed and exposes submitted target")
	check(ui.pending_time() == 2.25123456789 and not ui.requested.tooltip_text.contains(ui.FloatText.format_value(2.25123456789)),"Requested UI uses whole clock while controller retains exact submitted value")
	ui.show_remaining = true; ui.refresh()
	check(ui.duration.text == "-00:06","Cold seek remaining follows committed origin, not pending request")
	await settle(); picture("buffering")
	ui.open_seek(); ui.seek_dialog.editor.text = "00:04"; ui.refresh()
	check(ui.requested.text == "Requested time 00:02" and viewer.committed_sample.requested_time == 0,"Editing replacement target does not replace submitted request")
	ui.seek_dialog.confirmed.emit(); go(ui,"3.125")
	check(not ui.requested.visible and ui.requested.text.is_empty(),"Rapid replacements clear stale status immediately")
	worker.test_barrier = null; gate.post(); await ready(viewer)
	check(viewer.committed_sample.requested_time == 3.125 and ui.requested.text.is_empty(),"Only latest rapid seek commits and clears requested readout")
	check(ui.displayed.text == "00:03" and ui.duration.text == "-00:02","Latest committed seek updates elapsed and remaining")
	await settle(); picture("remaining")
	ui.show_remaining = false; ui.refresh()
	for i in 12: viewer.scene_layers.tick(0); await process_frame
	check(viewer.committed_sample.requested_time == 3.125,"Stale completions do not move clock backwards")
	var state := Visual.snapshot(viewer)
	Profile.enabled = true; Profile.reset()
	for i in 100: ui.refresh()
	var activity := Profile.report(); Profile.enabled = false
	check(activity.stages.is_empty() and activity.counters.is_empty() and Visual.snapshot(viewer)==state,"UI refresh causes no scientific/preparation/decode/upload activity or state changes")
	viewer.physical_rate = -.125; ui.refresh(); var saved := Visual.snapshot(viewer)
	viewer.physical_rate = 2; var sample_before: Dictionary = viewer.committed_sample.duplicate(true)
	Visual.apply(viewer,saved); ui.refresh()
	check(viewer.physical_rate == -.125 and ui.rate.selected == -1 and viewer.committed_sample == sample_before,"Recipe visual restoration updates rate silently without seek")
	ui.open_seek(); await settle()
	check(ui.seek_dialog.size.y < 240 and ui.seek_dialog.size.x < 360,"Seek remains a compact formatted-time popover")
	picture("seek")
	ui.seek_dialog.hide()
	for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
		root.size = dimensions; await settle(); viewer.shell.layout(); await settle()
		check(ui.get_global_rect().end.y == dimensions.y-viewer.shell.status_ui.size.y and ui.size.x == dimensions.x,"Transport fits native window " + str(dimensions))
		check(viewer.overlay_panel.get_rect().end.y <= ui.position.y,"Dock cannot cover persistent transport " + str(dimensions))
		check(ui.options.get_global_rect().end.x <= dimensions.x,"Speed/loop fit without clipping " + str(dimensions))
		check(ui.size.y == (64 if dimensions.x == 1440 else 104),"Transport height follows desktop/compact allocation " + str(dimensions))
		viewer._toggle_overlay(); await settle(); check(ui.is_visible_in_tree(),"Dock hide preserves transport"); viewer._toggle_overlay(); await settle()
		check(ui.displayed.get_global_rect().end.x <= viewer.timeline.get_global_rect().position.x and viewer.timeline.get_global_rect().end.x <= ui.duration.get_global_rect().position.x,"Elapsed and total flank the union slider")
		var radius: float = viewer.timeline.get_theme_icon("grabber").get_width()*.5
		check(viewer.timeline.get_global_rect().position.x-ui.displayed.get_global_rect().end.x >= radius and ui.duration.get_global_rect().position.x-viewer.timeline.get_global_rect().end.x >= radius,"Endpoint thumb has room beside time readouts")
		var first: Rect2 = ui.primary.get_global_rect()
		var last: Rect2 = ui.secondary.get_global_rect() if ui.compact else first
		check(absf((first.position.y-ui.global_position.y)-(ui.get_global_rect().end.y-last.end.y)) <= 1,"Transport rows have equal top and bottom space")
		check(absf(viewer.timeline.get_global_rect().get_center().y-ui.displayed.get_global_rect().get_center().y) <= 1 and absf(viewer.timeline.get_global_rect().get_center().y-ui.duration.get_global_rect().get_center().y) <= 1,"Slider and both time readouts share a vertical center")
		var stable := [ui.get_global_rect(),ui.actions.get_global_rect(),viewer.timeline.get_global_rect(),ui.options.get_global_rect()]
		var controller = viewer.scene_layers.playback
		var prior_buffering: bool = controller.buffering; var prior_pending = controller.pending_time
		for pending_value in [121.0,999999.99999,null]:
			controller.buffering = pending_value != null; controller.pending_time = pending_value
			ui.refresh()
			if pending_value != null: await create_timer(float(ui.REQUESTED_DELAY_MS+50)/1000).timeout
			await settle(); viewer.shell.layout(); await settle()
			check(ui.requested.visible == (pending_value != null),"Layout stress keeps the requested readout present until cleared")
			check(stable == [ui.get_global_rect(),ui.actions.get_global_rect(),viewer.timeline.get_global_rect(),ui.options.get_global_rect()],"Requested readout does not move or resize transport controls")
			if pending_value != null:
				check(ui.requested.get_global_rect().end.y <= (ui.secondary.get_global_rect().position.y if ui.compact else ui.get_global_rect().end.y),"Requested readout fits without overlapping the next row")
				picture("pending-layout-"+str(dimensions.x))
		controller.buffering = prior_buffering; controller.pending_time = prior_pending; ui.refresh()
		layouts.append({"window":str(dimensions),"transport":str(ui.get_rect())}); picture("loaded-"+str(dimensions.x))
		await typography_layouts(ui, dimensions.x)
	viewer._toggle_fullscreen(); await settle()
	check(viewer.shell.immersive and not ui.is_visible_in_tree() and not viewer.shell.status_ui.is_visible_in_tree(),"Fullscreen hides combined media strip")
	viewer._toggle_fullscreen(); await settle()
	if not config.real.is_empty():
		viewer._open_capture(config.real); viewer.playing = false; await ready(viewer)
		var time: float = lerpf(viewer.generic_reader.frames[0].time,viewer.generic_reader.frames[-1].time,.37)
		go(ui,ui.FloatText.format_value(time)); await ready(viewer)
		check(viewer.committed_sample.requested_time == time,"Frozen real capture fractional seek")
		await settle(); picture("real-capture")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"layouts":layouts,"request_delay_observed_ms":request_delay_observed_ms,"refresh_activity":activity},"\t")); file.close()
	viewer.free(); await process_frame
	print("TRANSPORT: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)

func typography_layouts(ui, width: int):
	# Presentation-only long clocks: real seek/toggle/timing are covered above.
	var processing: bool = ui.is_processing(); ui.set_process(false)
	for pair in [["00:00","00:06"],["01:45","12:43"],["01:04:27","10:00:00"],["01:04:27","-08:55:33"]]:
		ui.displayed.text = pair[0]; ui.duration.text = pair[1]
		await settle(); ui.shell.layout(); await settle()
		check(ui.displayed.get_global_rect().end.x < ui.viewer.timeline.global_position.x and ui.viewer.timeline.get_global_rect().end.x < ui.duration.global_position.x,"Clock widths preserve slider clearance: "+str(pair)+" at "+str(width))
		check(ui.duration.get_global_rect().end.x <= ui.rate.global_position.x and ui.rate.get_global_rect().end.x <= ui.get_global_rect().end.x,"Long clocks leave speed control inside transport at "+str(width))
		check(ui.size.y == (64 if width == 1440 else 104),"Shared typography preserves transport height at "+str(width))
		picture("typography-"+str(width)+"-"+str(pair[1]).replace(":","-"))
	ui.set_process(processing); ui.refresh(); await settle()

func media_checks(viewer, ui, config):
	go(ui,"0"); await ready(viewer); ui.refresh()
	check(ui.displayed.text == "00:00","Recorded playback begins at zero elapsed")
	var total: float = 6.0
	check(is_equal_approx(ui.playback_timing().total,total),"Recorded playback nominal duration follows existing normal rate")
	ui.duration.pressed.emit()
	check(ui.show_remaining and ui.duration.text == ui.format_duration(total,true),"Recorded playback duration toggles to negative remaining")
	ui.duration.pressed.emit()
	check(not ui.show_remaining and ui.duration.text == ui.format_duration(total),"Recorded playback duration toggles back to total")
	for speed in [-2.0,-0.5,0.0,0.5,1.0,2.0]:
		go(ui,"2.25"); await ready(viewer); ui.refresh()
		var before: float = ui.playback_timing().elapsed
		check(is_equal_approx(before,2.25),"Recorded playback fractional seek maps committed position")
		viewer.physical_rate = speed; ui.refresh()
		check(is_equal_approx(viewer.physical_rate,speed),"Recorded playback multiplier maps to existing rate "+str(speed))
		viewer.playing = true; viewer.scene_layers.tick(.05); await ready(viewer); viewer.playing = false; ui.refresh()
		check(is_equal_approx(ui.playback_timing().elapsed,before+.05*speed),"Recorded playback speed affects actual committed motion "+str(speed))
		check(is_equal_approx(ui.playback_timing().total,total),"Recorded playback duration stays stable during playback and speed edits")
	go(ui,"6"); await ready(viewer); ui.refresh()
	check(ui.displayed.text == ui.duration.text,"Recorded playback end elapsed equals total")
	ui.duration.pressed.emit(); check(ui.duration.text == "00:00","Recorded playback remaining ends at zero without negative zero")
	ui.duration.pressed.emit()
	check(not Visual.snapshot(viewer).has("time_mode") and not Visual.snapshot(viewer).has("playback_fps"),"Snapshots contain no obsolete playback-mode fields")
	check(not viewer.visual_sliders.has("Playback • frames / second (index mode)"),"Obsolete index-rate control is not constructed")
	# An unchanged multiplier must never round-trip or alter an arbitrary saved rate.
	viewer.physical_rate = 0.12345678912345678; ui.refresh()
	var exact: float = viewer.physical_rate
	ui.refresh(); check(viewer.physical_rate == exact and ui.rate.selected == -1,"Preset selector preserves an arbitrary exact controller rate")
	var saved := Visual.snapshot(viewer); viewer.physical_rate = 12; Visual.apply(viewer,saved); ui.refresh()
	check(viewer.physical_rate == exact and ui.rate.selected == -1,"Recipe restores original exact recorded rate without redefining it")
	for path in [config.offset,config.single]:
		viewer._open_capture(path); viewer.playing = false; await ready(viewer)
		check(ui.displayed.text == "00:00","Nonzero source origin still begins at zero elapsed")
		go(ui,ui.FloatText.format_value(float(viewer.generic_reader.frames[-1].time))); await ready(viewer)
		check(ui.displayed.text == ui.duration.text,"Offset/single-sample capture ends at total")
		ui.duration.pressed.emit(); check(ui.duration.text == "00:00","Offset/single-sample remaining reaches zero")
		ui.duration.pressed.emit()
		check(ui.displayed.get_tooltip().is_empty() and ui.displayed.text == ui.format_duration(ui.playback_timing().elapsed), "Offset source units retain a tooltip-free whole-clock readout")
	viewer._open_capture(config.source); viewer.playing = false; await ready(viewer)

func delay_checks(viewer, ui):
	go(ui,"0.5")
	var cached_flashed: bool = ui.requested.visible
	var cached_started := Time.get_ticks_msec()
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec()-cached_started < 2000:
		await process_frame; viewer.scene_layers.tick(0); cached_flashed = cached_flashed or ui.requested.visible
	ui.refresh()
	check(not cached_flashed and not ui.requested.visible and viewer.committed_sample.requested_time == .5,"Cached seek commits without transient label")
	go(ui,"0"); await ready(viewer)
	ui.reset_requested()
	ui.refresh_requested(1.0,0.0,1000)
	check(not ui.requested.visible,"New request status starts hidden")
	ui.refresh_requested(1.0,0.0,1449)
	check(not ui.requested.visible,"Request remains hidden just below threshold")
	ui.refresh_requested(1.0,0.0,1450)
	check(ui.requested.visible,"Request appears at threshold")
	ui.refresh_requested(2.0,0.0,1451)
	check(not ui.requested.visible and ui.requested.text.is_empty(),"Replacement resets delay and stale text")
	ui.refresh_requested(2.0,0.0,1901)
	check(ui.requested.visible and ui.requested.text == "Requested time 00:02","Replacement shows only latest target")
	ui.pending_generation = -1; ui.refresh_requested(2.0,0.0,1902)
	check(not ui.requested.visible,"Changed capture generation restarts presentation delay")
	ui.refresh_requested(2.0,0.0,2352)
	ui.refresh_requested(null,0.0,2353)
	check(not ui.requested.visible,"Cancellation clears the label")
	ui.refresh_requested(2.0,0.0,2000); ui.refresh_requested(2.0,2.0,2450)
	check(not ui.requested.visible,"Commit clears the label")
	var controller = viewer.scene_layers.playback
	for duration_ms in [100,350]:
		controller.buffering = true; controller.pending_time = 1.0; ui.refresh()
		var began := Time.get_ticks_msec(); var flashed := false
		while Time.get_ticks_msec()-began < duration_ms:
			await process_frame; flashed = flashed or ui.requested.visible
		controller.buffering = false; controller.pending_time = null; ui.refresh()
		check(not flashed and not ui.requested.visible,"Native short wait stays hidden: "+str(duration_ms)+" ms")
	controller.buffering = true; controller.pending_time = 1.0; ui.refresh()
	await create_timer(.55).timeout
	check(ui.requested.visible,"Native 550 ms wait displays status")
	controller.readiness_error = "Injected preparation failure"; ui.refresh()
	check(not ui.requested.visible and ui.requested.text.is_empty(),"Published preparation failure clears transient status")
	controller.readiness_error = ""; controller.buffering = false; controller.pending_time = null; ui.refresh()

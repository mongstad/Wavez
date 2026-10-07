extends SceneTree
# Presentation snapshots plus the production Details/dialog and real worker.
const Details = preload("res://video/progress_details.gd")
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
class DelayedExport extends "res://video/export_dialog.gd":
	var delay_ms := 0
	func configured_job() -> Dictionary:
		var job := super.configured_job()
		job.test_frame_delay_ms = delay_ms
		return job
var checks: Array = []
var measurements := {}
var out := ""
var view
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok: push_error(label)
func snapshot(frame := 3000.0, seconds := 100.0, ticks := 1000) -> Dictionary:
	return {"job":"first","stage":"rendering","snapshot_ticks":ticks,"progress_ticks":ticks,"elapsed_seconds":seconds,
		"progress":{"current_frame":frame,"total_frames":12000.0,"elapsed_seconds":seconds},"output":"/exports/movie.mp4","directory":"/exports/job"}
func eta(text: String) -> String: return text.split("\n")[2]
func seconds_left(text: String) -> int:
	var value := eta(text).trim_prefix("Estimated remaining: ").split(":")
	return int(value[0])*3600+int(value[1])*60+int(value[2])
func snapshots() -> void:
	var presentation := Details.new()
	var state := snapshot()
	var original := state.duplicate(true)
	var initial := presentation.present(state,1000)
	check(initial.contains("Elapsed: 00:01:40\nEstimated remaining: 00:05:00"),"Initial estimate uses observed frames/time")
	for now in range(1000,11000,10):
		var text: String = presentation.present(state,now)
		check(eta(text) == eta(initial),"Unchanged frame snapshot has stable ETA at "+str(now))
	check(presentation.present(state,3000).contains("Elapsed: 00:01:42"),"Live elapsed keeps advancing independently")
	check(state == original,"Presentation leaves published progress untouched")
	check(eta(presentation.present(state,11001)).contains("no recent frame progress"),"Stalled progress suppresses ETA immediately")
	state = snapshot(3001,111,11002)
	check(not eta(presentation.present(state,11002)).contains("Unavailable"),"Fresh frame progress recovers after stall")
	presentation = Details.new()
	var previous := ""; var previous_raw := ""; var changed: Array = []; var raw_changes := 0
	for i in 6000:
		# Thousands of fast, jittering frame publications, polled twice by consumers.
		var now := 1000+i*10
		state = snapshot(3000+i,100+i*.01+(0.004 if i%2 else 0),now)
		var text: String = presentation.present(state,now)
		var remaining := eta(text)
		if remaining != previous:
			changed.append(now); previous = remaining
		check(eta(presentation.present(state,now,true)) == remaining,"Dialog/Details share estimate "+str(i))
		var raw_text := Details.format(state,now)
		check(text.replace(remaining,"ETA") == raw_text.replace(eta(raw_text),"ETA"),"Only ETA changes in formatted snapshot "+str(i))
		var raw := eta(raw_text)
		if raw != previous_raw:raw_changes += 1;previous_raw = raw
	for i in range(1,changed.size()):check(changed[i]-changed[i-1] >= 500,"Visible ETA changes respect 500 ms minimum "+str(i))
	check(changed.size() < raw_changes,"Smoothed display reduces raw ETA replacements")
	measurements.fast_publications = {"snapshots":6000,"raw_changes":raw_changes,"visible_changes":changed.size(),"minimum_interval_ms":500}
	# Sustained cost changes: substantial response in one smoothing window.
	for cost in [.1,.01]:
		presentation = Details.new();state = snapshot(1000,50,1000)
		var before := seconds_left(presentation.present(state,1000))
		var frame := 1000.0;var elapsed := 50.0
		for i in 50:
			elapsed += .1;frame += .1/cost
			state = snapshot(frame,elapsed,1100+i*100)
			presentation.present(state,1100+i*100)
		var after := seconds_left(presentation.present(state,6100))
		check(after > before*1.5 if cost == .1 else after < before*.6,"Throughput shift responds within five seconds: "+str(cost))
		measurements[str(cost)] = {"before_seconds":before,"after_seconds":after}
	for stage in ["starting","loading","preparing","encoding","cancelling","failed","cancelled","complete","frames_ready"]:
		presentation = Details.new();state = snapshot();presentation.present(state,1000)
		state.stage = stage
		var text: String = presentation.present(state,1001)
		check(eta(text).ends_with("00:00:00") if stage in ["complete","frames_ready"] else eta(text).contains("Unavailable"),"Stage bypasses ETA throttle: "+stage)
		if stage in Details.TERMINAL:check(text == presentation.present(state,999999),"Terminal time freezes: "+stage)
	presentation = Details.new();state = snapshot();presentation.present(state,1000)
	state.job = "second";state.progress.current_frame = 100;state.progress.elapsed_seconds = 10;state.elapsed_seconds = 10
	check(seconds_left(presentation.present(state,1001)) == 1190,"New job never inherits old rate/ETA")
	state = snapshot();presentation.present(state,2000)
	for counts in [[0,0],[-1,10],[11,10],[0,-10],[0,NAN],[INF,10],[1.5,10]]:
		state.progress.current_frame = counts[0];state.progress.total_frames = counts[1]
		check(presentation.present(state,2001).begins_with("Rendering — frame count unavailable") and eta(presentation.present(state,2001)).ends_with("Unavailable"),"Invalid counts clear cached ETA: "+str(counts))
	for reset in ["total","frame","time"]:
		presentation = Details.new();state = snapshot();presentation.present(state,1000)
		if reset == "total":state.progress.total_frames = 24000
		elif reset == "frame":state.progress.current_frame = 100;state.progress.elapsed_seconds = 10
		else:state.progress.elapsed_seconds = 50
		check(seconds_left(presentation.present(state,1001)) == {"total":700,"frame":1190,"time":150}[reset],"Changed/regressing progress resets cached estimate immediately: "+reset)
	for count in [0,1]:
		state = snapshot(count,.5,2000)
		check(eta(presentation.present(state,2001)).contains("Waiting"),"Initial progress waits: "+str(count))
	state = snapshot();state.progress.elapsed_seconds = NAN
	check(eta(presentation.present(state,2001)).ends_with("Unavailable"),"Invalid observed time clears estimate")
	check(Details.duration(360005) == "100:00:05","Long estimates retain hours beyond 24")
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	snapshots()
	var config_path := out.path_join("config.json")
	if FileAccess.file_exists(config_path):await integration(JSON.parse_string(FileAccess.get_file_as_string(config_path)))
	Job.write_json(out.path_join("report.json"),{"checks":checks,"measurements":measurements})
	var failed := checks.any(func(item):return not item.ok)
	if view != null:view.queue_free();await process_frame;await process_frame
	quit(1 if failed else 0)
func integration(config: Dictionary) -> void:
	view = Viewer.new();view.capture_path = config.source;view.scene_prebuffer_enabled = false
	view.playing = false;view.orbit_enabled = false;root.add_child(view);await process_frame
	check(view.frame_a != null,"Production viewer opens synthetic capture")
	check(OS.has_feature("editor") != config.packaged,"Expected development/release executable")
	var ui = view.shell.status_ui
	view.video_dialog.queue_free();await process_frame
	var dialog := DelayedExport.new();dialog.viewer = view;dialog.delay_ms = int(config.get("delay_ms",0))
	view.video_dialog = dialog;view.add_child(dialog);dialog.job_changed.connect(ui.video_changed)
	# High-call-rate actual UI: no text replacement when formatted content is equal.
	dialog.active_job_path = "first";dialog.preparing = true
	dialog.job_status = snapshot(3000,100,Time.get_ticks_msec()+10000)
	ui.open_job_details("Video export");await process_frame
	var text: TextEdit = view.shell.detail_text
	var version := text.get_version()
	var current_text := text.text
	for i in 1000:ui.refresh();dialog._update_status_summary()
	check(text.get_version() == version and text.text == current_text,"1,000 duplicate refreshes do not replace Details text")
	check(eta(dialog.message.text) == eta(text.text),"Dialog and actual Details show the same estimate")
	view.shell.details.hide();dialog.preparing = false;dialog.job_status = {};dialog.active_job_path = ""
	var menu: Dictionary = view.shell.commands.video;menu.popup.id_pressed.emit(menu.index)
	dialog.range_choice.select(2);dialog.update_range();dialog.start.value = 0;dialog.end.value = 2
	dialog.width.value = 320;dialog.height.value = 180;dialog.fps.value = 60 if config.get("long",false) or config.get("cancel","") == "rendering" else 4;dialog.rate.value = 1
	dialog.overlays.button_pressed = false;dialog.inspection_sidecars.button_pressed = false
	dialog.output.text = out.path_join("result.mp4")
	view.file_locations.settings.ffmpeg_mode = "custom";view.file_locations.settings.ffmpeg_path = config.ffmpeg
	dialog.start_button.pressed.emit();check(dialog.pid > 0,"Production Start launches worker")
	if dialog.pid <= 0:return
	var pid: int = dialog.pid
	Job.write_json(out.path_join("launched.json"),{"pid":pid,"directory":dialog.active_directory})
	dialog.background_button.pressed.emit();check(not dialog.visible and dialog.pid == pid,"Background keeps original worker")
	ui.open_job_details("Video export")
	var began := Time.get_ticks_msec();var deadline := began+260000
	var stages: Array = [];var samples: Array = [];var previous := "";var eta_changes: Array = []
	var reopened := false;var cancelled := false;var captured := false;var saw_eta := false
	while dialog.pid > 0 and Time.get_ticks_msec()<deadline:
		var stage := str(dialog.job_status.get("stage",""))
		if stage not in stages:stages.append(stage)
		var now := Time.get_ticks_msec()
		var detail: String = dialog.progress_details()
		if stage == "rendering":
			var value := eta(detail)
			if value != previous:
				eta_changes.append({"ticks":now,"value":value});previous = value
			if not value.contains("Waiting") and not value.contains("Unavailable"):
				saw_eta = true
				if not captured:
					await process_frame;RenderingServer.force_draw(false)
					view.shell.details.get_texture().get_image().save_png(out.path_join("live-details.png"));captured = true
			if not reopened and now-began > 1500:
				view.shell.details.hide();ui.open_jobs();ui.reopen_video()
				check(dialog.visible and dialog.pid == pid,"Jobs reopens same running export")
				dialog.hide();ui.jobs_dialog.hide();ui.open_job_details("Video export");reopened = true
		if stage == "encoding":check(eta(detail).contains("Unavailable while encoding"),"Encoding immediately removes render ETA")
		if not cancelled and stage == config.get("cancel",""):
			view.shell.details.hide();ui.open_jobs();ui.job_rows["Video export"].cancel.pressed.emit()
			check(dialog.cancel_confirmation.visible,"Cancellation uses production confirmation")
			dialog.cancel_confirmation.confirmed.emit();cancelled = true
			dialog.hide();ui.jobs_dialog.hide()
		samples.append({"ticks":now,"stage":stage,"details":detail,"progress":dialog.last_progress.duplicate(true)})
		await create_timer(.05).timeout
	check(dialog.pid <= 0,"Real worker terminates within deadline")
	check(dialog.job_status.stage == config.get("expected","complete"),"Expected terminal stage")
	check(not config.get("long",false) or Time.get_ticks_msec()-began >= 180000,"Long export observed for at least three minutes")
	check(not config.get("long",false) or saw_eta,"Long export exposes numeric ETA")
	ui.refresh();var terminal: String = dialog.progress_details()
	await create_timer(.6).timeout;ui.refresh()
	check(dialog.progress_details() == terminal,"Terminal presentation stays frozen")
	check(eta(terminal).ends_with("00:00:00") if dialog.job_status.stage == "complete" else eta(terminal).ends_with("Unavailable"),"Terminal ETA is appropriate")
	check(FileAccess.file_exists(dialog.output.text) == (dialog.job_status.stage == "complete"),"MP4 publication matches terminal state")
	for i in range(1,eta_changes.size()):
		if eta_changes[i].value.contains("Waiting") or eta_changes[i-1].value.contains("Waiting"):continue
		check(eta_changes[i].ticks-eta_changes[i-1].ticks >= 450,"Sampled real ETA changes stay below 2 Hz (50 ms sampling tolerance)")
	ui.open_job_details("Video export");await process_frame;RenderingServer.force_draw(false)
	view.shell.details.get_texture().get_image().save_png(out.path_join("terminal-details.png"))
	measurements.integration = {"runtime_ms":Time.get_ticks_msec()-began,"stages":stages,"eta_changes":eta_changes,"directory":dialog.active_directory,"progress":dialog.last_progress,"details":terminal,"samples":samples}

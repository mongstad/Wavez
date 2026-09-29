extends SceneTree
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
const Hash = preload("res://data/capture_index.gd")
var output := ""
var checks := 0
var failures := []
var phases := {}
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)
func picture() -> String:return Hash.digest(root.get_texture().get_image().get_data())
func settle() -> void:await create_timer(.3).timeout
func ready(view) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 10000:
		await process_frame
		var fields = view.scene_layers.field_playback
		if not view.scene_layers.is_buffering() and (not fields.active() or fields.worker.status().session.get("state") == "ready"):break
	check(not view.scene_layers.is_buffering(),"Requested scene becomes ready")
	await settle()
func idle(view, label: String, stable_ui := true) -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null:focus.release_focus()
	await settle()
	var frames := Engine.get_frames_drawn();var callbacks := Engine.get_process_frames()
	var before := picture();var sample: Dictionary = view.committed_sample.duplicate(true);var camera: Transform3D = view.camera.transform
	await create_timer(1.2).timeout
	var draws := Engine.get_frames_drawn()-frames
	phases[label] = {"draws":draws,"callbacks":Engine.get_process_frames()-callbacks,"same_pixels":before == picture()}
	check(OS.low_processor_usage_mode,label+" redraw-on-change enabled")
	check(draws <= 4,label+" unchanged scene does not continuously draw: "+str(draws))
	check(phases[label].callbacks >= 20,label+" callbacks remain responsive")
	if stable_ui:check(before == picture(),label+" stable paused image")
	check(sample == view.committed_sample and camera == view.camera.transform,label+" scientific clock and camera unchanged")
	# Compare the retained presentation with a fresh render of the exact same state.
	var retained := picture()
	RenderingServer.force_draw(false)
	check(retained == picture(),label+" retained image equals forced full-quality render")
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	root.title = "SimScope #118 automated regression"
	var initial_mode := OS.low_processor_usage_mode;var initial_fps := Engine.max_fps
	OS.low_processor_usage_mode = false;Engine.max_fps = 0
	for kind in ["particles","field","mesh","mixed"]:
		var view = Viewer.new();view.playing = false;view.orbit_enabled = false;view.capture_path = output.path_join(kind+".ssc")
		root.add_child(view);await ready(view)
		check(view.generic_reader != null,kind+" opens")
		await idle(view,kind+"_ready")
		var time: float = view.committed_sample.requested_time
		view.play_button.pressed.emit();await create_timer(.5).timeout
		check(view.playing and not OS.low_processor_usage_mode,kind+" playback restores normal rendering")
		check(Engine.max_fps == 0,kind+" playback restores previous frame cap")
		check(view.committed_sample.requested_time > time,kind+" playback advances")
		view.play_button.pressed.emit();await ready(view);await idle(view,kind+"_paused_again")
		check(view.scene_layers.seek(1.5),kind+" paused seek accepted")
		await ready(view);check(view.committed_sample.requested_time == 1.5,kind+" paused seek commits exact target")
		await idle(view,kind+"_seek")
		var old: Transform3D = view.camera.transform;var frames := Engine.get_frames_drawn()
		view.dragging = true;view.last_mouse = Vector2.ZERO
		var motion := InputEventMouseMotion.new();motion.position = Vector2(40,20);view._unhandled_input(motion);view.dragging = false
		await settle()
		check(view.camera.transform != old and Engine.get_frames_drawn() > frames,kind+" camera drag redraws immediately")
		view.orbit_enabled = true;old = view.camera.transform;await settle()
		check(not OS.low_processor_usage_mode and view.camera.transform != old,kind+" intentional orbit continues to render")
		check(Engine.max_fps == 60,kind+" paused orbit has a bounded presentation rate")
		var yaw: float = view.yaw;var started := Time.get_ticks_usec();frames = Engine.get_frames_drawn()
		await create_timer(.5).timeout
		var wall := (Time.get_ticks_usec()-started)/1000000.0
		check(absf((view.yaw-yaw)-view.orbit_speed*wall) < .003,kind+" orbit speed remains tied to elapsed time")
		check((Engine.get_frames_drawn()-frames)/wall <= 65,kind+" paused orbit bounds actual draws")
		var speed: float = view.orbit_speed;view.orbit_speed = 0
		await idle(view,kind+"_zero_speed_orbit");view.orbit_speed = speed
		view.orbit_enabled = false;await idle(view,kind+"_after_orbit")
		view.free_camera = true;await idle(view,kind+"_free_camera_stationary");view.free_camera = false
		frames = Engine.get_frames_drawn();view.tools_ui.open("Performance");await settle()
		check(Engine.get_frames_drawn() > frames,kind+" tool opens visibly while paused")
		# Live diagnostics can legitimately change once as resource usage settles.
		await idle(view,kind+"_performance",false)
		view.tools_ui.close();await settle()
		if view.scene_layers.views.has("field"):
			var choice: OptionButton = view.scene_layers.panel_controls.field.channel
			choice.select(1);choice.item_selected.emit(1);await ready(view)
			check(view.scene_layers.views.field.channel == choice.get_item_metadata(1),kind+" channel change commits")
			await idle(view,kind+"_channel")
			# #137 starts legends hidden. Exercise a real on -> off transition.
			view.scene_layers.panel_controls.field.legend.button_pressed = true;await settle()
			frames = Engine.get_frames_drawn();view.scene_layers.panel_controls.field.legend.button_pressed = false;await settle()
			check(Engine.get_frames_drawn() > frames and not view.shell.layer_legends.entries.has("field"),kind+" legend toggle redraws")
			view.scene_layers.panel_controls.field.legend.button_pressed = true;await settle()
			check(view.shell.layer_legends.entries.has("field"),kind+" legend restored")
		var size := root.size;frames = Engine.get_frames_drawn();root.size = size+Vector2i(32,24);await settle()
		check(Engine.get_frames_drawn() > frames,kind+" resize redraws")
		root.size = size;await idle(view,kind+"_resized")
		view.free();await process_frame
		check(not OS.low_processor_usage_mode,kind+" teardown restores previous engine policy")
		check(Engine.max_fps == 0,kind+" teardown restores previous frame cap")
	# An offline instance must neither install nor overwrite the process policy.
	for mode in [false,true]:
		OS.low_processor_usage_mode = mode
		var offline = Viewer.new();offline.offline_instance = true;root.add_child(offline);await settle()
		check(OS.low_processor_usage_mode == mode,"Offline viewer preserves existing redraw policy "+str(mode))
		offline.free();await process_frame
		check(OS.low_processor_usage_mode == mode,"Offline teardown preserves existing redraw policy "+str(mode))
	for limit in [24,120]:
		Engine.max_fps = limit;OS.low_processor_usage_mode = false
		var limited = Viewer.new();limited.playing = false;limited.orbit_enabled = true;root.add_child(limited);await settle()
		check(Engine.max_fps == mini(limit,60),"Paused orbit honors a lower existing cap "+str(limit))
		limited.playing = true;await settle()
		check(Engine.max_fps == limit,"Playback restores supplied cap "+str(limit))
		limited.free();await process_frame
		check(Engine.max_fps == limit,"Teardown restores supplied cap "+str(limit))
	OS.low_processor_usage_mode = initial_mode;Engine.max_fps = initial_fps
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"phases":phases})
	print("RENDER PACING: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

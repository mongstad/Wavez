extends SceneTree
const Preset = preload("res://scene/view_preset.gd")
const Visual = preload("res://scene/visual_state.gd")
const Profile = preload("res://scene/playback_profile.gd")
var checks := 0
var failures := []
var timings := []
var output := ""
var view
var frame_times := []
var last_frame := 0
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok:failures.append(label);push_error(label)
func settle():
	for i in 5:await process_frame
func protected() -> Dictionary:
	var sample: Dictionary = view.committed_sample.duplicate(true)
	# Render provenance must follow the newly applied presentation; source sampling must not.
	for layer in sample.get("layers",[]):
		for key in ["opacity_mapping","color_mapping","color_bounds"]:layer.erase(key)
	return {"sample":sample,"time":view.requested_time,"playing":view.playing,
	"selection":view.selection_controller.state.snapshot(),"jobs":view.selection_controller.jobs.serial,
	"revision":view.selection_controller.temporal.revision,"panel":view.overlay_visible,"width":view.panel_width,
	"sections":Visual.snapshot(view).sections,"objects":view.scene_layers.selected_objects.duplicate(),
	"channels":view.scene_layers.states.values().map(func(s):return s.channel),"particle_channel":view.color_channel}
func configure():
	view.point_scale = 1.25;view.exposure = 1.7;view.orbit_enabled = false;view.show_legend = true
	view.colormap_name = "plasma";view.camera_distance = 9;view.yaw = .5;view.pitch = -.2;view.camera_target = Vector3(2,3,4);view._update_camera()
	view.environment.glow_enabled = true;view.environment.fog_enabled = true;view.environment.fog_density = .02
	var layers = view.scene_layers
	var id: String = layers.selected_objects.get("volume","")
	if not id.is_empty():
		layers.states[id].opacity = .7;layers.states[id].step = .75;layers.states[id].lower = .1;layers.states[id].upper = 5.
		layers.states[id].opacity_mapping = {"mode":"magnitude","lower":.2,"upper":4.}
		layers.legend_visibility[id] = true
	var mesh: String = layers.selected_objects.get("mesh","")
	if not mesh.is_empty():layers.states[mesh].wireframe = true
func run():
	create_timer(120).timeout.connect(func():push_error("Preset test timed out");quit(1))
	var args = OS.get_cmdline_user_args();output = args[0]
	var production: String = args[1] if args.size()>1 else ""
	view = load("res://main.gd").new();view.scene_prebuffer_enabled = false;root.add_child(view);view.set_process(false)
	view._open_capture(output.path_join("scene.wvz") if production.is_empty() else production);view.playing = false;view.orbit_enabled = false
	await settle();check(view.generic_reader != null,"capture opens")
	configure()
	view.playing = true # main processing is disabled; check transport intent survives
	var expected := Preset.snapshot(view)
	var before := protected()
	var path := output.path_join("chosen-name.json")
	process_frame.connect(record_frame)
	var baseline_nodes := get_node_count()
	var bytes := 0
	for cycle in 12:
		Profile.enabled = true;Profile.reset()
		var begin := Time.get_ticks_usec()
		check(view._save_inspection(path) == OK,"save cycle "+str(cycle))
		var saved_ms := (Time.get_ticks_usec()-begin)/1000.0
		check(Profile.report().counters.get("identity_hash_calls",0) == 0 and Profile.report().stages.is_empty(),"save performs no scientific preparation/hash work")
		check(protected() == before,"save preserves playback, source and shell state")
		view.exposure = .8;view.camera_distance = 5;view.show_legend = false
		view.point_scale = .5;view.gamma = .5;view.brightness_scale = 2.;view.free_camera = true;view.orbit_enabled = true
		view.colormap_name = "viridis";view.camera.fov = 70
		view.environment.glow_enabled = false;view.environment.fog_density = .001
		var volume_id := Preset.selected(view,"volume")
		if not volume_id.is_empty():
			var state: Dictionary = view.scene_layers.states[volume_id]
			state.opacity = .1;state.step = .25;state.lower = 0.;state.upper = 1.
			state.opacity_mapping = {"mode":"linear","lower":0.,"upper":1.}
			view.scene_layers.legend_visibility[volume_id] = false
		var mesh_id := Preset.selected(view,"mesh")
		if not mesh_id.is_empty():view.scene_layers.states[mesh_id].wireframe = false
		begin = Time.get_ticks_usec()
		var error: String = view._load_inspection(path)
		check(error.is_empty(),"load cycle "+str(cycle)+": "+error)
		var load_ms := (Time.get_ticks_usec()-begin)/1000.0
		check(Profile.report().counters.get("identity_hash_calls",0) == 0,"load performs no source hash")
		Profile.enabled = false
		check(is_equal_approx(view.exposure,1.7) and is_equal_approx(view.camera_distance,9),"presentation and camera restored")
		check(protected() == before,"load preserves time, selections, jobs and shell layout")
		# Compare every documented field after the JSON round trip; renderer may skip unsupported quality.
		var actual := Preset.snapshot(view)
		for group in expected.settings:
			if group == "particles" and view.scene_layers.particle_id.is_empty():continue
			if group == "quality" and RenderingServer.get_current_rendering_method() == "gl_compatibility":continue
			for key in expected.settings[group]:check(same(expected.settings[group][key],actual.settings[group][key]),"roundtrip "+group+"."+key)
		var frame_begin := Time.get_ticks_usec();await settle()
		timings.append({"save_callback_ms":saved_ms,"save_total_ms":saved_ms,"load_apply_ms":load_ms,"five_frames_ms":(Time.get_ticks_usec()-frame_begin)/1000.0})
		if cycle == 0:baseline_nodes = get_node_count() # enabled legend cards are created once
		before = protected()
	check(get_node_count() == baseline_nodes,"repeated save/load does not accumulate nodes")
	var text := FileAccess.get_file_as_string(path);bytes = text.to_utf8_buffer().size()
	check(bytes < 16384,"preset is small")
	for forbidden in ["capture_path","requested_time","panel_width","overlay_visible","selection","source_time","source_channel","object_id","channel_preferences"]:
		check(not text.contains('"'+forbidden+'"'),"no source/shell field "+forbidden)
	var stored = JSON.parse_string(text)
	var stable := Visual.snapshot(view);before = protected()
	var obsolete: Dictionary = stored.duplicate(true);obsolete.kind = "simscope-view-preset"
	write_text(output.path_join("bad.json"),JSON.stringify(obsolete))
	check(not view._load_inspection(output.path_join("bad.json")).is_empty(),"Old preset kind is refused")
	write_text(output.path_join("bad.json"),'{"kind":"broken"}')
	check(not view._load_inspection(output.path_join("bad.json")).is_empty(),"malformed preset reported")
	var bad: Dictionary = stored.duplicate(true);bad.settings.view.exposure = "wrong type"
	write_text(output.path_join("bad.json"),JSON.stringify(bad))
	check(not view._load_inspection(output.path_join("bad.json")).is_empty(),"invalid known field reported")
	check(Visual.snapshot(view) == stable and protected() == before,"failed load is atomic")
	check(view._save_inspection(output.path_join("missing/path.json")) != OK,"unwritable save is explicit")
	check(view._save_inspection(view.capture_path) != OK,"save refuses non-JSON capture destination")
	write_text(output.path_join("bad.json"),"{broken")
	check(not view._load_inspection(output.path_join("bad.json")).is_empty(),"malformed syntax is actionable")
	write_text(output.path_join("bad.json")," ".repeat(Preset.MAX_BYTES+1))
	check(not view._load_inspection(output.path_join("bad.json")).is_empty(),"oversized input is bounded")
	check(not view._load_inspection(output.path_join("missing.json")).is_empty(),"missing input is actionable")
	view.inspection_busy = true
	check(not view._load_inspection(path).is_empty(),"load refuses during an image capture")
	view.inspection_busy = false
	check(Visual.snapshot(view) == stable and protected() == before,"all refused loads preserve view and transport")
	var unavailable: Dictionary = stored.duplicate(true);unavailable.settings.particles.colormap_name = "unavailable-map"
	var skipped := Preset.prepare(view,unavailable)
	check(skipped.error.is_empty() and not skipped.skipped.is_empty(),"unavailable optional colormap is skipped")
	var extra: Dictionary = stored.duplicate(true);extra.settings.unknown_feature = {"object_id":"do-not-remap"};extra.settings.view.channel = "wrong-name"
	var result := Preset.apply(view,extra)
	check(result.error.is_empty() and result.skipped.size() >= 2,"unsupported optional settings skipped with diagnostics")
	if production.is_empty():
		view._open_capture(output.path_join("scene.wvz"));await settle()
		check(view._load_inspection(path).is_empty(),"same capture after reopen")
		view._open_capture(output.path_join("different.wvz"));await settle();before = protected()
		check(view._load_inspection(path).is_empty(),"different compatible object/channel names load")
		check(protected() == before,"different capture identifiers/time remain unchanged")
		check(view.scene_layers.states.vacuum_field.colormap == stored.settings.volume.colormap and is_equal_approx(view.scene_layers.states.vacuum_field.opacity,.7),"portable volume settings apply to current selection")
		view._open_capture(output.path_join("particles.wvz"));await settle()
		check(view._load_inspection(path).is_empty() and view.status_label.text.contains("Skipped"),"absent optional volume/mesh skipped")
	# A native/platform file dialog is the sole recipe UI. Exercise callback and cancellation.
	var was := protected()
	view._show_recipe_dialog(true)
	check(view.recipe_dialog.use_native_dialog and view.recipe_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE,"native save filename dialog configured")
	view.recipe_dialog.canceled.emit();view.recipe_dialog.hide()
	check(protected() == was,"cancel save leaves state intact")
	view._show_recipe_dialog(false)
	check(view.recipe_dialog.use_native_dialog and view.recipe_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE,"native load filename dialog configured")
	view.recipe_dialog.canceled.emit();view.recipe_dialog.hide()
	check(protected() == was,"cancel load leaves state intact")
	# Signal is the same boundary used by the platform picker; no second Save dialog.
	view.recipe_saving = true
	var picker_begin := Time.get_ticks_usec()
	view.recipe_dialog.file_selected.emit(output.path_join("picker-name.json"))
	var picker_callback_ms := (Time.get_ticks_usec()-picker_begin)/1000.0
	check(FileAccess.file_exists(output.path_join("picker-name.json")),"selected filename saves immediately")
	view.shell.details.hide()
	await zoom_roundtrip(path)
	var report := {"checks":checks,"failures":failures,"timings":timings,"bytes":bytes,"fields":expected,"renderer":RenderingServer.get_current_rendering_method(),"production":not production.is_empty(),"memory_static":OS.get_static_memory_usage(),"frame_gaps_ms":frame_times,"file_selected_callback_ms":picker_callback_ms}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	view.free();print("PRESET: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func same(a,b) -> bool:
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not same(a[i],b[i]):return false
		return true
	if (a is float or a is int) and (b is float or b is int):return is_equal_approx(a,b)
	return a == b

func write_text(path: String, text: String):
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()

func record_frame():
	var now := Time.get_ticks_usec()
	if last_frame > 0:frame_times.append((now-last_frame)/1000.0)
	last_frame = now

# Exercise actual wheel input and picker callbacks while the viewer ticks normally.
func zoom_roundtrip(path: String):
	view.playing = false;view.orbit_enabled = false;view.free_camera = false
	view.set_process(true)
	view.camera_distance = 40.;view._update_camera()
	for i in 4:wheel(MOUSE_BUTTON_WHEEL_UP)
	var distance: float = view.camera_distance
	var transform: Transform3D = view.camera.transform
	var projection: Projection = view.camera.get_camera_projection()
	view._show_recipe_dialog(true);await settle()
	check(is_equal_approx(view.camera_distance,distance),"opening Save picker preserves adjusted zoom")
	view.recipe_dialog.hide();view.recipe_dialog.file_selected.emit(path)
	view.shell.details.hide()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(is_equal_approx(data.settings.view.camera_distance,distance),"wheel zoom is exported to JSON")
	for reopen in [false,true]:
		for i in 6:wheel(MOUSE_BUTTON_WHEEL_DOWN)
		check(not view.camera.transform.is_equal_approx(transform),"wheel changes visible camera before reload")
		if reopen:
			await view._open_from_picker(view.capture_path)
			await settle()
		view.recipe_saving = false;view.recipe_dialog.file_selected.emit(path)
		view.shell.details.hide();await settle()
		check(is_equal_approx(view.camera_distance,distance),"picker restores zoom distance; reopen="+str(reopen))
		check(view.camera.transform.is_equal_approx(transform),"picker restores visible zoom after live ticks; reopen="+str(reopen))
		check(view.camera.get_camera_projection() == projection,"picker restores projection; reopen="+str(reopen))
		wheel(MOUSE_BUTTON_WHEEL_UP)
		check(is_equal_approx(view.camera.position.distance_to(view.camera_target),distance*.9),"first wheel after loading continues from saved zoom")
	view.set_process(false)

func wheel(button: MouseButton):
	var event := InputEventMouseButton.new();event.button_index = button;event.pressed = true
	view._unhandled_input(event)

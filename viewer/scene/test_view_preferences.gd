extends SceneTree
const Preferences = preload("res://scene/view_preferences.gd")
const Visual = preload("res://scene/visual_state.gd")
const Portable = preload("res://scene/view_preset.gd")
var checks := 0
var failures: Array[String] = []
var viewer
var output := ""
var phase := ""
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures.append(label);push_error(label)
func settle():
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
func bloom() -> Array:
	return [viewer.selected_preset,viewer.environment.glow_enabled,viewer.environment.glow_intensity]
func equal_bloom(expected: Array) -> bool:
	return viewer.selected_preset == expected[0] and viewer.environment.glow_enabled == expected[1] and is_equal_approx(viewer.environment.glow_intensity,expected[2])
func record_picture(name: String):
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output.path_join(name+".png"))
func unit_contracts():
	var prefs := Preferences.new();prefs.storage_path = output.path_join("unit.cfg")
	check(prefs.reload().is_empty() and prefs.settings == Preferences.defaults(),"Missing profile uses fresh defaults")
	var settings := prefs.settings.duplicate(true);settings.preset="Cinematic";settings.bloom.Cinematic.intensity=.76
	check(prefs.save(settings).is_empty(),"Transactional save succeeds")
	var original := FileAccess.get_file_as_bytes(prefs.storage_path)
	var loaded := Preferences.new();loaded.storage_path=prefs.storage_path
	check(loaded.reload().is_empty() and loaded.settings==settings,"Full profile round trip")
	for value in [-.01,2.01,NAN,INF,"wrong",true]:
		var bad := settings.duplicate(true);bad.bloom.Scientific.intensity=value
		check(not prefs.save(bad).is_empty() and prefs.settings==settings and FileAccess.get_file_as_bytes(prefs.storage_path)==original,"Bad intensity cannot partially replace disk or memory")
	for field in ["preset","bloom"]:
		var bad := settings.duplicate(true);bad.erase(field)
		check(not prefs.save(bad).is_empty(),"Incomplete preference is rejected: "+field)
	var file := FileAccess.open(prefs.storage_path,FileAccess.WRITE);file.store_string('{"version":1,"settings":{"preset":"Cinematic"}}');file.close()
	check(not loaded.reload().is_empty() and loaded.settings==settings,"Malformed reload is atomic")
	file=FileAccess.open(prefs.storage_path,FileAccess.WRITE);file.store_string("{broken");file.close()
	check(not loaded.reload().is_empty() and loaded.settings==settings,"Corrupt syntax leaves memory unchanged")
	file=FileAccess.open(prefs.storage_path,FileAccess.WRITE);file.store_string("x".repeat(Preferences.MAX_BYTES+1));file.close()
	check(not loaded.reload().is_empty() and loaded.settings==settings,"Oversized input bounded before parsing")
	prefs.storage_path=output.path_join("missing/folder/profile.cfg")
	check(not prefs.save(Preferences.defaults()).is_empty() and prefs.settings==settings,"Failed write leaves committed profile unchanged")
func run():
	create_timer(90).timeout.connect(func():push_error("View preferences test timed out");quit(1))
	var args := OS.get_cmdline_user_args();output=args[0];phase=args[1]
	viewer=load("res://main.gd").new();viewer.scene_prebuffer_enabled=false;root.add_child(viewer);viewer.set_process(false)
	await settle()
	if phase=="restart":
		check(equal_bloom(["Scientific",true,.74]),"New process restores selected preset and manual Scientific Bloom")
		viewer._apply_preset("Cinematic")
		check(equal_bloom(["Cinematic",false,.52]),"New process restores Cinematic override")
		viewer._apply_preset("Scientific")
	elif phase=="corrupt":
		check(equal_bloom(["Scientific",false,.30]),"Corrupt startup restores complete fresh defaults")
		check(viewer.bloom_notice.visible and not viewer.bloom_notice.text.is_empty(),"Corrupt preference is visible in Global effects")
	elif phase=="missing":
		check(equal_bloom(["Scientific",false,.30]),"Removing preference file while closed restores defaults")
	else:
		unit_contracts()
		check(equal_bloom(["Scientific",false,.30]),"Fresh startup Scientific with Bloom off")
		check(viewer.glow_slider.max_value==2 and is_equal_approx(viewer.glow_slider.step,.02),"Existing Bloom slider range and step retained")
		for name in Preferences.PRESETS:
			viewer._apply_preset(name)
			check(equal_bloom([name,name=="Cinematic",.30]),"Fresh initial Bloom for "+name)
			check(viewer.glow_slider.editable,"Bloom editable in "+name)
			viewer.bloom_enabled.button_pressed=true;viewer.glow_slider.value=.64
			check(equal_bloom([name,true,.64]) and viewer.bloom_enabled.button_pressed,"Manual enable/intensity preserves preset identity: "+name)
			viewer._apply_preset("Cinematic" if name!="Cinematic" else "Scientific");viewer._apply_preset(name)
			check(equal_bloom([name,true,.64]),"Preset switch remembers override: "+name)
			viewer.bloom_enabled.button_pressed=false
			check(equal_bloom([name,false,.64]) and viewer.glow_slider.editable,"Manual disable keeps value editable: "+name)
		viewer._apply_preset("Scientific");viewer._set_bloom_enabled(true);viewer.glow_slider.value=.74
		var expected := bloom()
		viewer._reset_camera()
		check(equal_bloom(expected),"Reset Camera leaves viewing preferences intact")
		for source in ["particles","fields","meshes","mixed"]:
			viewer._open_capture(output.path_join(source+".wvz"));viewer.playing=false;await settle()
			check(viewer.generic_reader!=null and equal_bloom(expected),"Opening "+source+" preserves preferences")
			check(viewer._close_capture() and equal_bloom(expected),"Close File preserves preferences: "+source)
		viewer._open_capture(output.path_join("mixed.wvz"));await settle()
		var disk := FileAccess.get_file_as_bytes(Preferences.STORAGE_PATH)
		var saved := Visual.snapshot(viewer);saved.environment.glow_enabled=false;saved.environment.glow_intensity=.31;saved.sliders.Bloom=1.8
		Visual.apply(viewer,saved)
		check(equal_bloom(["Scientific",false,.31]) and is_equal_approx(viewer.glow_slider.value,.31),"Native view restore keeps identity and exact environment over stale slider")
		check(FileAccess.get_file_as_bytes(Preferences.STORAGE_PATH)==disk,"Native snapshot restoration does not write application preferences")
		var recipe := Portable.snapshot(viewer)
		recipe.settings.view.preset="Cinematic";recipe.settings.environment.glow_enabled=false;recipe.settings.environment.glow_intensity=.43
		check(Portable.apply(viewer,recipe).error.is_empty() and equal_bloom(["Cinematic",false,.43]),"Explicit portable view applies named preset and independent Bloom")
		check(FileAccess.get_file_as_bytes(Preferences.STORAGE_PATH)==disk,"Portable view does not overwrite application preference file")
		var stable := Visual.snapshot(viewer);recipe.settings.environment.glow_enabled="bad"
		check(not Portable.apply(viewer,recipe).error.is_empty() and Visual.snapshot(viewer)==stable and FileAccess.get_file_as_bytes(Preferences.STORAGE_PATH)==disk,"Invalid recipe changes neither live state nor persistent preferences")
		viewer._close_capture();viewer._open_capture(output.path_join("fields.wvz"));await settle()
		check(equal_bloom(["Cinematic",false,.43]),"Explicit session override survives capture close/open")
		viewer._apply_preset("Cinematic");viewer._set_bloom_enabled(false);viewer.glow_slider.value=.52
		viewer._apply_preset("Scientific");viewer._set_bloom_enabled(true);viewer.glow_slider.value=.74
		for light in [false,true]:
			viewer.shell.appearance.select(light);viewer.tools_ui.open("Global effects");await settle()
			check(viewer.bloom_enabled.button_pressed and is_equal_approx(viewer.glow_slider.value,.74),"Theme change keeps controls/model consistent")
			record_picture("effects-"+("light" if light else "dark"))
			viewer.bloom_enabled.grab_focus()
			for enabled in [false,true]:
				var toggle_key := InputEventKey.new();toggle_key.keycode=KEY_SPACE;toggle_key.pressed=true
				viewer.tools_ui.window.push_input(toggle_key)
				toggle_key=toggle_key.duplicate();toggle_key.pressed=false;viewer.tools_ui.window.push_input(toggle_key);await settle()
				check(viewer.environment.glow_enabled==enabled and viewer.selected_preset=="Scientific" and not viewer.playing,"Space toggles Bloom independently of preset/playback")
			for enabled in [false,true]:
				var mouse := InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true
				mouse.position=viewer.bloom_enabled.get_global_rect().get_center();mouse.global_position=mouse.position
				var motion := InputEventMouseMotion.new();motion.position=mouse.position;motion.global_position=mouse.position
				if viewer.tools_ui.window.is_embedded():
					motion.position += Vector2(viewer.tools_ui.window.position)
					root.warp_mouse(motion.position);root.push_input(motion)
				else:
					viewer.tools_ui.window.warp_mouse(motion.position);viewer.tools_ui.window.push_input(motion)
				await settle()
				viewer.tools_ui.window.push_input(mouse);await settle()
				mouse=mouse.duplicate();mouse.pressed=false;viewer.tools_ui.window.push_input(mouse);await settle()
				check(viewer.environment.glow_enabled==enabled and viewer.selected_preset=="Scientific","Mouse toggles manual Bloom without relabeling")
			# Real Window keyboard path, independent of preset selection.
			viewer.glow_slider.grab_focus()
			var key := InputEventKey.new();key.keycode=KEY_RIGHT;key.pressed=true;viewer.tools_ui.window.push_input(key)
			key=key.duplicate();key.pressed=false;viewer.tools_ui.window.push_input(key);await settle()
			check(is_equal_approx(viewer.environment.glow_intensity,.76) and viewer.selected_preset=="Scientific","Keyboard adjusts manual Scientific Bloom")
			viewer.glow_slider.value=.74
	FileAccess.open(output.path_join(phase+"-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"phase":phase,"state":bloom()},"  "))
	viewer.queue_free();await process_frame;await process_frame
	print("VIEW PREFERENCES: ",checks," checks, ",failures.size()," failures (",phase,")")
	quit(0 if failures.is_empty() else 1)

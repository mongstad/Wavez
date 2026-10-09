extends SceneTree
const Visual = preload("res://scene/visual_state.gd")
const Preset = preload("res://scene/view_preset.gd")
const Job = preload("res://video/render_job.gd")
var viewer
var output := ""
var fixture := ""
var baseline := false
var checks := 0
var failures: Array = []
var observations: Array = []
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks += 1
	if not ok:failures.append(label);push_error(label)
func settle():
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String, expected: String):
	viewer.shell.refresh_commands()
	var selected: Dictionary = viewer.shell.commands["preset:"+expected]
	check(selected.popup.is_item_checked(selected.index),name+" effective preset checked in real menu")
	viewer.tools_ui.open("Global effects")
	selected.popup.popup(Rect2i(970,330,230,220))
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,name+" screenshot")
	observations.append({"case":name,"preset":viewer.selected_preset,"menu_checked":expected,"editable":viewer.glow_slider.editable,"glow_enabled":viewer.environment.glow_enabled})
	selected.popup.hide();viewer.tools_ui.close(false)
func run():
	var args := OS.get_cmdline_user_args();output = args[0];fixture = args[1];baseline = "baseline" in args
	OS.low_processor_usage_mode = false
	viewer = load("res://main.gd").new();root.add_child(viewer);viewer.set_process(false)
	viewer.playing = false;viewer.orbit_enabled = false;viewer.shell.set_process(false)
	for scene in ["fields","meshes"]:
		viewer._open_capture(fixture.path_join(scene+".wvz"))
		viewer.camera.position = Vector3(0,0,12);viewer.camera.look_at(Vector3.ZERO);viewer._adopt_camera_basis()
		for light in [false,true]:
			viewer.shell.appearance.select(light)
			var theme: String = "light" if light else "dark"
			viewer._apply_preset("Scientific")
			var saved := Preset.snapshot(viewer)
			viewer._apply_preset("Cinematic");Preset.apply(viewer,saved)
			await capture(scene+"-"+theme+"-restored", "Cinematic" if baseline else "Scientific")
			# Invoke the connected menu command, including its availability guard.
			viewer.shell.refresh_commands()
			var entry: Dictionary = viewer.shell.commands["preset:Cinematic"]
			check(not entry.popup.is_item_disabled(entry.index),scene+" Cinematic available without particles")
			entry.popup.id_pressed.emit(entry.index)
			check(viewer.environment.glow_enabled and viewer.glow_slider.editable,scene+" Cinematic menu enables shared control")
			await capture(scene+"-"+theme+"-selected-Cinematic","Cinematic")
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"observations":observations})
	viewer.queue_free();await process_frame
	print("GLOBAL BLOOM MENU: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

extends Node
## Empty-state decoration isolation and accepted-main image comparison driver.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var reference := false
var layouts: Array = []
var loaded: Dictionary = {}
var idle: Dictionary = {}
@onready var root: Window = get_tree().root
func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 10: await get_tree().process_frame
	RenderingServer.force_draw(false)
func picture(name: String) -> void:
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Save "+name)
func ready(view) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 12000:
		await get_tree().process_frame; view._process(0)
		if not view.scene_layers.is_buffering() and (not view.scene_layers.field_playback.active() or view.scene_layers.field_playback.worker.status().session.get("state") == "ready"): break
	check(not view.scene_layers.is_buffering(),"Loaded sample ready")
	await settle()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--empty-output="): output = arg.trim_prefix("--empty-output=")
		if arg == "--reference": reference = true
	if output.is_empty(): queue_free(); return
	get_tree().create_timer(100).timeout.connect(func(): push_error("Empty background timeout"); get_tree().quit(1))
	await get_tree().process_frame
	var view = get_tree().current_scene
	if view == null: view = Viewer.new(); view.scene_prebuffer_enabled = false; root.add_child(view)
	view.orbit_enabled = false; view.playing = false; view.set_process(false)
	OS.low_processor_usage_mode = false
	check(view.scene_layers == null and view.environment.background_mode == Environment.BG_SKY,"Startup remains cinematic without a capture")
	check(view.starfield.multimesh.instance_count == 2400,"Accepted loaded decoration is retained")
	await settle() # Native decoration changes settle before setting test geometry.
	var sky_code: String = view.environment.sky.sky_material.shader.code
	var environment_before: Dictionary = Visual.snapshot(view).environment
	for layout in [[Vector2i(1440,900),1.0],[Vector2i(3840,2160),2.0],[Vector2i(3840,2160),2.5]]:
		root.size = layout[0]; root.content_scale_factor = layout[1]; await settle(); root.size = layout[0]; view.shell.layout(); await settle()
		check(root.size == layout[0],"Actual rendered dimensions "+str(layout[0]))
		layouts.append({"actual":str(root.size),"scale":layout[1]})
		var id := str(layout[0].x)+"-"+str(layout[1])
		if reference:
			view.starfield.show(); await settle(); picture("stars-"+id); view.starfield.hide(); await settle()
		check(not view.starfield.is_visible_in_tree(),"No decorative stars in empty viewport "+id)
		picture("empty-"+id)
		var no_stars := root.get_texture().get_image().get_data()
		# Toggling the child cannot expose dots in the candidate empty state.
		view.starfield.show(); await settle()
		if not reference:
			check(not view.starfield.is_visible_in_tree(),"Parent isolates saved/child star visibility "+id)
			check(no_stars == root.get_texture().get_image().get_data(),"Child visibility leaves cinematic pixels intact "+id)
			RenderingServer.force_draw(false)
			check(no_stars == root.get_texture().get_image().get_data(),"Redraw has no sparkle pixels "+id)
		if reference: view.starfield.hide()
	check(sky_code == view.environment.sky.sky_material.shader.code and environment_before == Visual.snapshot(view).environment,"Sky shader and atmosphere unchanged")
	root.content_scale_factor = 1; root.size = Vector2i(1440,900); await settle()
	view._open_capture(output.path_join("invalid.ssc")); await settle(); view.shell.details.hide(); await settle()
	check(view.scene_layers == null and not view.starfield.is_visible_in_tree(),"Failed capture open does not expose stars")
	view._set_clean(true); view._set_clean(false); await settle()
	if reference: view.starfield.hide(); await settle()
	check(not view.starfield.is_visible_in_tree(),"Empty viewing preset cannot expose stars")
	view.set_process(true); await settle(); await get_tree().create_timer(.3).timeout
	var frames := Engine.get_frames_drawn(); var callbacks := Engine.get_process_frames()
	var image := root.get_texture().get_image().get_data()
	await get_tree().create_timer(1.2).timeout
	idle = {"draws":Engine.get_frames_drawn()-frames,"callbacks":Engine.get_process_frames()-callbacks,"same_pixels":image == root.get_texture().get_image().get_data()}
	check(OS.low_processor_usage_mode and idle.same_pixels,"Empty startup retains pacing policy and stable pixels")
	view.set_process(false); OS.low_processor_usage_mode = false
	if reference: view.starfield.show()
	for kind in ["particles","field","mesh","mixed"]:
		view._open_capture(output.path_join(kind+".ssc")); view.playing = false; view.orbit_enabled = false; await ready(view)
		view._set_clean(false); await settle()
		check(view.starfield.is_visible_in_tree(),kind+" cinematic loaded decoration unchanged")
		picture(kind+"-cinematic")
		view._set_clean(true); await settle()
		check(not view.starfield.is_visible_in_tree(),kind+" scientific mode retains star suppression")
		picture(kind+"-scientific")
		loaded[kind] = {"clock":view.committed_sample.requested_time,"camera":str(view.camera.transform),"records":view.generic_reader.records.size()}
	var report := {"checks":checks,"failures":failures,"reference":reference,"layouts":layouts,"idle":idle,"loaded":loaded,"sky_shader":sky_code,"environment":environment_before,"renderer":RenderingServer.get_current_rendering_method(),"display_driver":DisplayServer.get_name(),"packaged":not OS.has_feature("editor")}
	FileAccess.open(output.path_join("empty-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("EMPTY BACKGROUND: ",checks," checks, ",failures.size()," failures")
	view._reset_inspection_source()
	if view.generic_reader != null: view.generic_reader.close()
	view.queue_free(); await get_tree().process_frame; await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

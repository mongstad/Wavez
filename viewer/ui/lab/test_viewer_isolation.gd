extends SceneTree
## Load the optional library beside a frozen native fixture viewer; verify all existing UI/science pixels and state.
const Viewer = preload("res://main.gd")
const Inspection = preload("res://scene/inspection_state.gd")
const Profile = preload("res://scene/playback_profile.gd")
var checks: Array = []
var out := ""
var fixture := ""
func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	checks.append({"passed": value, "description": description})
	if not value: push_error(description)
func settle() -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ux2-output="): out = arg.trim_prefix("--ux2-output=")
		if arg.begins_with("--ux2-fixture="): fixture = arg.trim_prefix("--ux2-fixture=")
	if out.is_empty() or fixture.is_empty() or DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(out)
	var viewer := Viewer.new(); viewer.capture_path = fixture; viewer.playing = false; viewer.orbit_enabled = false; viewer.scene_prebuffer_enabled = false
	root.add_child(viewer); viewer.set_process(false); viewer.set_process_unhandled_input(false)
	await settle()
	var source := Inspection.identity(viewer)
	var before := Inspection.snapshot(viewer, source)
	check(not before.is_empty(), "Loaded native combined SIMSCP3 fixture snapshot")
	var image_before := root.get_texture().get_image(); image_before.save_png(out.path_join("production-before.png"))
	var original_theme = root.theme
	var original_project_theme = ProjectSettings.get_setting("gui/theme/custom", "")
	var original_main = ProjectSettings.get_setting("application/run/main_scene")
	Profile.enabled = true; Profile.reset()
	var theme = load("res://ui/theme/simscope_theme.gd").new()
	var viewport := SubViewport.new(); viewport.size = Vector2i(1440, 900); viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab = load("res://ui/lab/ui_laboratory.gd").new(); lab.manage_window = false; viewport.add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	# Exercise presentation state and rebuild the optional resource, without attaching it to Viewer.
	lab.tabs.current_tab = 1; lab.specimens.scientific.editor.text = "2e-20"; lab.specimens.scientific.commit()
	lab.specimens.disclosure.set_expanded(false)
	theme = load("res://ui/theme/simscope_theme.gd").new()
	lab.theme = theme
	await settle()
	var activity := Profile.report(); Profile.enabled = false
	var after := Inspection.snapshot(viewer, source)
	var image_after := root.get_texture().get_image(); image_after.save_png(out.path_join("production-after.png"))
	check(before == after, "Native scientific/visual/recipe snapshot unchanged after library load, edit and theme rebuild")
	check(image_before.get_data() == image_after.get_data(), "Production viewport and existing UI pixels byte-identical")
	check(Profile.counters.is_empty(), "No scientific preparation/hash/upload counters from theme/component activity")
	check(root.theme == original_theme and ProjectSettings.get_setting("gui/theme/custom", "") == original_project_theme, "Root and global production theme untouched")
	check(ProjectSettings.get_setting("application/run/main_scene") == original_main, "Production startup scene unchanged")
	var failures := checks.filter(func(item): return not item.passed)
	var file := FileAccess.open(out.path_join("isolation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "profile": activity, "before": before, "after": after, "production_before_sha256": FileAccess.get_sha256(out.path_join("production-before.png")), "production_after_sha256": FileAccess.get_sha256(out.path_join("production-after.png"))}, "\t")); file.close()
	viewport.queue_free(); viewer.queue_free(); await process_frame
	print("UX2 ISOLATION: %d checks, %d failures" % [checks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

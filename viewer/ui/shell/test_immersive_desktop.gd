extends SceneTree
## Read-only real-capture review; the external harness acknowledges each native stage.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var output := ""
var capture := ""
var viewer
var before: Dictionary
var sample: Dictionary
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func stage(label: String) -> void:
	await create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	check(Visual.snapshot(viewer) == before and viewer.committed_sample == sample, label + " preserves scientific state and sample")
	get_root().get_texture().get_image().save_png(output.path_join(label + "-viewport.png"))
	var report := {"stage":label,"pid":OS.get_process_id(),"backend":DisplayServer.get_name(),"mode":root.mode,"window_size":str(root.size),"immersive":viewer.shell.immersive,"hint":viewer.shell.immersive_hint.visible,"shell_visible":viewer.shell.is_visible_in_tree(),"dock_visible":viewer.overlay_panel.visible,"legend_visible":viewer.legend.visible,"colorbar_visible":viewer.colorbar.visible,"checks":checks,"failures":failures}
	FileAccess.open(output.path_join("stage.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
	for i in 1200:
		if FileAccess.file_exists(output.path_join(label+".ack")): return
		await create_timer(.05).timeout
	check(false,"Desktop harness acknowledgement timed out"); quit(1)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="): output = arg.trim_prefix("--review-output=")
		if arg.begins_with("--review-capture="): capture = arg.trim_prefix("--review-capture=")
	if output.is_empty() or capture.is_empty(): quit(1); return
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(capture); viewer.playing = false; viewer.orbit_enabled = false
	check(viewer.frame_a != null,"Real source opens")
	var particles := 0; var volumes := 0
	for object in viewer.generic_reader.objects.values():
		if object.kind == "particles": particles += 1
		if object.kind == "volume": volumes += 1
	check(particles > 0 and volumes > 0,"Real source contains particles and volume")
	await create_timer(1).timeout
	before = Visual.snapshot(viewer); sample = viewer.committed_sample.duplicate(true)
	await stage("windowed")
	viewer._toggle_fullscreen()
	await stage("fullscreen-entry")
	await stage("fullscreen-settled")
	await create_timer(3).timeout
	await stage("fullscreen-clean")
	await stage("fullscreen-stable")
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	root.push_input(escape)
	await stage("restored-windowed")
	var shortcut := InputEventKey.new(); shortcut.keycode = KEY_F11; shortcut.pressed = true
	root.push_input(shortcut)
	await create_timer(.7).timeout
	await stage("windowed-to-fullscreen")
	# The harness requests an actual KWin fullscreen exit for this test window.
	for i in 100:
		if not viewer.shell.immersive: break
		await create_timer(.05).timeout
	check(not viewer.shell.immersive,"Compositor fullscreen loss restores chrome")
	await stage("wm-recovered")
	print("DESKTOP: ",checks," checks; ",failures.size()," failures")
	viewer.free(); await process_frame; quit(0 if failures.is_empty() else 1)

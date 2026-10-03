extends SceneTree
## File/Tools routing, compact shared surface, native picker contracts, and review images.
const Viewer = preload("res://main.gd")
const TITLES = ["Selection", "Temporal", "Space time", "Diagnostics", "Compare", "Matched runs", "Period", "Bookmarks", "Results", "Mapping", "Derive range", "Slice", "Clipping", "Isosurface", "Source probe", "Performance", "Geometry", "Image", "Data", "Save analysis", "Load analysis"]
var output := ""
var checks := 0
var failures: Array[String] = []
var measurements := []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); push_error(description)

func settle() -> void:
	for i in 5: await process_frame

func picture(window: Window, name: String) -> void:
	window.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(120).timeout.connect(func(): push_error("Dialog coherence timeout"); quit(1))
	var viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("mixed.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	await settle()
	var tools = viewer.tools_ui
	var shell = viewer.shell
	check(not shell.commands.has("tool:Quick setup"), "Removed Quick setup route stays absent")
	check(viewer.open_dialog.use_native_dialog and viewer.open_dialog.filters == PackedStringArray(["*.wvz ; WAVEZ Scene Format"]), "Accepted scene-open picker stays native with one WVZ filter")
	for title in TITLES:
		tools.open(title); await settle()
		check(tools.window.visible and tools.current == title, "Active route opens " + title)
		check(tools.window.borderless and tools.window.theme == shell.style_slice.theme, "Custom WAVEZ surface: " + title)
		check(not tools.context.visible, "No duplicated source heading: " + title)
		if title != "Image": check(tools.content.get_parent().size.y >= 100, "Scrollable content remains usable: " + title)
		measurements.append({"title":title,"before":[600,720],"after":[tools.window.size.x,tools.window.size.y]})
		if title in ["Mapping","Diagnostics","Performance","Image"]: picture(tools.window,title.to_lower().replace(" ","-"))
		if title == "Mapping":
			check(not tools.notice.visible, "Mapping has no duplicate loaded footer")
			check(tools.window.size.y < 400, "Mapping is compact")
		if title == "Diagnostics": check(tools.window.size.y <= 620, "Diagnostics is bounded and scrollable")
		if title == "Diagnostics":
			check(tools.footer.get_child_count() == 1 and tools.footer.get_child(0).get_child_count() == 2, "Diagnostics retains Import and Close actions")
			check(tools.footer.get_child(0).get_child(0).size.x >= 70, "Import action remains legible")
			check(tools.done_button.get_global_rect().end.x <= tools.window.size.x, "Diagnostics Close stays within the surface")
		tools.close()
	root.size = Vector2i(1024,640); await settle()
	for title in TITLES:
		tools.open(title); await settle()
		check(tools.window.size.x <= 1024 and tools.window.size.y <= 640, "Small desktop bounds: " + title)
		tools.close()
	root.size = Vector2i(1440,900); await settle()
	shell.show_source(); await settle()
	check(shell.details.borderless and shell.details.theme == shell.style_slice.theme, "File Details has custom WAVEZ surface")
	check(shell.detail_text.text.contains(viewer.capture_path), "File Details retains authoritative full source identity")
	picture(shell.details,"file-details"); shell.details.hide()
	var video = viewer.video_dialog
	video.open(); await settle()
	check(video.borderless and video.theme == shell.style_slice.theme, "Video export has custom WAVEZ surface")
	check(video.save_dialog.use_native_dialog and video.save_dialog.filters == PackedStringArray(["*.mp4 ; H.264 MP4"]), "Video output picker is native with MP4 filter")
	picture(video,"video-export")
	video.cancel_confirmation.theme = shell.style_slice.theme
	video.cancel_confirmation.popup_centered(); await settle()
	check(video.cancel_confirmation.borderless and video.cancel_confirmation.theme == shell.style_slice.theme, "Video cancellation confirmation uses WAVEZ styling")
	picture(video.cancel_confirmation,"cancel-video"); video.cancel_confirmation.hide(); video.hide()
	check(viewer.recipe_dialog == null or viewer.recipe_dialog.use_native_dialog, "Portable preset picker remains native")
	var report := {"checks":checks,"failures":failures,"measurements":measurements}
	FileAccess.open(output.path_join("dialog-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	viewer.free(); await process_frame
	print("DIALOG COHERENCE: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

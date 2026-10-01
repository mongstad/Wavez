extends Node
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Version = preload("res://application_version.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var report := {}
var real_browser := false

@onready var root: Window = get_tree().root

func _ready() -> void:run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:failures.append(message); push_error(message)
func settle() -> void:
	for i in 8:await get_tree().process_frame
	if DisplayServer.get_name() != "headless":await RenderingServer.frame_post_draw
func picture(dialog, name: String) -> void:
	if DisplayServer.get_name() == "headless":return
	var viewport: Viewport = root if dialog.is_embedded() else dialog
	viewport.get_texture().get_image().save_png(output.path_join(name+".png"))
func open_about(shell) -> void:
	shell.refresh_commands()
	shell.commands.about.popup.id_pressed.emit(shell.commands.about.index)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--about-output="):output = arg.trim_prefix("--about-output=")
		if arg == "--open-browser":real_browser = true
	if output.is_empty():queue_free(); return
	get_tree().create_timer(90).timeout.connect(func():push_error("About test timeout");get_tree().quit(1))
	await get_tree().process_frame
	var viewer = get_tree().current_scene
	if viewer == null:
		viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer)
	viewer.set_process(false)
	var shell = viewer.shell; var dialog = shell.about
	check(not dialog.visible,"About does not open at startup")
	check(not shell.commands.has("version") and shell.commands.has("about"),"About is the only application identity menu")
	var help: PopupMenu = shell.menus.Help.get_popup(); var entries := PackedStringArray()
	for index in help.item_count:entries.append(help.get_item_text(index))
	check(entries == PackedStringArray(["Shortcuts","Handbook","About WAVEZ"]),"Exact Help menu has no standalone Version")
	open_about(shell); await settle()
	check(dialog.visible and not shell.details.visible,"Help opens the dedicated About surface without a capture")
	check(dialog.identity.text == "WAVEZ "+Version.read().full,"About uses authoritative full identity")
	check(dialog.logo.texture.get_size() == Vector2(1254,1254),"Unmodified owner logo is available as a packaged texture")
	check(dialog.logo.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Logo preserves aspect ratio")
	var summary := ""
	for child in dialog.overview.get_children():
		if child is Label:summary += child.text+"\n"
	check(summary.contains("Copyright © 2026 Johnny Mongstad"),"Overview shows the canonical rights holder")
	check(summary.contains("WAVEZ project material\nPolyForm Noncommercial 1.0.0"),"Overview attributes PolyForm to WAVEZ")
	check(summary.contains("Godot Engine/runtime — MIT License") and summary.contains("third-party components retain"),"Overview distinguishes engine and other third-party licensing")
	var source_version = ProjectSettings.get_setting(Version.SETTING)
	ProjectSettings.set_setting(Version.SETTING,"v2.3.4.1001"); open_about(shell)
	check(dialog.identity.text == "WAVEZ v2.3.4.1001","About follows release and BUILD changes without another literal")
	ProjectSettings.set_setting(Version.SETTING,null); open_about(shell)
	check(dialog.identity.text.begins_with("WAVEZ version unavailable."),"Missing version has an explicit fallback")
	ProjectSettings.set_setting(Version.SETTING,source_version)
	dialog.hide()
	viewer._open_capture(output.path_join("scene.ssc")); viewer.playing = false; viewer.orbit_enabled = false
	await settle()
	check(viewer.generic_reader != null,"Synthetic capture opens normally")
	var layouts := []
	# #143 native chrome sets a 970x600 minimum. Allow the isolated About
	# compact cases to reach their requested sizes instead of comparing a
	# compositor-clamped viewport against an impossible 480x480 request.
	root.min_size = Vector2i.ZERO
	for dimensions in [Vector2i(1440,900),Vector2i(1920,1080),Vector2i(800,600),Vector2i(480,480)]:
		root.content_scale_size = Vector2i.ZERO; root.content_scale_factor = 1; root.size = dimensions
		await settle(); shell.layout(); await settle()
		var before := Visual.snapshot(viewer); var committed: Dictionary = viewer.committed_sample.duplicate(true)
		var requests: int = viewer.selection_controller.jobs.serial
		open_about(shell); await settle()
		check(dialog.visible and dialog.size.x <= dimensions.x and dialog.size.y <= dimensions.y,"About fits viewport "+str(dimensions))
		check(dialog.scroller.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,"Compact layout wraps instead of horizontal scrolling")
		check(dialog.logo.size.x >= 96 and dialog.logo.size.y >= 96,"Logo remains compact and readable")
		check(dialog.identity.text == "WAVEZ "+Version.read().full,"Full version remains visible "+str(dimensions))
		check(dialog.runtime.text.contains(Engine.get_version_info().string),"Godot runtime version is read live")
		picture(dialog,"about-%d" % dimensions.x)
		if dimensions.x >= 1440:
			check(dialog.scroller.get_global_rect().encloses(dialog.licenses.get_global_rect()),"Normal layout exposes license action without scrolling")
		else:
			dialog.scroller.ensure_control_visible(dialog.licenses); await settle()
			check(dialog.scroller.get_global_rect().encloses(dialog.licenses.get_global_rect()),"Compact scroll exposes the license action")
			picture(dialog,"about-actions-%d" % dimensions.x)
		dialog.licenses.pressed.emit(); await settle()
		check(dialog.license_page.visible and not dialog.overview.visible,"Licenses button opens in-app notices")
		for index in dialog.notice_choice.item_count:
			dialog.notice_choice.select(index); dialog.notice_choice.item_selected.emit(index)
			check(not dialog.notice_text.text.is_empty(),"Packaged notice is readable: "+dialog.notice_choice.get_item_text(index))
			if not report.has("notice_sha256"):report.notice_sha256 = {}
			report.notice_sha256[dialog.notice_choice.get_item_text(index)] = dialog.notice_text.text.sha256_text()
			if index == 0:
				check(dialog.notice_text.text.contains("PolyForm Noncommercial License 1.0.0") and dialog.notice_text.text.contains("Johnny Mongstad"),"WAVEZ license and rights holder are preserved")
			if dialog.notice_choice.get_item_text(index) == "Godot Engine — MIT License":
				check(dialog.notice_text.text == Engine.get_license_text(),"Godot MIT notice belongs to the running engine")
		check(dialog.size.x <= dimensions.x,"Notices retain compact width")
		picture(dialog,"notices-%d" % dimensions.x)
		dialog.show_overview(); dialog.get_ok_button().pressed.emit(); await settle()
		check(not dialog.visible,"Close dismisses About")
		check(Visual.snapshot(viewer) == before and viewer.committed_sample == committed and not viewer.playing,"About leaves scientific/session state unchanged "+str(dimensions))
		check(viewer.selection_controller.jobs.serial == requests,"About makes no analysis request")
		layouts.append({"viewport":str(dimensions),"actual_viewport":str(root.size),"dialog":str(dialog.size)})
	open_about(shell); await settle()
	var requested := []; var normal_opener: Callable = dialog.url_opener
	dialog.url_opener = func(url):requested.append(url);return ERR_UNAVAILABLE
	dialog.github.pressed.emit(); await settle()
	check(requested == [dialog.REPOSITORY] and dialog.REPOSITORY == "https://github.com/mongstad/SimScope","GitHub dispatches only the canonical URL")
	check(dialog.browser_error.visible and dialog.browser_error.text.contains(dialog.REPOSITORY) and dialog.visible,"Missing browser handler leaves About usable with a copyable URL")
	check(dialog.scroller.get_global_rect().encloses(dialog.browser_error.get_global_rect()),"Browser failure message is visible in the compact viewport")
	picture(dialog,"browser-unavailable")
	dialog.url_opener = func(url):requested.append(url);return OK
	dialog.github.pressed.emit()
	check(not dialog.browser_error.visible,"Successful dispatch clears the previous error")
	dialog.url_opener = normal_opener
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
	escape.window_id = root.get_window_id() if dialog.is_embedded() else dialog.get_window_id()
	Input.parse_input_event(escape); await settle()
	check(not dialog.visible,"Escape dismisses About")
	open_about(shell); await settle()
	if real_browser:
		dialog.url_opener = func(url):
			var result := OS.shell_open(url); report.browser_url = url; report.browser_result = result; return result
		dialog.github.pressed.emit()
		check(report.browser_result == OK,"Normal platform handler accepts the GitHub URL")
	report.merge({"checks":checks,"failures":failures,"version":Version.read(),"layouts":layouts,"help":entries,"runtime":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"architecture":Engine.get_architecture_name()})
	FileAccess.open(output.path_join("about-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	viewer.free(); print("ABOUT: ",checks," checks, ",failures.size()," failures");get_tree().quit(0 if failures.is_empty() else 1)

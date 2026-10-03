extends SceneTree
## Product identity across real shell, menus, panels and dynamically built forms.
const Viewer = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []
var output := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
func text_check(value: String, label: String) -> void:
	var reviewed := value.to_lower()
	check(not reviewed.contains("simscope") and not reviewed.contains("simscp") and not reviewed.contains(".ssc"), label + ": " + value)
func scan(node: Node) -> void:
	for property in node.get_property_list():
		if property.name in ["text", "title", "tooltip_text"]:
			var value = node.get(property.name)
			if value is String and not value.is_empty(): text_check(value, str(node.get_path()) + "/" + property.name)
	if node is PopupMenu:
		for index in node.item_count: text_check(node.get_item_text(index), str(node.get_path()) + "/item")
	for child in node.get_children(): scan(child)
func picture(window: Window, name: String) -> void:
	var viewport: Viewport = root if window == root or window.is_embedded() else window
	viewport.get_texture().get_image().save_png(output.path_join(name + ".png"))
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(90).timeout.connect(func(): push_error("Brand audit timeout"); quit(1))
	var viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	await settle()
	check(ProjectSettings.get_setting("application/config/name") == "WAVEZ", "Application name")
	check(root.title == "WAVEZ", "Native window title")
	check(ProjectSettings.get_setting("application/config/icon") == "res://ui/about/wavez-logo-dark.png", "Approved dark application icon")
	scan(viewer); picture(root, "empty")
	viewer._open_capture(output.path_join("scene.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	await settle()
	check(viewer.generic_reader != null, "WVZ1 opens")
	viewer.shell.about.open(); await settle(); scan(viewer); picture(viewer.shell.about, "about"); viewer.shell.about.hide()
	for title in viewer.shell.menus:
		var menu: PopupMenu = viewer.shell.menus[title].get_popup()
		menu.popup(); await settle(); scan(menu); picture(menu, "menu-" + title); menu.hide()
	for page in 3:
		viewer.shell.select_workspace(page); await settle(); scan(viewer); picture(root, "panel-" + str(page))
	for name in viewer.shell.commands:
		if not name.begins_with("tool:"): continue
		var command: Dictionary = viewer.shell.commands[name]
		command.popup.id_pressed.emit(command.index); await settle(); scan(viewer.tools_ui.window)
		picture(viewer.tools_ui.window, "tool-" + name.trim_prefix("tool:").to_snake_case())
	viewer.tools_ui.close()
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"user_data_dir":OS.get_user_data_dir()}, "  ")); file.close()
	viewer.free(); quit(0 if failures.is_empty() else 1)

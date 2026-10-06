extends Node

const Viewer = preload("res://main.gd")
const Preset = preload("res://scene/view_preset.gd")
const CASES = [
	["particles.wvz", 0, "particles"],
	["fields.wvz", 1, "volume"],
	["meshes.wvz", 2, "mesh"],
	["particle-fields.wvz", 0, "particles"],
	["particle-meshes.wvz", 0, "particles"],
	["field-meshes.wvz", 1, "volume"],
	["mixed.wvz", 0, "particles"],
]

var checks := 0
var failures: Array[String] = []
var report_dir := ""
var fixtures_dir := ""
var offline := false
var real_path := ""
var real_expected := -1
@onready var root: Window = get_tree().root

func _ready() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)

func settle() -> void:
	for i in 5: await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func check_category(viewer, expected: int, kind: String, label: String) -> void:
	var shell = viewer.shell
	var layers = viewer.scene_layers
	check(viewer.generic_reader != null and shell.workspace == expected and shell.chooser.selected == expected
		and shell.tab_buttons[expected].theme_type_variation == "SelectedButton", label + ": source kinds select and display the expected category")
	if kind == "particles":
		check(viewer.inspector_box.visible and not shell.particle_empty.visible and not shell.adapter.visible,
			label + ": particle controls are immediately available")
	else:
		var selected: String = layers.selected_objects.get(kind, "")
		check(shell.adapter.visible and layers.category_pages[kind].is_visible_in_tree()
			and layers.object_choices[kind].item_count > 0 and not selected.is_empty()
			and layers.panel_controls.has(selected), label + ": object selector and controls are immediately available")

func check_visibility_stays(viewer, kind: String, expected: int, label: String) -> void:
	if kind == "particles":
		viewer.particle_layer_visible = false
	else:
		var layers = viewer.scene_layers
		var selected: String = layers.selected_objects[kind]
		layers.panel_controls[selected].visible.button_pressed = false
	viewer.shell.refresh()
	check(viewer.shell.workspace == expected, label + ": hiding the selected kind does not switch categories")
	if kind == "particles": viewer.particle_layer_visible = true
	else: viewer.scene_layers.panel_controls[viewer.scene_layers.selected_objects[kind]].visible.button_pressed = true
	viewer.shell.refresh()
	check(viewer.shell.workspace == expected, label + ": restoring visibility does not switch categories")
	if kind != "particles":
		var layers = viewer.scene_layers
		var first: String = layers.selected_objects[kind]
		var second: String = kind + "1"
		layers.choose_object(kind, second)
		check(viewer.shell.workspace == expected and layers.selected_objects[kind] == second,
			label + ": choosing another object does not switch categories")
		layers.choose_object(kind, first)

func check_interactive(viewer) -> void:
	for entry in CASES:
		var file: String = entry[0]
		var expected: int = entry[1]
		var kind: String = entry[2]
		var label := file.get_basename()
		viewer.shell.select_workspace((expected + 1) % 3)
		viewer._open_capture(fixtures_dir.path_join(file))
		check_category(viewer, expected, kind, label + " first load")
		check_visibility_stays(viewer, kind, expected, label)
		if DisplayServer.get_name() != "headless":
			await settle()
			root.get_texture().get_image().save_png(report_dir.path_join(label + "-initial.png"))
		viewer.shell.select_workspace((expected + 2) % 3)
		viewer._open_capture(fixtures_dir.path_join(file))
		check_category(viewer, expected, kind, label + " reload")
	viewer.shell.select_workspace(2)
	viewer._open_capture(fixtures_dir.path_join("mixed.wvz"))
	check(viewer.shell.workspace == 0, "Mixed source overrides an unrelated previous Meshes tab")
	viewer.particle_layer_visible = false
	viewer.shell.select_workspace(2)
	viewer._open_capture(fixtures_dir.path_join("particle-fields.wvz"))
	check(viewer.shell.workspace == 0 and not viewer.particle_layer_visible,
		"Declared particles select Particles even when their display visibility is off")
	viewer.particle_layer_visible = true
	var preset: Dictionary = Preset.snapshot(viewer)
	var exposure: float = viewer.exposure
	viewer.exposure = 0.8
	viewer.shell.select_workspace(2)
	var result: Dictionary = Preset.apply(viewer, preset)
	check(result.error.is_empty() and is_equal_approx(viewer.exposure, exposure)
		and viewer.shell.workspace == 2, "Explicit view preset restores presentation without changing the chosen tab")
	viewer._open_capture(fixtures_dir.path_join("missing.wvz"))
	check(viewer.shell.workspace == 2, "Failed load leaves the explicitly selected tab unchanged")

func check_offline(viewer) -> void:
	viewer.shell.prepare_export({"workspace": 1, "scroll": 0, "remaining": true})
	for file in ["particles.wvz", "meshes.wvz", "mixed.wvz"]:
		viewer._open_capture(fixtures_dir.path_join(file))
		check(viewer.generic_reader != null and viewer.shell.workspace == 1 and viewer.shell.chooser.selected == 1,
			"Offline " + file + " keeps its explicit Fields export workspace")

func check_real_capture(viewer) -> void:
	viewer.shell.select_workspace((real_expected + 1) % 3)
	viewer._open_capture(real_path)
	var label := real_path.get_file()
	check_category(viewer, real_expected, ["particles", "volume", "mesh"][real_expected], label)
	check(viewer.generic_reader != null and not viewer.generic_reader.objects.is_empty(),
		label + ": real source descriptor and first sample load")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2: queue_free(); return
	fixtures_dir = args[0]; report_dir = args[1]
	offline = args.has("--offline")
	for argument in args:
		if argument.begins_with("--real-path="): real_path = argument.trim_prefix("--real-path=")
		if argument.begins_with("--real-expected="): real_expected = int(argument.trim_prefix("--real-expected="))
	get_tree().create_timer(120).timeout.connect(func(): push_error("Initial category test timed out"); get_tree().quit(1))
	await get_tree().process_frame
	var viewer = get_tree().current_scene
	if viewer == null or offline:
		viewer = Viewer.new()
		viewer.offline_instance = offline
		viewer.scene_prebuffer_enabled = false
		root.add_child(viewer)
	viewer.set_process(false)
	if offline: check_offline(viewer)
	elif not real_path.is_empty(): check_real_capture(viewer)
	else: await check_interactive(viewer)
	var report := {"checks": checks, "failures": failures, "offline": offline,
		"display_driver": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"packaged": OS.has_feature("template")}
	FileAccess.open(report_dir.path_join("report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("INITIAL CATEGORY: ", checks, " checks; failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

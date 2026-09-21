extends SceneTree
const Viewer = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []
var out := ""

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)

func _initialize() -> void:call_deferred("run")

func wait_idle(controller) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began<10000:
		await create_timer(.02).timeout
		if not controller.jobs.pending and controller.operation.is_empty():return controller.jobs.error.is_empty()
	return false

func wait_overlay(controller) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began<10000:
		await create_timer(.02).timeout
		if not controller.overlay_key.is_empty() and controller.overlay_key == controller._current_key() and not controller.jobs.pending:return true
	return false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--selection-fixture="):out = arg.trim_prefix("--selection-fixture=")
	if out.is_empty():quit(1);return
	var viewer := Viewer.new();viewer.offline_instance = true;root.add_child(viewer)
	await process_frame
	viewer._open_capture(out.path_join("fixture.ssc"));viewer.playing = false;viewer.orbit_enabled = false
	var control = viewer.selection_controller
	check(control.source.is_empty() and control.jobs.worker_pid<0,"idle viewer starts no analysis worker")
	control.bind_source()
	check(await wait_idle(control),"viewer opens source through worker")
	check(control.target.item_count == 3,"all native source objects available")
	control.kind.select(0);control.members_input.text = "7,9007199254740993"
	control.create_definition()
	check(await wait_idle(control),"exact IDs create through UI")
	check(control.state.definitions.size()==1,"selection stored")
	if control.state.definitions.is_empty():
		push_error(control.status.text);viewer.queue_free();await process_frame;quit(1);return
	var original: Dictionary = control.state.definitions[0].duplicate(true)
	check(original.selector.ids == ["7","9007199254740993"],"JSON round trip preserves exact int64 strings")
	check(await wait_overlay(control),"source overlay resolves asynchronously")
	await process_frame
	check(control.overlay.drawn == 2,"two selected source markers drawn")
	check(control.overlay.gpu_bytes<=16*1048576,"separate overlay is bounded")
	viewer.scene_layers.sample(1.0);viewer.playing = false
	check(await wait_overlay(control),"selection follows new source bracket")
	await process_frame
	var key: String = original.key
	# The dummy headless RenderingServer does not retain MultiMesh transforms.
	# Actual renderer runs additionally inspect native MultiMesh readback.
	var marker: Vector3 = control.overlay.points[key].display_positions[1]
	check(is_equal_approx(marker.x,8.),"dying ID holds earlier position while shared IDs interpolate")
	if DisplayServer.get_name() != "headless":
		check(is_equal_approx(control.overlay.layers[key].multimesh.get_instance_transform(1).origin.x,8.),"rendered marker matches source hold")
	check(control.state.definitions[0].selector.ids == original.selector.ids,"scrub never mutates fixed cohort")
	viewer.scene_layers.sample(3.0)
	check(await wait_overlay(control),"absent cohort resolves on forward seek")
	await process_frame
	check(control.overlay.drawn == 0,"absent IDs keep definitions and lose current markers")
	viewer.scene_layers.sample(0.0)
	check(await wait_overlay(control),"reverse seek restores source membership")
	viewer.particle_layer_visible = false
	await process_frame;await process_frame
	check(control.state.definitions.size()==1 and control.overlay.drawn == 0,"hide does not delete cohort")
	viewer.particle_layer_visible = true
	check(await wait_overlay(control),"visible overlay returns independently")
	control.edits.select(2);control.members_input.text = "9223372036854775807"
	control.create_definition()
	check(await wait_idle(control),"add members occurs on worker")
	check(control.state.find(key).selector.ids == ["7","9007199254740993","9223372036854775807"],"set edit retains exact upper int64")
	control.edits.select(0)
	check(control.state.group("cohort comparison",[key]),"named group references selection revision")
	check(control.state.groups[0].members[0].revision==control.state.find(key).revision,"group revision matches member")
	# Exercise captured-camera click separately from orbit input.
	control.tool.select(1);control._pick(viewer.camera.unproject_position(Vector3(7,0,0)))
	check(await wait_idle(control),"camera pick resolves through worker")
	check(control.state.definitions.size()==2,"click creates a second named selection")
	check(await wait_overlay(control),"multiple selection previews share a bounded overlay")
	control.tool.select(2)
	var press := InputEventMouseButton.new();press.button_index = MOUSE_BUTTON_LEFT;press.pressed = true;press.position = Vector2.ZERO
	var release := InputEventMouseButton.new();release.button_index = MOUSE_BUTTON_LEFT;release.pressed = false;release.position = viewer.get_viewport().get_visible_rect().size
	check(control.handle_input(press),"rectangle gesture owns pointer independently of orbit")
	var motion := InputEventMouseMotion.new();motion.position = release.position
	control.handle_input(motion)
	check(control.gesture.polygon.size()==4,"bounded rectangle outline follows pointer")
	control.handle_input(release)
	check(await wait_idle(control),"rectangle resolves captured source geometry")
	check(control.state.find(control.state.active).selector.ids == ["7","9007199254740993"],"rectangle freezes all eligible source IDs")
	control.handle_input(press)
	viewer._update_camera();viewer.yaw += .01;viewer._update_camera()
	control.handle_input(release)
	check(control.gesture.polygon.is_empty() and control.status.text.begins_with("Scene or camera changed"),"changed camera cancels gesture without relabeling its source")
	check(await wait_overlay(control),"rectangle selection overlays resolve after camera movement")
	if FileAccess.file_exists(out.path_join("derived.json")):
		var derived: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("derived.json")))
		var layers = viewer.scene_layers
		layers.states.field.isosurface = true;layers.states.field.threshold = 14.0;layers._sync_iso_target()
		layers.iso_debounce = 0;layers.iso_finished_target = layers.iso_target
		var reader = preload("res://layers/scene_reader.gd").new()
		check(reader.open(derived.path),"exact extracted artifact opens in existing renderer")
		var sample: Dictionary = reader.read_sample("isosurface",0)
		layers.iso_node = preload("res://layers/mesh_view.gd").new();layers.add_child(layers.iso_node)
		layers.iso_node.load_samples(reader.objects.isosurface,sample,sample,0,{"visible":true,"channel":"","wireframe":false},layers.layer_budget,viewer.colormaps.viridis)
		reader.close();layers.iso_result = derived
		control.target.select(1);control._select_artifact("object",{})
		check(await wait_idle(control),"derived artifact selection uses source worker")
		check(control.state.find(control.state.active).kind == "derived_surface","derived artifact never acquires particle identity")
		check(await wait_overlay(control),"approximate artifact overlay resolves")
		var artifact_key: String = control.state.active
		check(control.overlay.points[artifact_key].result.status == "approximate_artifact","derived overlay labels geometry approximation")
		layers.iso_node.visible = false
		check(not control._definition_visible(control.state.find(artifact_key)),"hidden/remeshed artifact does not retain visual hit identity")
		layers.iso_node.visible = true
	var report := {"checks":checks,"failures":failures,"backend":RenderingServer.get_current_rendering_method(),"drawn":control.overlay.drawn,"gpu_bytes":control.overlay.gpu_bytes,"status":control.status.text}
	if not DisplayServer.get_name() == "headless":
		control.panel.visible = true
		viewer.shell.refresh_export()
		var scroll: ScrollContainer = viewer.shell.scroll
		await process_frame;await process_frame
		scroll.scroll_vertical = maxi(0,int(control.panel.position.y)-30)
		await process_frame;await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("selection.png"))
	var pid: int = control.jobs.worker_pid
	viewer.queue_free();await process_frame;await create_timer(.1).timeout
	check(not DirAccess.dir_exists_absolute("/proc/%d" % pid),"viewer close leaves no selection worker")
	report.checks = checks;report.failures = failures
	var file := FileAccess.open(out.path_join("selection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t",true,true));file.close()
	print("G4 SELECTION: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

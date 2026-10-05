extends SceneTree
## Focused native Save Image check against the live scientific viewport.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var output := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func settle() -> void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw

func ready(view) -> void:
	check(await view.scene_layers.wait_for_surface(), "Scene surface is ready")
	await settle()

func wait_jobs(control) -> bool:
	var deadline := Time.get_ticks_msec()+20000
	while control.jobs.busy() and Time.get_ticks_msec() < deadline:
		await create_timer(.01).timeout
	return not control.jobs.busy() and control.jobs.error.is_empty()

func one(kind: String) -> void:
	var view = Viewer.new()
	root.add_child(view)
	view.playing = false; view.orbit_enabled = false
	view._open_capture(output.path_join(kind+".wvz"))
	view.set_process(false)
	check(view.generic_reader != null, kind+": source opens")
	if view.generic_reader == null: view.queue_free(); await process_frame; return
	await ready(view)
	view.brightness_scale = 1.35; view.gamma = 1.25; view.show_legend = true
	if kind in ["particles","mixed"]: view._choose_color("value")
	view._restyle()
	view._update_particle_legend()
	if kind in ["fields","meshes"]:
		for id in view.scene_layers.states:
			if not view.scene_layers.states[id].visible: continue
			if view.scene_layers.states[id].channel.is_empty(): view.scene_layers.states[id].channel = "value"
			view.scene_layers.legend_visibility[id] = true
			view.scene_layers.resample()
			check(await view.scene_layers.wait_for_surface(), kind+": styled surface is ready")
			view.shell.layer_legends.sync(); view.shell.reposition_legend()
			break
	view.file_locations.settings.image_dir = output
	view.tools_ui.open("Image")
	await settle()
	var before := Visual.snapshot(view)
	var world: Transform3D = view.scene_layers.transform
	var window_position: Vector2i = view.tools_ui.window.position
	var reference: Image = view._save_image_viewport()
	reference.save_png(output.path_join(kind+"-reference.png"))
	if kind == "particles":
		check(view.legend.visible, "Particle legend enabled")
		view.get_viewport().get_texture().get_image().save_png(output.path_join("particles-with-chrome.png"))
	if kind in ["fields","meshes"]: check(view.shell.layer_legends.visible, kind+": scientific layer legend enabled")
	view.screenshot_sidecar = kind == "mixed"
	await view._save_image()
	check(not view.screenshot_saving, kind+": save finishes")
	check(view.screenshot_count == 1, kind+": one Save Image capture")
	var image_path := ""
	for file in DirAccess.get_files_at(output):
		if file.begins_with("wavez-") and file.ends_with(".png"):
			image_path = output.path_join(file)
	if not image_path.is_empty():
		var saved := Image.load_from_file(image_path)
		check(saved.get_size() == reference.get_size(), kind+": image is cropped to visible viewport")
		check(saved.get_data() == reference.get_data(), kind+": pixels equal the chrome-free current presentation")
		if kind != "mixed": DirAccess.rename_absolute(image_path,output.path_join(kind+"-saved.png"))
	else: check(false,kind+": PNG written to preferred directory")
	check(Visual.snapshot(view) == before, kind+": camera and presentation state unchanged")
	check(view.scene_layers.transform == world, kind+": scientific world transform unchanged")
	check(view.tools_ui.window.visible and view.tools_ui.window.position == window_position, kind+": Tools window restored")
	if kind == "mixed":
		var recipe = JSON.parse_string(FileAccess.get_file_as_string(image_path.get_basename()+".json"))
		check(recipe is Dictionary and recipe.image.width == reference.get_width() and recipe.image.height == reference.get_height(), "Inspection sidecar records cropped dimensions")
	if kind == "particles":
		view.show_legend = false; view._restyle(); view._update_particle_legend(); await settle()
		var no_legend: Image = view._save_image_viewport()
		check(no_legend.get_data() != reference.get_data(), "Legend toggle changes captured pixels")
		view.show_legend = true; view._restyle(); view._update_particle_legend(); await settle()
		var editor_reference: Image = view._save_image_viewport()
		view.shell.edit_orbit_center(); await settle()
		var edit_state := Visual.snapshot(view)
		await view._save_image()
		check(view.shell.orbit_editor.visible and Visual.snapshot(view) == edit_state, "Save Image preserves open orbit editor and camera")
		var edited_png := ""
		for file in DirAccess.get_files_at(output):
			if file.begins_with("wavez-") and file.ends_with(".png"): edited_png = output.path_join(file)
		check(not edited_png.is_empty() and Image.load_from_file(edited_png).get_data() == editor_reference.get_data(), "Orbit editor chrome and gizmo are excluded")
		if not edited_png.is_empty(): DirAccess.rename_absolute(edited_png,output.path_join("particles-editor-saved.png"))
		view.shell.dismiss_orbit_editor(); await settle()
		view._dispatch_shortcut("save_image")
		for frame in 60:
			if not view.screenshot_saving and view.screenshot_count == 3: break
			await process_frame
		check(view.screenshot_count == 3 and not view.screenshot_saving, "Save Image shortcut dispatch uses the configured directory")
		for file in DirAccess.get_files_at(output):
			if file.begins_with("wavez-") and file.ends_with(".png"):
				check(Image.load_from_file(output.path_join(file)).get_size() == reference.get_size(), "Shortcut image uses viewport crop")
				DirAccess.rename_absolute(output.path_join(file),output.path_join("particles-shortcut-saved.png"))
		view.tools_ui.close(false)
		view.shell.toggle_dock(); await settle()
		var wide_reference: Image = view._save_image_viewport()
		check(wide_reference.get_width() == view.get_viewport().get_visible_rect().size.x, "Hidden dock expands saved viewport width")
		await view._save_image()
		for file in DirAccess.get_files_at(output):
			if file.begins_with("wavez-") and file.ends_with(".png"):
				check(Image.load_from_file(output.path_join(file)).get_data() == wide_reference.get_data(), "Hidden-dock pixels match current viewport")
				DirAccess.rename_absolute(output.path_join(file),output.path_join("particles-wide-saved.png"))
		var control = view.selection_controller
		control.bind_source()
		check(await wait_jobs(control), "Selection source binds for durable Save Image")
		control._request("define_selection",{"key":"selected","object":"p","kind":"particle_ids","selector":{"ids":["7"]}})
		check(await wait_jobs(control) and not control.state.definitions.is_empty(), "Particle selection commits")
		var selected_size: Vector2i = view._save_image_viewport().get_size()
		view.screenshot_sidecar = true
		await view._save_image()
		var durable_png := ""
		for file in DirAccess.get_files_at(output):
			if file.begins_with("wavez-") and file.ends_with(".png"): durable_png = output.path_join(file)
		check(not durable_png.is_empty() and DirAccess.dir_exists_absolute(durable_png.get_basename()+".inspection"), "Durable sidecar publishes with cropped PNG")
		if not durable_png.is_empty():
			var durable_size: Vector2i = Image.load_from_file(durable_png).get_size()
			check(durable_size.y == selected_size.y and durable_size.x <= view.get_viewport().get_visible_rect().size.x, "Selection-aware image excludes top and bottom chrome")
			var manifest = JSON.parse_string(FileAccess.get_file_as_string(durable_png.get_basename()+".inspection/inspection.json"))
			check(manifest is Dictionary and int(manifest.payload.base.render.dimensions[0]) == durable_size.x
				and int(manifest.payload.base.render.dimensions[1]) == durable_size.y
				and manifest.payload.base.render.image.sha256 == FileAccess.get_sha256(durable_png), "Durable sidecar verifies cropped dimensions and PNG hash")
	view.queue_free(); await process_frame
	RenderingServer.force_draw(false); await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-image-output="): output = arg.trim_prefix("--save-image-output=")
	if output.is_empty(): quit(1); return
	for kind in ["particles","fields","meshes","mixed"]: await one(kind)
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("SAVE IMAGE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

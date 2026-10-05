extends SceneTree
## Native idle-render regression. No pushed input or forced draws wake capture.
## Owner physical shortcut/menu verification is still an acceptance requirement.
const Visual = preload("res://scene/visual_state.gd")
class ReadbackViewer extends "res://main.gd":
	var fail_readback := false
	func _save_image_viewport() -> Image:
		var image := super._save_image_viewport()
		return null if fail_readback else image

var output := ""
var checks := 0
var failures: Array[String] = []
var draws := 0
var samples: Array[Dictionary] = []
var captures: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func idle(view, label: String) -> bool:
	# Use timers, not frame_post_draw: reaching zero draws is the precondition.
	var last := {}
	for attempt in 10:
		var first := draws
		var processes := Engine.get_process_frames()
		await create_timer(.6).timeout
		last = {"case":label,"draws":draws-first,"process_frames":Engine.get_process_frames()-processes,
			"low_processor":OS.low_processor_usage_mode,"viewer_processing":view.is_processing()}
		if last.draws == 0 and last.process_frames > 0 and last.low_processor and last.viewer_processing:
			samples.append(last); return true
	samples.append(last)
	check(false,label+": live production viewer reaches zero-draw idle before capture")
	return false

func shell_state(view) -> Dictionary:
	var shell = view.shell
	return {"immersive":shell.immersive,"shell":shell.visible,"edges":shell.edge_reveal.states.duplicate(true),
		"pointer_inside":shell.edge_reveal.pointer_inside,"keyboard_navigation":shell.edge_reveal.keyboard_navigation,
		"popup":shell.edge_reveal.popup_active(view),"focus":root.gui_get_focus_owner(),
		"bar":[shell.bar.visible,shell.bar.get_rect()],"dock":[shell.dock.visible,shell.dock.get_rect()],
		"handle":[view.resize_handle.visible,view.resize_handle.get_rect()],
		"bottom":[shell.bottom_strip.visible,shell.transport.get_rect()],"legend_available":shell.legend_available,
		"legend":[view.legend.get_rect(),view.colorbar.get_rect(),shell.particle_legend_panel.get_rect()],
		"tools":[view.tools_ui.window.visible,view.tools_ui.window.position,view.tools_ui.window.size,view.tools_ui.window.gui_get_focus_owner()]}

func save(view, label: String, menu := false, fail := false) -> Image:
	var directory := output.path_join(label)
	DirAccess.make_dir_recursive_absolute(directory)
	view.file_locations.settings.image_dir = directory
	view.fail_readback = fail
	if not await idle(view,label): return null
	var before := shell_state(view)
	var visual := Visual.snapshot(view)
	var world: Transform3D = view.scene_layers.transform
	var extent := Vector2i(root.get_visible_rect().size)
	var start := Time.get_ticks_msec()
	var first := draws
	var count: int = view.screenshot_count
	# Call the same command/button callbacks without synthesizing OS input that
	# could schedule a render and mask the stalled frame_post_draw wait.
	if menu: view.tools_ui.find_button(view.tools_ui.footer,"Save image…").pressed.emit()
	else: view._dispatch_shortcut("save_image")
	while view.screenshot_saving and Time.get_ticks_msec()-start < 5000:
		await create_timer(.01).timeout
	var elapsed := Time.get_ticks_msec()-start
	check(not view.screenshot_saving and not view.inspection_busy,label+": capture releases busy/saving without another input or window event")
	check(view.screenshot_count == count+1,label+": command starts exactly one capture")
	check(view.shell.immersive and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,label+": capture finishes while still fullscreen")
	check(OS.low_processor_usage_mode,label+": capture preserves low-processor policy")
	check(shell_state(view) == before,label+": capture restores chrome, edge-reveal, popup, layout and focus state")
	check(Visual.snapshot(view) == visual and view.scene_layers.transform == world,label+": camera, sample and scientific world state unchanged")
	var files: Array[String] = []
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".png"): files.append(directory.path_join(file))
	var image: Image
	if fail:
		check(files.is_empty() and view.status_label.text.begins_with("Could not save PNG:"),label+": readback failure publishes no PNG and reports failure")
	else:
		check(files.size() == 1,label+": PNG is published")
		if files.size() == 1:
			image = Image.load_from_file(files[0])
			check(image.get_size() == extent,label+": PNG uses the complete fullscreen resolution")
			if view.screenshot_sidecar:
				var manifest = JSON.parse_string(FileAccess.get_file_as_string(files[0].get_basename()+".inspection/inspection.json"))
				check(manifest is Dictionary and int(manifest.payload.base.render.dimensions[0]) == extent.x
					and int(manifest.payload.base.render.dimensions[1]) == extent.y
					and manifest.payload.base.render.image.sha256 == FileAccess.get_sha256(files[0]),label+": durable sidecar verifies fullscreen dimensions and hash")
	captures.append({"case":label,"elapsed_ms":elapsed,"draws":draws-first,"busy":view.inspection_busy,
		"saving":view.screenshot_saving,"dimensions":[image.get_width(),image.get_height()] if image != null else []})
	view.fail_readback = false
	return image

func wait_jobs(control) -> bool:
	var deadline := Time.get_ticks_msec()+20000
	while control.jobs.busy() and Time.get_ticks_msec() < deadline: await create_timer(.01).timeout
	return not control.jobs.busy() and control.jobs.error.is_empty()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-image-output="): output = arg.trim_prefix("--save-image-output=")
	if output.is_empty(): quit(1); return
	RenderingServer.frame_post_draw.connect(func(): draws += 1)
	var view := ReadbackViewer.new()
	view.capture_path = output.path_join("particles.wvz")
	root.add_child(view)
	check(view.generic_reader != null,"Source opens")
	if view.generic_reader == null: finish(view); return
	view.playing = false; view.orbit_enabled = false
	view.show_legend = true; view._choose_color("value"); view._restyle(); view._update_particle_legend()
	check(await view.scene_layers.wait_for_surface(),"Source surface is ready")
	view.shell.enter_immersive()
	view.shell.edge_reveal.pointer_inside = false
	await create_timer(1.0).timeout
	var reference := await save(view,"shortcut")
	if reference == null: finish(view); return
	# Secondary input regression after a completed idle capture. This is not a
	# substitute for the owner's physical double-click test.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.double_click = true
	click.position = Vector2(root.size)*.5
	root.push_input(click)
	check(not view.shell.immersive,"Double-click exits fullscreen immediately after idle capture")
	await create_timer(.4).timeout
	view.shell.enter_immersive(); await create_timer(.4).timeout
	view.shell.edge_reveal.tick(.6,Vector2(100,0),true,false)
	view.shell.invoke_shortcut_command("image")
	var button: Button = view.tools_ui.find_button(view.tools_ui.footer,"Save image…")
	button.grab_focus()
	check(view.shell.bar.visible and view.shell.bar.size.y == 48 and view.tools_ui.window.visible,"File Image route exposes the 48 px bar and export dialog")
	var menu := await save(view,"menu",true)
	check(menu != null and menu.get_data() == reference.get_data(),"File-menu and shortcut fullscreen composition are pixel-identical")
	# Any revealed edge is presentation chrome, including the legend displacement
	# caused by a temporarily visible Simulation dock or bottom transport.
	for side in view.shell.edge_reveal.states: view.shell.edge_reveal.states[side].visible = true
	view.shell.layout()
	var revealed := await save(view,"all-edges",true)
	check(revealed != null and revealed.get_data() == reference.get_data(),"All revealed edges preserve the same fullscreen composition and scientific legend")
	await save(view,"failed-readback",true,true)
	view.tools_ui.close(false)
	var control = view.selection_controller
	control.bind_source()
	check(await wait_jobs(control),"Selection source binds for durable idle capture")
	control._request("define_selection",{"key":"selected","object":"p","kind":"particle_ids","selector":{"ids":["7"]}})
	check(await wait_jobs(control) and not control.state.definitions.is_empty(),"Selection commits for durable idle capture")
	check(await control.await_committed_overlay(),"Exact selection overlay is ready")
	# Visible markers currently upload transforms each tick. Hide the preview
	# through its presentation state to exercise the real idle durable path;
	# the selections and their verified bundle remain present.
	control.state.overlay.visible = false
	control.state.revision += 1
	view.screenshot_sidecar = true
	await save(view,"durable-shortcut")
	await save(view,"durable-failed-readback",false,true)
	finish(view)

func finish(view) -> void:
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),
		"display_driver":DisplayServer.get_name(),"idle_samples":samples,"captures":captures,
		"physical_owner_verification":"pending"}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("IDLE SAVE IMAGE: ",checks," checks, ",failures.size()," failures")
	view.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)

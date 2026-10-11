extends SceneTree
## Exercise actual Control/Window dispatch, including clicks before a double-click.
const Visual = preload("res://scene/visual_state.gd")
const Preset = preload("res://scene/view_preset.gd")
const FloatText = preload("res://ui/components/float64_text.gd")
var viewer
var slider
var output := ""
var checks := 0
var failures: Array[String] = []
var visuals := []
var ui_sizes := []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle() -> void:
	for i in 6: await process_frame
func key(window: Window, code: Key, shift := false, pressed := true) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code
	event.pressed = pressed; event.shift_pressed = shift; window.push_input(event)
func mouse(point: Vector2, pressed: bool, double := false, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new(); event.position = point; event.global_position = point
	event.pressed = pressed; event.button_index = button; event.double_click = double
	root.push_input(event)
func thumb() -> Vector2: return slider.global_position + slider.thumb_rect().get_center()
func double_thumb() -> void:
	var point := thumb()
	mouse(point, true); mouse(point, false); mouse(point, true, true); mouse(point, false)
	await settle()
func submit(text: String) -> void:
	slider.popover.editor.text = text
	key(slider.popover, KEY_ENTER); key(slider.popover, KEY_ENTER, false, false)
	await settle()
func protected() -> Dictionary:
	return {"sample":viewer.committed_sample.duplicate(true),"time":viewer.requested_time,
		"selection":viewer.selection_controller.state.snapshot(),"jobs":viewer.selection_controller.jobs.serial,
		"camera":viewer.camera.transform,"scene":viewer.scene_layers.snapshot(),
		"exposure":viewer.exposure,"brightness":viewer.brightness_scale,"gamma":viewer.gamma,
		"environment":Visual.snapshot(viewer).environment,"playing":viewer.playing}
func synchronized(expected: float, label: String) -> void:
	check(viewer.point_scale == expected and slider.value == expected and slider.readout.text == FloatText.format_value(expected), label)
	for material in viewer.particle_materials:
		check(is_equal_approx(material.get_shader_parameter("point_scale"), expected), label + " shader uniform")

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(220).timeout.connect(func(): push_error("Particle-size timeout"); quit(1))
	viewer = load("res://main.gd").new(); viewer.scene_prebuffer_enabled = false
	root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("mixed.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	viewer.sections.Rendering.show(); viewer.section_buttons.Rendering.set_pressed_no_signal(true)
	slider = viewer.visual_sliders["Particle size"]; await settle()
	check(RenderingServer.get_current_rendering_method() == "forward_plus" and RenderingServer.get_current_rendering_driver_name() == "vulkan", "Supported renderer")
	synchronized(1.8, "Default remains 1.8")
	check(slider.min_value == .01 and slider.max_value == 8 and slider.step == 0, "Bounds and unquantized precision")
	var before := protected()
	slider.value = .0251234567890123; await settle()
	var precise: float = slider.value
	await double_thumb()
	check(slider.popover.visible and slider.popover.gui_get_focus_owner() == slider.popover.editor, "Double-click thumb focuses numeric entry")
	key(slider.popover, KEY_TAB); await settle()
	check(slider.popover.gui_get_focus_owner() == slider.popover.editor, "Tab remains within compact numeric editor")
	synchronized(precise, "First click and double-click preserve exact selected value")
	check(not viewer.dragging and not viewer.free_look_dragging and not slider.thumb_drag, "Opening editor creates no camera/slider gesture")
	for draft in ["nope", "NaN", "inf", "1e9999", "0.009", "8.00001", ""]:
		await submit(draft)
		check(slider.popover.visible and slider.popover.error_label.visible and slider.popover.editor.text == draft, "Invalid draft retained: " + draft)
		synchronized(precise, "Invalid draft preserves value: " + draft)
	check(slider.popover.editor.theme_type_variation == "InvalidNumericInput", "Semantic invalid state")
	key(slider.popover, KEY_ESCAPE); await settle()
	check(not slider.popover.visible and root.gui_get_focus_owner() == slider, "Escape cancels and restores slider focus")
	synchronized(precise, "Cancel preserves exact value")
	await double_thumb(); await submit("0.0251234567890123")
	check(not slider.popover.visible, "Enter accepts unchanged exact prefill")
	for text in ["0.01", "2.5e-2", "0.05", "0.1", "8", "0.01234567890123456"]:
		await double_thumb(); await submit(text)
		synchronized(FloatText.parse(text).value, "Exact manual entry " + text)
		check(not slider.popover.visible, "Valid Enter closes editor")
	check(protected() == before, "Size edits preserve scientific sample, selection/jobs, camera, environment and playback")
	# Track double-clicks retain ordinary slider behavior and never open the editor.
	slider.value = .01; await settle()
	mouse(slider.global_position + Vector2(slider.size.x * .8, slider.size.y * .5), true, true)
	mouse(slider.global_position + Vector2(slider.size.x * .8, slider.size.y * .5), false); await settle()
	check(not slider.popover.visible and slider.value > .01 and not viewer.dragging, "Off-thumb double-click stays on the track")
	# A one-pixel thumb drag at the minimum should make a genuinely small change.
	slider.value = .01; await settle()
	var start := thumb(); mouse(start, true)
	var motion := InputEventMouseMotion.new(); motion.position = start + Vector2(1,0); motion.relative = Vector2(1,0); motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion); mouse(motion.position, false); await settle()
	check(slider.value > .01 and slider.value < .011, "One-pixel drag resolves the low end below 0.001")
	synchronized(slider.value, "Drag readout updates continuously")
	var drag_value: float = slider.value
	key(root, KEY_RIGHT); await settle()
	check(slider.value > drag_value and slider.value - drag_value < .001, "Arrow key gives fine logarithmic increment")
	var coarse: float = slider.value; key(root, KEY_RIGHT, true); await settle()
	check(slider.value > coarse and slider.value - coarse < (coarse - drag_value) / 5, "Shift-arrow is finer")
	key(root, KEY_END); synchronized(8, "End selects upper endpoint")
	key(root, KEY_HOME); synchronized(.01, "Home selects lower endpoint")
	key(root, KEY_ENTER); await settle(); check(slider.popover.visible, "Keyboard opens exact entry")
	# Physically held movement must remain blocked throughout numeric entry.
	var held := InputEventKey.new(); held.keycode = KEY_W; held.physical_keycode = KEY_W; held.pressed = true
	Input.parse_input_event(held); await settle()
	var camera: Transform3D = viewer.camera.transform
	viewer._move_free_camera(.25)
	check(viewer.camera.transform == camera, "Held W cannot move camera while editing")
	held.pressed = false; Input.parse_input_event(held); await settle()
	await submit("0.0251234567890123")
	check(not viewer.playing, "Keyboard entry does not toggle playback")
	# Portable preset save/load and native visual snapshots preserve small exact values.
	var path := output.path_join("small-preset.json")
	check(viewer._save_inspection(path) == OK, "Save preset below old minimum")
	var state := Visual.snapshot(viewer); slider.value = 3
	check(viewer._load_inspection(path).is_empty(), "Load preset below old minimum")
	synchronized(precise, "Preset restore synchronizes exact readout")
	slider.value = 2; Visual.apply(viewer, state); await settle()
	synchronized(precise, "Visual-state restore synchronizes exact readout")
	await double_thumb(); slider.popover.editor.text = "5"
	viewer.point_scale = .05; viewer._sync_visuals(); await settle()
	check(not slider.popover.visible, "External value change dismisses stale draft")
	synchronized(.05, "External synchronization")
	var invalid := Preset.snapshot(viewer); invalid.settings.view.point_scale = .009
	check(not Preset.apply(viewer, invalid).error.is_empty(), "Preset rejects below lower bound")
	synchronized(.05, "Invalid preset is transactional")
	await double_thumb(); slider.popover.editor.text = "7"
	mouse(Vector2(400,400), true); mouse(Vector2(400,400), false); await settle()
	check(not slider.popover.visible, "Outside click dismisses draft")
	synchronized(.05, "Outside dismissal preserves value")
	for light in [true, false]:
		viewer.shell.appearance.light = light; viewer.shell.appearance.apply(); await settle()
		await double_thumb(); await submit("NaN")
		check(slider.popover.editor.get_theme_color("font_color") != slider.popover.error_label.get_theme_color("font_color"), "Readable semantic error in theme " + str(light))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("ui-error-%s.png" % ("light" if light else "dark")))
		key(slider.popover, KEY_ESCAPE); await settle()
	viewer._set_clean(true); synchronized(.05, "Scientific preset preserves particle size")
	viewer._set_clean(false); synchronized(.05, "Cinematic preset preserves particle size")
	for extent in [Vector2i(960,640),Vector2i(1920,1080),Vector2i(3840,2160)]:
		root.size = extent; await settle(); slider.value = precise; await settle()
		check(slider.readout.size.x >= slider.readout.get_combined_minimum_size().x and slider.readout.get_line_count() == 1 and slider.get_global_rect().end.x <= root.size.x, "Exact readout fits on one line at " + str(extent))
		await double_thumb()
		check(slider.popover.visible and slider.popover.size.x >= 224 and slider.popover.position.x >= 0 and slider.popover.position.y >= 0, "Entry remains visible after resize " + str(extent))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("ui-%dx%d.png" % [extent.x,extent.y]))
		key(slider.popover, KEY_ESCAPE); await settle()
		var actual := root.get_texture().get_image().get_size()
		ui_sizes.append({"requested":str(extent),"actual":str(actual)})
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("ui-slider-%dx%d.png" % [actual.x,actual.y]))
	check(slider.tooltip_text.is_empty() and slider.readout.tooltip_text.is_empty() and slider.popover.editor.tooltip_text.is_empty(), "No unsolicited tooltips")
	if "dense" in OS.get_cmdline_user_args(): await render_dense()
	var report := {"checks":checks,"failures":failures,"visuals":visuals,"ui_sizes":ui_sizes,"renderer":"Forward+ Vulkan","version":ProjectSettings.get_setting("application/config/version")}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	viewer._clear_manual_navigation(); viewer.queue_free(); await settle()
	print("Particle size: ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)

func render_dense() -> void:
	# The desktop may clamp oversized native windows. Share the production 3D
	# world with an explicit render target to obtain true 1080p and 4K pixels.
	var viewport := SubViewport.new(); viewport.world_3d = root.world_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var render_camera := Camera3D.new(); viewport.add_child(render_camera); render_camera.make_current()
	viewer.overlay_panel.hide(); viewer.shell.dock.hide(); viewer.guide_mesh.hide(); viewer.shell.bottom_strip.hide(); viewer.shell.bar.hide()
	viewer._set_clean(true); viewer.brightness_scale = 1; viewer.exposure = 1; viewer.gamma = 1
	viewer.environment.glow_enabled = false; viewer.environment.fog_enabled = false
	viewer.environment.background_mode = Environment.BG_COLOR; viewer.environment.background_color = Color.BLACK
	viewer.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.msaa_3d = Viewport.MSAA_DISABLED; root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED; root.use_taa = false; root.use_debanding = false
	for fixture in ["dense","marker"]:
		viewer._open_capture(output.path_join(fixture + ".wvz")); viewer.playing = false; viewer.orbit_enabled = false
		viewer._set_clean(true); viewer.guide_mesh.hide(); viewer.hud.hide(); viewer.legend.hide()
		viewer.shell.dock.hide(); viewer.shell.bottom_strip.hide(); viewer.shell.bar.hide()
		viewer.camera.position = Vector3(0,0,6); viewer.camera.look_at(Vector3.ZERO)
		viewer.camera.fov = 55; viewer.camera.near = .01; viewer.camera.far = 100
		render_camera.transform = viewer.camera.transform; render_camera.fov = viewer.camera.fov
		render_camera.near = viewer.camera.near; render_camera.far = viewer.camera.far
		viewer.exposure = 1; viewer.gamma = 1; viewer.brightness_scale = 1; viewer._sync_visuals()
		for extent in [Vector2i(1920,1080),Vector2i(3840,2160)]:
			viewport.size = extent; await settle()
			# Opening/resizing can re-show shell chrome; remove it before every image.
			viewer.shell.dock.hide(); viewer.shell.bottom_strip.hide(); viewer.shell.bar.hide(); viewer.hud.hide()
			for scale in [.01,.025,.05,.1,1.8]:
				slider.value = scale; await settle(); await RenderingServer.frame_post_draw
				var name := "%s-%dx%d-%s.png" % [fixture,extent.x,extent.y,str(scale)]
				var image := viewport.get_texture().get_image()
				check(image.get_size() == extent, "Dense target has actual requested pixels " + name)
				image.save_png(output.path_join(name))
				var result := {"file":name,"point_scale":scale,"camera":Visual.vec(viewer.camera.position),"fov":viewer.camera.fov,"count":viewer.particle_count,"model_scale":viewer.current_mm.get_instance_transform(0).basis.get_scale().x,"actual_size":str(image.get_size())}
				if fixture == "marker" and scale <= .1:
					var phases := []
					var pixel_world: float = 2.0 * 6.0 * tan(deg_to_rad(55.0) * .5) / extent.y
					for fraction in [0.0,.25,.5,.75,1.0]:
						render_camera.position.x = pixel_world * fraction
						render_camera.position.y = pixel_world * fraction
						await settle(); await RenderingServer.frame_post_draw
						var shifted := viewport.get_texture().get_image()
						var lit := 0; var peak := 0
						for y in range(extent.y/2-8,extent.y/2+8):
							for x in range(extent.x/2-8,extent.x/2+8):
								var color := shifted.get_pixel(x,y)
								var signal_value := roundi(maxf(color.r,maxf(color.g,color.b))*255)
								if signal_value > 0: lit += 1
								peak = maxi(peak,signal_value)
						phases.append({"diagonal_pixel_shift":fraction,"lit_pixels":lit,"peak_byte":peak})
					result.pixel_phases = phases
					render_camera.position.x = 0; render_camera.position.y = 0
				visuals.append(result)
	viewport.queue_free(); await settle()

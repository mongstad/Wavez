extends SceneTree
const VisualState = preload("res://scene/visual_state.gd")
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func presentation(viewer) -> Dictionary:
	var state := VisualState.snapshot(viewer)
	return {"environment":state.environment, "background_color":viewer.environment.background_color,
		"preset":state.preset,
		"exposure":viewer.exposure, "bloom_editable":viewer.glow_slider.editable}

func run() -> void:
	var viewer = load("res://main.gd").new()
	viewer.offline_instance = true
	root.add_child(viewer)
	viewer.set_process(false)
	await process_frame
	for preset in ["Scientific", "Cinematic"]:
		viewer._apply_preset(preset)
		check(viewer.environment.glow_enabled == (preset == "Cinematic"), preset + " preset bloom")
		check(viewer.environment.background_mode == (Environment.BG_SKY if preset == "Cinematic" else Environment.BG_COLOR), preset + " preset backdrop")
		viewer.environment.glow_intensity = 0.73
		viewer.environment.tonemap_exposure = 1.27
		viewer.exposure = 1.61
		var before := presentation(viewer)
		for points in [true, false]:
			viewer.control_checks["Point rendering"].button_pressed = points
			check(viewer.clean_view == points, preset + " checkbox changes particle representation")
			check(presentation(viewer) == before, preset + " checkbox preserves presentation")
			for material in viewer.particle_materials:
				check(material.get_shader_parameter("clean_view") == points, preset + " particle shader updated")
			var saved := VisualState.snapshot(viewer)
			viewer._apply_preset("Cinematic" if preset == "Scientific" else "Scientific")
			VisualState.apply(viewer, saved)
			check(VisualState.snapshot(viewer) == saved, preset + " visual recipe round trip")
			check(presentation(viewer) == before, preset + " restored presentation and bloom control")
			check(viewer.control_checks["Point rendering"].button_pressed == points, preset + " restored checkbox")
			var event := InputEventKey.new()
			event.keycode = KEY_V
			event.pressed = true
			viewer._unhandled_input(event)
			check(viewer.clean_view != points, preset + " V toggles particles")
			check(presentation(viewer) == before, preset + " V preserves presentation")
			viewer._unhandled_input(event)
			check(VisualState.snapshot(viewer) == saved, preset + " V round trip")
	if DisplayServer.get_name() != "headless":
		# Finish the sky draw before teardown (Compatibility owns filter textures).
		await process_frame
		await RenderingServer.frame_post_draw
	viewer.queue_free()
	await process_frame
	print("POINT RENDERING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

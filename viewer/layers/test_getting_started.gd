extends Node
## Focused onboarding checks: real opening, clocks, GPU resources and pixels.
var output := ""
var checks := 0
var failures: Array[String] = []
var scenes: Array = []
var view

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--getting-output="): output = arg.trim_prefix("--getting-output=")
	if not output.is_empty(): run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func draw() -> Image:
	for i in 4: await get_tree().process_frame
	RenderingServer.force_draw(false)
	return get_tree().root.get_texture().get_image()

func geometry_only() -> void:
	view._set_clean(true)
	view.shell.hide(); view.overlay_panel.hide(); view.resize_handle.hide()
	view.legend.hide(); view.colorbar.hide()
	view.guide_visibility.data = false; view.guide_visibility.domain = false
	view.guide_visibility.absorber = false; view._apply_geometry()

func hide_layers() -> void:
	view.current_instance.visible = false
	for instance in view.trail_instances: instance.visible = false
	for layer in view.scene_layers.views.values():
		if layer is MeshInstance3D: layer.visible = false
		else: layer.quad.visible = false; layer.slice.visible = false

func changed_pixels(first: Image, second: Image) -> int:
	var count := 0
	for y in range(0,first.get_height(),2):
		for x in range(0,first.get_width(),2):
			var a := first.get_pixel(x,y); var b := second.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > .02: count += 1
	return count

func run() -> void:
	check(DisplayServer.get_name() != "headless", "GPU display required")
	if not failures.is_empty(): get_tree().quit(1); return
	get_tree().create_timer(90).timeout.connect(func(): push_error("Getting Started watchdog expired"); get_tree().quit(1))
	await get_tree().process_frame
	view = get_tree().current_scene
	if view == null:
		view = load("res://main.gd").new(); get_tree().root.add_child(view)
	view.set_process(false)
	for name in ["particles", "field", "mesh", "combined"]:
		view._open_capture(output.path_join(name+".wvz"))
		check(view.generic_reader != null and view.scene_layers != null and view.frame_count == 3, name+": opens with three union times")
		if view.scene_layers == null: continue
		check(not view.playing and view.requested_time == 0, name+": starts paused at zero")
		view.shell.show()
		check((await draw()).save_png(output.path_join(name+"-opening.png")) == OK, name+": opening screenshot")
		var clocks: Array = []
		for time in [0.25, 0.5, 1.0]:
			var sample: Dictionary = view.scene_layers.sample(time)
			check(not sample.is_empty(), name+": sample "+str(time))
			var committed: Dictionary = view.committed_sample.duplicate(true)
			check(committed.get("layers",[]).size() == view.generic_reader.objects.size(), name+": every object has a committed clock")
			clocks.append(committed)
			for layer in committed.get("layers",[]):
				check(layer.visible and layer.status != "unavailable", name+": "+layer.id+" available at "+str(time))
				if name == "combined" and layer.id == "field":
					check(layer.source_time == (1.0 if time == 1.0 else 0.0), "Combined field uses its independent source time")
				if layer.kind == "particles": check(view.current_mm.instance_count == 3, name+": three GPU particles")
				elif layer.kind == "volume":
					check(view.scene_layers.views[layer.id].texture != null and view.scene_layers.views[layer.id].grid_size == Vector3(11,7,5), name+": noncubic grid uploaded in xyz")
				else: check(view.scene_layers.views[layer.id].mesh != null, name+": triangle uploaded")
		geometry_only()
		hide_layers(); var empty := await draw()
		var pixels := {}
		for id in view.generic_reader.objects:
			hide_layers()
			var kind: String = view.generic_reader.objects[id].kind
			if kind == "particles": view.current_instance.visible = true
			elif kind == "volume": view.scene_layers.views[id].quad.visible = true
			else: view.scene_layers.views[id].visible = true
			var image := await draw()
			pixels[id] = changed_pixels(empty,image)
			check(pixels[id] > 5, name+": "+id+" contributes visible pixels")
			check(image.save_png(output.path_join(name+"-"+id+".png")) == OK, name+": layer screenshot")
		view.scene_layers.resample()
		check((await draw()).save_png(output.path_join(name+"-scene.png")) == OK, name+": scene screenshot")
		scenes.append({"name":name,"clocks":clocks,"visible_pixel_samples":pixels})
	view.queue_free()
	for i in 4: await get_tree().process_frame
	RenderingServer.force_draw(false)
	var report := {"checks":checks,"failures":failures,"scenes":scenes,"renderer":RenderingServer.get_current_rendering_method(),"packaged":not OS.has_feature("editor")}
	var file := FileAccess.open(output.path_join("viewer-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print("GETTING STARTED: ",checks," checks, ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

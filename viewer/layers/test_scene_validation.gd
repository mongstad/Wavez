extends SceneTree
const R = preload("res://layers/scene_reader.gd")
const I = preload("res://scene/inspection_state.gd")
const Job = preload("res://video/render_job.gd")
var checks := 0
var failures := 0
var evidence := {}
var view
var vp: SubViewport
var base: String
func check(value: bool, label: String) -> void:
	checks += 1
	if value:print("PASS: ",label)
	else:failures += 1;push_error("FAIL: "+label)
func _initialize() -> void:run.call_deferred()
func draw() -> Image:
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image();vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return image
func setup_capture(name: String) -> void:
	view._open_capture(base.path_join(name));view.playing = false;view.orbit_enabled = false;view._set_clean(true)
	view.overlay_panel.visible = false;view.show_panel_button.visible = false;view.resize_handle.visible = false;view.legend.visible = false;view.colorbar.visible = false
	view.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR;view.environment.tonemap_exposure = 1
	vp.msaa_3d = Viewport.MSAA_DISABLED;vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED;vp.use_taa = false;vp.use_debanding = false
	view.camera.near = .01;view.camera.far = 300
func camera_at(position: Vector3, target: Vector3) -> void:
	view.camera.position = position;view.camera.look_at(target,Vector3.UP if absf((target-position).normalized().y)<.9 else Vector3.BACK)
func run() -> void:
	if DisplayServer.get_name() == "headless":push_error("Requires actual GPU");quit(1);return
	create_timer(120).timeout.connect(func():push_error("G3 test watchdog expired");quit(1))
	base = ProjectSettings.globalize_path("res://../results/g3")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene-fixture="):base = arg.trim_prefix("--scene-fixture=")
	vp = SubViewport.new();vp.size = Vector2i(512,512);vp.own_world_3d = true;vp.render_target_update_mode = SubViewport.UPDATE_DISABLED;root.add_child(vp)
	view = load("res://main.gd").new();view.offline_instance = true;view.capture_path = base.path_join("small.ssc");vp.add_child(view)
	setup_capture("small.ssc")
	check(view.frame_a != null and view.frame_count == 9,"SIMSCP3 opens with independent union clock")
	view.scene_layers.sample(.55)
	check(view.committed_sample.layers[0].status == "interpolated by ID" and view.committed_sample.layers[1].status == "interpolated" and view.committed_sample.layers[2].source_time == 0,"I14 independent particle / mesh / held volume times")
	check(view.frame_a.ids[0]>=9007199254740993,"Exact >2^53 particle IDs survive scene reader")
	var mesh = view.scene_layers.views.surface
	var a: Dictionary = view.generic_reader.read_sample("surface",0)
	var b: Dictionary = view.generic_reader.read_sample("surface",1)
	var source := Vector3(a.channels.position[0],a.channels.position[1],a.channels.position[2]);var next := Vector3(b.channels.position[0],b.channels.position[1],b.channels.position[2])
	check(mesh.source_positions[0].is_equal_approx(source.lerp(next,.55/2)),"V09 explicit vertex-ID position interpolation")
	check(mesh.normal_values[0].dot(Vector3.RIGHT)>.98,"V09 outward analytic torus normal")
	var state: Dictionary = view.scene_layers.states.surface.duplicate(true);var changed := b.duplicate(true);changed.channels.triangles = PackedInt32Array([0,1,2])
	check(mesh.load_samples(view.generic_reader.objects.surface,a,changed,.5,state,1000000,view.colormaps.viridis)=="held","V10 topology change is discrete")
	changed = b.duplicate(true);changed.channels.vertex_id.reverse()
	check(mesh.load_samples(view.generic_reader.objects.surface,a,changed,.5,state,1000000,view.colormaps.viridis)=="held","V10 unrelated vertex IDs are never blended")
	check(mesh.load_samples(view.generic_reader.objects.surface,a,changed,.5,state,1,view.colormaps.viridis)=="unavailable" and mesh.gpu_bytes==0,"V07 lowering mesh budget releases a previously cached mesh")
	view.scene_layers.resample()
	var recipe := I.snapshot(view);check(recipe.version == 2 and recipe.layers.size() == 3,"Layer recipe records actual objects")
	view.scene_layers.states.density.opacity = .7;view.scene_layers.sample(1.5)
	check(I.restore(view,recipe).is_empty() and is_equal_approx(view.requested_time,.55) and is_equal_approx(view.scene_layers.states.density.opacity,.25),"Scene inspection restores clock and display parameters")
	var invalid := recipe.duplicate(true);invalid.visual.scene.layers.density.step = -1
	check(not I.restore(view,invalid).is_empty() and view.requested_time == .55,"Malformed scene recipe rejected before mutation")
	view.scene_layers.request_iso("density")
	view.scene_layers.states.density.threshold = .6;view.scene_layers._sync_iso_target()
	check(await view.scene_layers.wait_for_surface(),"V13 threshold supersedes stale worker")
	check(view.scene_layers.iso_result.provenance.threshold == .6,"V13 installed extraction matches latest threshold")
	view.scene_layers.request_iso("density");check(await view.scene_layers.wait_for_surface() and view.scene_layers.iso_result.cache_hit,"V13 repeat request validates cache")
	view.scene_layers.states.density.isosurface = false;view.scene_layers.resample()
	check(view.scene_layers.iso_node.gpu_bytes == 0,"V07/V13 hidden derived surface releases its GPU buffers")
	setup_capture("cadence.ssc")
	check(view.scene_layers.layer_samples[1].status == "static" and view.scene_layers.layer_samples[2].status == "unavailable","I14 static mesh available before its timestamp; dynamic grid unavailable before first sample")
	view.scene_layers.sample(2)
	check(view.committed_sample.positions == "held (no IDs)","Anonymous G3 particles hold without inferred row identity")
	var face_state: Dictionary = view.scene_layers.states.static_mesh;face_state.channel = "value";face_state.lower = 0;face_state.upper = 1
	view.scene_layers.resample()
	var reflected = view.scene_layers.views.static_mesh
	var arrays: Array = reflected.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX].size() == 3 and arrays[Mesh.ARRAY_COLOR][0].is_equal_approx(arrays[Mesh.ARRAY_COLOR][2]),"V09 face-associated scalar expands consistently")
	check(arrays[Mesh.ARRAY_INDEX] == PackedInt32Array([0,1,2]) and reflected.normal_values[0] == Vector3.BACK,"V09 reflected transform adjusts winding and preserves supplied outward normals")
	view.scene_layers.states.b.visible = true
	check(view.scene_layers.sample(2).is_empty() and "One translucent" in view.scene_layers.error,"V06 second translucent volume explicitly refused")
	view.scene_layers.states.b.visible = false;view.scene_layers.sample(4)
	check(view.scene_layers.layer_samples[2].status == "held" and view.scene_layers.layer_samples[2].source_time == 3,"I14 dynamic layer holds its last recorded time without extrapolation")
	view.scene_layers.sample(0)
	check(not view.scene_layers.views.a.quad.visible and view.scene_layers.views.a.texture == null,"V08 seek before availability releases stale volume texture")
	# Independent source-coordinate slice and probe checks.
	setup_capture("affine.ssc")
	var grid = view.scene_layers.views.field
	check(absf(grid.probe(Vector3(5.2,22.15,22.2))-28.15)<.00003,"V01/V04 noncubic affine trilinear probe")
	view.scene_layers.sample(2);check(grid.grid_size == Vector3(10,7,4) and grid.data.geometry.centering == "cell","V08 shape/spacing/centering replace resources")
	view.scene_layers.sample(0)
	var gray: Array = []
	for i in range(256):gray.append([i/255.,i/255.,i/255.])
	view.colormaps.gray = gray
	var s: Dictionary = view.scene_layers.states.field;s.volume = false;s.slice = true;s.colormap = "gray";s.lower = 7;s.upper = 184
	# Grid world box: x[-2,8], y[21,25], z[-24,27].
	var center := Vector3(3,23,1.5);var slice_errors := {}
	for label in ["XY","XZ","YZ","oblique"]:
		var normal: Vector3 = {"XY":Vector3.BACK,"XZ":Vector3.UP,"YZ":Vector3.RIGHT,"oblique":Vector3(1,1,1).normalized()}[label]
		s.slice_normal = [normal.x,normal.y,normal.z];s.slice_distance = normal.dot(center);view.scene_layers.resample();camera_at(center+normal*65,center)
		var img := await draw();var error := 0.;var samples := 0
		for y in range(200,313,8):
			for x in range(200,313,8):
				var pixel := Vector2(x+.5,y+.5);var ro: Vector3 = view.camera.project_ray_origin(pixel);var rd: Vector3 = view.camera.project_ray_normal(pixel)
				var world: Vector3 = ro+rd*((s.slice_distance-normal.dot(ro))/normal.dot(rd));var value = grid.probe(world)
				if value == null:continue
				var expected := clampf((value-7)/177,0,1);error = maxf(error,absf(img.get_pixel(x,y).r-expected));samples += 1
		slice_errors[label] = {"max_color_error":error,"samples":samples};check(samples>10 and error < .025,"V03/V04 "+label+" rendered slice matches independent source probe")
		img.save_png(base.path_join("slice-"+label+".png"))
	evidence.slices = slice_errors
	setup_capture("tiny.ssc");view.colormaps.gray = gray
	s = view.scene_layers.states.field;s.volume = false;s.slice = true;s.colormap = "gray";s.lower = 0;s.upper = 7e-24;view.scene_layers.resample();camera_at(Vector3(0,0,4),Vector3.ZERO)
	var tiny := await draw()
	check(absf(tiny.get_pixel(256,256).r-.5)<.025,"V03 tiny scientific ranges are not flattened by a display epsilon")
	var input: LineEdit = view.scene_layers._scalar_input(view.scene_layers.panel,"test numeric",1e-24,func(_v):return true)
	check(absf(input.text.to_float()/1e-24-1)<1e-15,"Scientific range entry preserves small values without spin-box rounding");input.queue_free()
	# Actual homogeneous optical depth, geometry occlusion and camera-inside tests.
	setup_capture("slab.ssc");view.colormaps.gray = gray
	s = view.scene_layers.states.field;s.lower = 0;s.upper = 1;s.colormap = "gray";s.opacity = .5;s.slice = false;s.volume = true
	camera_at(Vector3(0,0,4),Vector3.ZERO)
	var slab: Array = []
	for step in [.05,.2,.7]:
		s.step = step;view.scene_layers.resample();var img := await draw();slab.append(img.get_pixel(256,256).r)
	var expected_opacity := 1-exp(-1.);var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var expected_rgb := expected_opacity if compatibility else Color(expected_opacity,expected_opacity,expected_opacity).linear_to_srgb().r
	check(slab.max()-slab.min()<.01 and absf(slab[0]-expected_rgb)<.025,"V05 homogeneous slab physical-step opacity convergence")
	evidence.slab = {"steps":[.05,.2,.7],"center_rgb":slab,"expected_rgb":expected_rgb}
	camera_at(Vector3.ZERO,Vector3(0,0,-1));var inside := await draw()
	var inside_alpha := 1-exp(-.495)
	var inside_expected := inside_alpha if compatibility else Color(inside_alpha,inside_alpha,inside_alpha).linear_to_srgb().r
	check(absf(inside.get_pixel(256,256).r-inside_expected)<.025 and inside.get_pixel(256,256).r < slab[0],"V06 camera inside integrates remaining ray interval")
	camera_at(Vector3(0,0,4),Vector3.ZERO)
	var occluder := MeshInstance3D.new();occluder.mesh = QuadMesh.new();occluder.mesh.size = Vector2(4,4);occluder.position.z = 1.5
	var black := StandardMaterial3D.new();black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;black.albedo_color = Color.BLACK;occluder.material_override = black;view.add_child(occluder)
	var blocked := await draw();check(blocked.get_pixel(256,256).r < .02,"V06 opaque geometry occludes volume rays");occluder.queue_free();await process_frame
	# Budget fallback leaves original probes unchanged.
	setup_capture("scene-demo.ssc");view.scene_layers.states.surface.visible = false;view.scene_layers.gpu_budget_mib = 1;view.scene_layers.resample()
	grid = view.scene_layers.views.density
	check(grid.lod>1 and grid.gpu_bytes<=1048576,"V07 GPU budget forces labeled display LOD")
	var before = grid.probe(Vector3(0,0,0));view.scene_layers.gpu_budget_mib = 256;view.scene_layers.resample()
	check(grid.lod == 1 and grid.probe(Vector3(0,0,0)) == before,"V07 source probe ignores preview LOD")
	# Render-job fixture uses all real layer kinds and extraction barrier.
	view.scene_layers.states.surface.visible = true;view.scene_layers.states.density.slice = true;view.scene_layers.states.density.slice_distance = -2;view.scene_layers.states.density.threshold = .5
	view.scene_layers.sample(.5);view.scene_layers.request_iso("density");check(await view.scene_layers.wait_for_surface(),"V14 combined 128³ + 100k + slice + surface settles")
	view.guide_visibility.domain = true;view.guide_visibility.absorber = true;view._apply_geometry();camera_at(Vector3(55,35,55),Vector3.ZERO)
	var combined := await draw();combined.save_png(base.path_join("combined.png"))
	var out := base.path_join("video-check");DirAccess.make_dir_recursive_absolute(out)
	var job := {"version":1,"capture_path":view.capture_path,"output_path":out.path_join("scene.mp4"),"source":I.identity(view),"start_time":.5,"end_time":1.5,"fps":4,"playback_rate":1.,"width":640,"height":640,"state":Job.snapshot(view),"keep_frames":true,"inspection_sidecars":true,"quality":"high","camera_mode":"locked"}
	if RenderingServer.get_current_rendering_method() == "forward_plus":Job.write_json(out.path_join("job.json"),job)
	evidence.checks = checks;evidence.failures = failures;evidence.renderer = RenderingServer.get_current_rendering_method()
	Job.write_json(base.path_join("gpu-acceptance-"+evidence.renderer+".json"),evidence)
	view.free();vp.queue_free();await process_frame
	print("G3 GPU: ",checks," checks, ",failures," failures");quit(1 if failures else 0)

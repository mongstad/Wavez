extends SceneTree
const Worker = preload("res://video/render_worker.gd")
const Job = preload("res://video/render_job.gd")
class ObservedWorker extends Worker:
	var evidence: Array = []
	func status(stage: String, message: String) -> void:
		super.status(stage,message)
		if stage != "rendering":return
		var layers = viewer.scene_layers
		var row := {"backend":RenderingServer.get_current_rendering_method(),"strict":viewer.generic_reader._verify_payloads,
			"async_workers":[layers.playback.enabled,layers.field_playback.enabled,layers.mesh_playback.enabled],
			"camera":Job.vec(viewer.camera.position),"legends_visible":viewer.legend.is_visible_in_tree()}
		for id in layers.current:
			if layers.reader.objects[id].kind == "particles":
				var positions: Array = []
				for i in mini(16,viewer.current_mm.instance_count):positions.append(Job.vec(viewer.current_mm.get_instance_transform(i).origin))
				var ids: Array = []
				for i in mini(16,viewer.frame_a.ids.size()):ids.append(str(viewer.frame_a.ids[i]))
				row[id] = {"positions":positions,"ids":ids}
			elif layers.views[id] is GridView:
				var grid = layers.views[id]
				if grid.texture == null:continue
				var state: Dictionary = layers.states[id]
				var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(grid.data.channels[grid.channel].to_byte_array())
				row[id] = {"channel":grid.channel,"sha256":hash.finish().hex_encode(),"lod":grid.lod,
					"opacity":[grid.material.get_shader_parameter("opacity_lower"),grid.material.get_shader_parameter("opacity_upper"),grid.material.get_shader_parameter("opacity")],
					"range":[grid.material.get_shader_parameter("lower"),grid.material.get_shader_parameter("upper")]}
				if RenderingServer.get_current_rendering_method() == "forward_plus":
					var gpu_hash := HashingContext.new();gpu_hash.start(HashingContext.HASH_SHA256)
					for plane in grid.texture.get_data():gpu_hash.update(plane.get_data())
					row[id].texture_sha256 = gpu_hash.finish().hex_encode()
			elif layers.views[id].mesh != null:
				var mesh_view = layers.views[id];var positions: Array = []
				for point in mesh_view.source_positions:positions.append(Job.vec(point))
				row[id] = {"positions":positions,"triangles":Array(mesh_view.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX])}
		# Field-only scenes have a separate legend component.
		row.legends_visible = row.legends_visible or viewer.shell.layer_legends.is_visible_in_tree()
		evidence.append(row)
		Job.write_json(directory.path_join("evidence.json"),{"frames":evidence})
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var worker := ObservedWorker.new();worker.job_path = OS.get_cmdline_user_args()[0];root.add_child(worker)

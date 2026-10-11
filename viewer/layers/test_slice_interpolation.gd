extends SceneTree
var job: Dictionary
var checks:=0
var failures: Array=[]
var records: Array=[]
var reader
var grid
var vp: SubViewport
var camera: Camera3D
var lut: ImageTexture
var shader_cache: Dictionary={}
var source_oracle: Dictionary={}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--job="):job=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--job=")))
	run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func state(mode:String) -> Dictionary:
	var value:={"visible":true,"volume":false,"slice":true,"lower":-1.,"upper":3.,"opacity":2.,"step":.8/128.,"clip":false,"clip_normal":[1.,0.,0.],"clip_distance":0.,"slice_normal":[0.,0.,1.],"slice_distance":.037,"opacity_mapping":{"mode":"linear","lower":-1.,"upper":3.}}
	if mode=="slice-narrow":value.lower=.254;value.upper=.256
	if mode=="slice-log":value.lower=.1;value.upper=3.;value.color_mapping={"normalization":"log","policy":"manual","source_channel":"scalar","source_time":0.}
	return value
func use_shader(variant:String) -> void:
	grid.slice_material.shader=shader_cache["slice-"+variant]
func load_case(name:String,index:int,budget:int) -> Dictionary:
	grid.clear();reader.close();check(reader.open(job.source.path_join(name+".wvz")),"Native strict WVZ1 open "+name)
	var sample:Dictionary=reader.read_sample("field",index)
	check(grid.load_sample(reader.objects.field,sample,"scalar",budget),"Native field upload "+name)
	var expected:Dictionary=source_oracle[name]
	check(grid.grid_size==Vector3(expected.dimensions[0],expected.dimensions[1],expected.dimensions[2]),"Actual grid dimensions "+name)
	for probe in expected.get("probes",[]):
		if int(probe.sample)==index:check(absf(grid.probe(Vector3(probe.world[0],probe.world[1],probe.world[2]))-float(probe.expected))<2e-6,"Original source probe "+name)
	check(grid.probe(Vector3.ZERO,"absent")==null,"Missing source probe unavailable "+name)
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(sample.channels.scalar.to_byte_array())
	check(h.finish().hex_encode()==expected.source_hashes[index],"Original source bytes "+name)
	check(grid.gpu_bytes==int(expected.gpu_full_bytes) if budget>=int(expected.gpu_full_bytes) else grid.lod>1,"Actual texture allocation "+name)
	return sample
func render_frames(count:int) -> void:
	for i in count:await process_frame
	await RenderingServer.frame_post_draw
func snapshot(name:String,mode:String,variant:String,sample:Dictionary) -> void:
	use_shader(variant)
	var settings:=state(mode)
	var transform:Transform3D=grid.world_to_grid.affine_inverse()
	var origin:Vector3=transform*((grid.grid_size-Vector3.ONE)*.5)
	var normal:Vector3=transform.basis.z.normalized()
	settings.slice_normal=[normal.x,normal.y,normal.z]
	# 0.037 m above the untransformed grid's physical center.
	var plane:Vector3=origin+normal*.037
	settings.slice_distance=normal.dot(plane)
	grid.apply(settings,lut)
	await render_frames(8)
	var image:=vp.get_texture().get_image()
	var filename:="%s-%s-%s-%d.png"%[name,mode,variant,int(sample.sequence)]
	check(image.save_png(job.output.path_join(filename))==OK,"Snapshot "+filename)
	var pixel:=image.get_pixel(vp.size.x/2,vp.size.y/2)
	var probe=grid.probe(plane,"scalar")
	records.append({"kind":"snapshot","case":name,"mode":mode,"variant":variant,"sequence":sample.sequence,"time":sample.time,"center_rgb":[pixel.r,pixel.g,pixel.b],"plane_center":[plane.x,plane.y,plane.z],"plane_probe":probe,"lod":grid.lod,"gpu_bytes":grid.gpu_bytes,"color_error":grid.color_error,"slice_visible":grid.slice.visible,"volume_visible":grid.quad.visible,"settings":settings,"image":filename})
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("slice watchdog");quit(2))
	check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Forward+ Vulkan only")
	for item in JSON.parse_string(FileAccess.get_file_as_string(job.source.path_join("oracle.json"))).cases:source_oracle[item.name]=item
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for name in ["slice"]:
		for variant in ["hardware","explicit"]:
			var shader:=Shader.new();shader.code=FileAccess.get_file_as_string(job.shaders.path_join(name+"-"+variant+".gdshader"));shader_cache[name+"-"+variant]=shader
	vp=SubViewport.new();vp.size=Vector2i(256,192);vp.own_world_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(),true)
	var world:=Node3D.new();vp.add_child(world)
	camera=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=2.;camera.near=.01;camera.far=10.;camera.current=true
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.environment.glow_enabled=false;env.environment.fog_enabled=false;world.add_child(env)
	grid=load("res://layers/grid_view.gd").new();world.add_child(grid);grid.setup(camera)
	var image:=Image.create(256,1,false,Image.FORMAT_RGB8)
	for i in 256:image.set_pixel(i,0,Color(i/255.,i/255.,i/255.))
	lut=ImageTexture.create_from_image(image);reader=load("res://layers/scene_reader.gd").new()
	for name in ["scientific","cell","transformed","scientific-lod"]:
		var sample:=load_case("scientific" if name=="scientific-lod" else name,0,3000 if name=="scientific-lod" else 268435456)
		var transform:Transform3D=grid.world_to_grid.affine_inverse();var center:Vector3=transform*((grid.grid_size-Vector3.ONE)*.5)
		camera.position=center+transform.basis.z.normalized()*3.;camera.look_at(center,transform.basis.y.normalized())
		for mode in ["slice-wide","slice-narrow","slice-log"]:
			for variant in ["hardware","explicit"]:await snapshot(name,mode,variant,sample)
		if name=="scientific":
			for time in [.0625,.125,.1875,.25]:
				var point:Dictionary=reader.bracket("field",time);sample=load_case("scientific",int(point.a),268435456)
				records.append({"kind":"hold","requested":time,"a":point.a,"b":point.b,"source_time":sample.time,"probe":grid.probe(Vector3.ZERO,"scalar")})
				for variant in ["hardware","explicit"]:await snapshot("hold-"+str(time),"slice-wide",variant,sample)
				if time==.125:
					for variant in ["hardware","explicit"]:await snapshot("positive-log","slice-log",variant,sample)
	await nonfinite_source_checks()
	await scalar_checks()
	var report:={"checks":checks,"failures":failures,"records":records,"godot":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"gpu":RenderingServer.get_video_adapter_name()}
	var f:=FileAccess.open(job.output.path_join("results.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ")+"\n");f.close()
	reader.close();grid.clear();world.free();vp.queue_free();lut=null;shader_cache.clear()
	for i in 8:await process_frame
	print("SLICE INTERPOLATION ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

func nonfinite_source_checks() -> void:
	grid.clear();reader.close();check(reader.open(job.nonfinite_source),"Nonfinite WVZ1 strict open")
	for index in 3:
		grid.clear()
		var sample: Dictionary=reader.read_sample("field",index)
		check(grid.load_sample(reader.objects.field,sample,"scalar",268435456),"Nonfinite source upload")
		var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(sample.channels.scalar.to_byte_array())
		check(h.finish().hex_encode()==job.nonfinite_hashes[index],"NaN/Inf source bytes preserved")
		check(grid.probe(Vector3.ZERO)==null,"Zero-weight nonfinite source support remains unavailable")
		check(grid.probe(Vector3(1,1,1))==null,"Nonfinite source center unavailable")
		check(grid.probe(Vector3(3,3,3))==.5,"Finite boundary source probe retained")
		check(grid.probe(Vector3(-.01,0,0))==null,"Out-of-domain source probe unavailable")
		check(grid.probe(Vector3.ZERO,"absent")==null,"Missing source channel unavailable")
		camera.position=Vector3(1.5,1.5,4.5);camera.look_at(Vector3(1.5,1.5,1.5));camera.size=4.
		for variant in ["hardware","explicit"]:await snapshot("nonfinite-source","slice-wide",variant,sample)
	grid.clear()
	var sample: Dictionary=reader.read_sample("field",0)
	check(not grid.load_sample(reader.objects.field,sample,"absent",268435456),"Missing slice channel refuses upload")
	check(grid.texture==null and not grid.slice.visible and not grid.quad.visible,"Missing channel cannot render stale/default scalar")

func scalar_checks() -> void:
	# Exercise the exact production sampler through an RGB24 scalar observable.
	var code := FileAccess.get_file_as_string("res://layers/slice.gdshader")
	var start := code.find("float slice_value(")
	var sampler := code.substr(start,code.find("void vertex()")-start)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler3D field_texture : filter_linear, repeat_disable;
uniform sampler2D points : filter_nearest, repeat_disable;
uniform int mode = 0;
"""+sampler+"""
void fragment() {
    vec4 p=texelFetch(points,ivec2(FRAGCOORD.xy),0);
    float v=texture(field_texture,p.xyz).r;
    if(mode==1) v=slice_value(p.xyz);
    if(mode==2) v=p.w;
    float code=floor(clamp((v+8.0)/16.0,0.0,1.0)*16777215.0+0.5);
    if(isnan(v)) code=16777215.0;
    if(isinf(v)) code=16777214.0;
    float r=floor(code/65536.0),g=floor((code-r*65536.0)/256.0);
    COLOR=vec4(vec3(r,g,code-r*65536.0-g*256.0)/255.0,1.0);
}
"""
	var scalar_view := SubViewport.new();scalar_view.disable_3d=true;scalar_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(scalar_view)
	var rect := ColorRect.new();scalar_view.add_child(rect)
	var mat := ShaderMaterial.new();mat.shader=shader;rect.material=mat
	for item in job.scalar_cases:
		var dims := Vector3i(item.dimensions[0],item.dimensions[1],item.dimensions[2])
		var raw := FileAccess.get_file_as_bytes(job.scalars.path_join(item.name+".rf"))
		var planes: Array[Image]=[]
		for z in dims.z:planes.append(Image.create_from_data(dims.x,dims.y,false,Image.FORMAT_RF,raw.slice(z*dims.x*dims.y*4,(z+1)*dims.x*dims.y*4)))
		var tex := ImageTexture3D.new()
		check(tex.create(Image.FORMAT_RF,dims.x,dims.y,dims.z,false,planes)==OK,"RF scalar upload "+item.name)
		var point_image := Image.create_from_data(512,int(item.points_height),false,Image.FORMAT_RGBAF,FileAccess.get_file_as_bytes(job.scalars.path_join(item.name+".points")))
		var points := ImageTexture.create_from_image(point_image)
		scalar_view.size=Vector2i(512,int(item.points_height));rect.size=Vector2(scalar_view.size)
		mat.set_shader_parameter("field_texture",tex);mat.set_shader_parameter("points",points)
		for mode in [0,1,2]:
			mat.set_shader_parameter("mode",mode);await render_frames(5)
			check(scalar_view.get_texture().get_image().save_png(job.output.path_join("%s-%d.png"%[item.name,mode]))==OK,"Scalar observable "+item.name+"/"+str(mode))
		mat.set_shader_parameter("field_texture",null);mat.set_shader_parameter("points",null)
		records.append({"kind":"scalar","case":item.name,"points":item.count})
	mat.shader=null;scalar_view.queue_free();await process_frame

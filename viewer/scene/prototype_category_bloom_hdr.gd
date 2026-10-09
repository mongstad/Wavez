extends SceneTree
## Issue #306's first architecture gate, deliberately outside production.
## Exit 1 means the measured backend failed the gate; it is not a harness pass.
const Job = preload("res://video/render_job.gd")
const VALUES = [0.0001, 0.001, 0.01, 0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
const SIZE = Vector2i(64, 64)
const FLOAT_FORMATS = [Image.FORMAT_RGBF, Image.FORMAT_RGBAF, Image.FORMAT_RGBH, Image.FORMAT_RGBAH]
const SPATIAL = """shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec3 radiance;
uniform float emission_multiplier;
void fragment() {
	ALBEDO = radiance;
	EMISSION = radiance * emission_multiplier;
}
"""
const EMISSIVE = """shader_type spatial;
render_mode fog_disabled;
uniform vec3 radiance;
void fragment() { ALBEDO = vec3(0.0); EMISSION = radiance; }
"""
const CANVAS = """shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform vec3 radiance;
void fragment() { COLOR = vec4(radiance, 1.0); }
"""
const PROBE = """shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D source_texture : filter_nearest, repeat_disable;
uniform vec3 expected;
void fragment() {
	vec3 received = texture(source_texture, UV).rgb;
	bvec3 close = lessThanEqual(abs(received - expected), max(expected * 0.01, vec3(0.000001)));
	// Binary answers avoid confusing a CPU color conversion with GPU information loss.
	COLOR = vec4(all(greaterThan(received, vec3(0.0))) ? 1.0 : 0.0,
		all(close) ? 1.0 : 0.0, all(greaterThan(received, vec3(1.0))) ? 1.0 : 0.0, 1.0);
}
"""
var checks := 0
var harness_failures: Array[String] = []
var gate_failures: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var source: SubViewport
var canvas: SubViewport
var probe: SubViewport
var environment: Environment
var material: ShaderMaterial
var canvas_material: ShaderMaterial
var probe_material: ShaderMaterial
var shader: Shader

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: harness_failures.append(label)

func viewport(three_d: bool) -> SubViewport:
	var node := SubViewport.new()
	node.size = SIZE
	node.own_world_3d = three_d
	node.disable_3d = not three_d
	node.use_hdr_2d = true
	node.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(node)
	return node

func canvas_pass(target: SubViewport, code: String) -> ShaderMaterial:
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE)
	var result := ShaderMaterial.new()
	var program := Shader.new()
	program.code = code
	result.shader = program
	rect.material = result
	target.add_child(rect)
	return result

func settle() -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw

func rgb(color: Color) -> Array:
	return [color.r, color.g, color.b]

func close_rgb(actual: Color, expected: Vector3) -> bool:
	for i in 3:
		if absf(actual[i] - expected[i]) > maxf(expected[i] * 0.01, 0.000001): return false
	return true

func run() -> void:
	if OS.get_cmdline_user_args().size() != 1: quit(2); return
	var output := OS.get_cmdline_user_args()[0]
	create_timer(60).timeout.connect(func(): print("HDR prototype timed out"); quit(2))
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	source = viewport(true)
	canvas = viewport(false)
	probe = viewport(false)
	canvas_material = canvas_pass(canvas, CANVAS)
	probe_material = canvas_pass(probe, PROBE)
	probe_material.set_shader_parameter("source_texture", source.get_texture())
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = false
	environment.fog_enabled = false
	world.environment = environment
	source.add_child(world)
	var camera := Camera3D.new()
	camera.position.z = 2.0
	source.add_child(camera)
	camera.current = true
	var instance := MeshInstance3D.new()
	instance.mesh = QuadMesh.new()
	material = ShaderMaterial.new()
	shader = Shader.new()
	shader.code = SPATIAL
	material.shader = shader
	instance.material_override = material
	source.add_child(instance)
	for variant in ["opaque", "transparent", "glow_zero", "shaded_emission", "unshaded_emission_3"]:
		source.transparent_bg = variant == "transparent"
		environment.glow_enabled = variant == "glow_zero"
		environment.glow_intensity = 0.0
		shader.code = EMISSIVE if variant == "shaded_emission" else SPATIAL
		material.set_shader_parameter("emission_multiplier", 3.0 if variant == "unshaded_emission_3" else 0.0)
		for value in VALUES:
			for chromatic in [false, true]:
				var expected: Vector3 = Vector3(value, value * 0.5, value * 0.25) if chromatic else Vector3.ONE * value
				material.set_shader_parameter("radiance", expected)
				canvas_material.set_shader_parameter("radiance", expected)
				probe_material.set_shader_parameter("expected", expected)
				await settle()
				var source_image := source.get_texture().get_image()
				var canvas_image := canvas.get_texture().get_image()
				var actual := source_image.get_pixel(32, 32)
				var control := canvas_image.get_pixel(32, 32)
				var received := probe.get_texture().get_image().get_pixel(32, 32)
				var gpu_positive := received.r > 0.9
				var gpu_linear := received.g > 0.9
				var gpu_over_one := received.b > 0.9
				var cpu_linear := close_rgb(actual, expected)
				check(source_image.get_format() in FLOAT_FORMATS, "3D source has a float image")
				check(canvas_image.get_format() in FLOAT_FORMATS, "2D control has a float image")
				check(close_rgb(control, expected), "2D HDR control preserves " + str(expected))
				check(gpu_linear == cpu_linear, "GPU and CPU linear comparisons agree")
				check(gpu_positive == (actual.r > 0.0 and actual.g > 0.0 and actual.b > 0.0), "GPU and CPU zero comparisons agree")
				check(gpu_over_one == (actual.r > 1.0 and actual.g > 1.0 and actual.b > 1.0), "GPU and CPU HDR comparisons agree")
				var sample := {"variant":variant, "expected":[expected.x, expected.y, expected.z], "actual":rgb(actual), "canvas_control":rgb(control),
					"source_format":source_image.get_format(), "canvas_format":canvas_image.get_format(),
					"gpu_positive":gpu_positive, "gpu_linear":gpu_linear, "gpu_over_one":gpu_over_one, "linear":cpu_linear}
				samples.append(sample)
				if not cpu_linear or not gpu_linear:
					gate_failures.append({"variant":variant, "expected":[expected.x, expected.y, expected.z], "actual":rgb(actual), "gpu_positive":gpu_positive})
	# Verify the accepted unshaded shader's EMISSION expression is ignored, rather
	# than assigning its literal expression as additional observed HDR radiance.
	for i in VALUES.size() * 2:
		check(samples[i].actual == samples[4 * VALUES.size() * 2 + i].actual, "unshaded emission does not add radiance")
	var report := {"renderer":RenderingServer.get_current_rendering_method(), "device":RenderingServer.get_video_adapter_name(),
		"godot":Engine.get_version_info().string, "checks":checks + 1, "harness_failures":harness_failures,
		"gate_passed":gate_failures.is_empty(), "gate_failures":gate_failures, "samples":samples,
		"scope":"first HDR source gate only; no production renderer/UI/state change", "size":[SIZE.x, SIZE.y]}
	check(Job.write_json(output, report) == OK, "write report")
	source.queue_free()
	canvas.queue_free()
	probe.queue_free()
	await process_frame
	print("BLOOM HDR PROTOTYPE: ", checks, " harness checks, ", harness_failures.size(), " harness failures; ", gate_failures.size(), " HDR gate failures")
	quit(2 if not harness_failures.is_empty() else (0 if gate_failures.is_empty() else 1))

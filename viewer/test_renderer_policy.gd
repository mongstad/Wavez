extends SceneTree
const Policy = preload("res://renderer_policy.gd")
const Job = preload("res://video/render_job.gd")
var checks: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok:printerr("FAIL: "+label)

func run() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var headless := DisplayServer.get_name() == "headless"
	check(Policy.problem(true).is_empty(),"Supported GPU runtime or explicit headless CPU test")
	check(Policy.problem().is_empty() != headless,"Headless rendering cannot certify the runtime")
	for key in ["rendering/rendering_device/fallback_to_opengl3","rendering/rendering_device/fallback_to_d3d12"]:
		check(not ProjectSettings.get_setting(key),"Fallback disabled: "+key)
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == Policy.METHOD,"Project pins Forward+")
	check(ProjectSettings.get_setting("rendering/rendering_device/driver.linuxbsd") == Policy.DRIVER,"Linux pins Vulkan")
	var args := Job.launch_arguments(output.path_join("job.json"),8)
	check(args.count("--rendering-method") == 1 and args[args.find("--rendering-method")+1] == Policy.METHOD,"Exactly one pinned child method")
	check(args.count("--rendering-driver") == 1 and args[args.find("--rendering-driver")+1] == Policy.DRIVER,"Exactly one pinned child driver")
	check(args.find("--rendering-driver") < args.find("--"),"Driver precedes user arguments")
	check(args.has("--path") == OS.has_feature("editor"),"Only development engine receives --path")
	for method in ["gl_compatibility","mobile","invalid"]:
		check(Job.validate({"rendering_method":method}).contains(Policy.REQUIREMENT),"Reject unsupported job renderer: "+method)
	var failures := checks.filter(func(c):return not c.ok).size()
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"runtime":Policy.runtime(),"headless":headless})
	print("Renderer policy: %d checks, %d failures" % [checks.size(),failures])
	quit(1 if failures else 0)

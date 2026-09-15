extends SceneTree
const Reader = preload("res://layers/scene_reader.gd")
const Exact = preload("res://scene/source_sampling.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--chunks-fixture="):directory = argument.trim_prefix("--chunks-fixture=")
	if directory.is_empty():quit(1);return
	var expected: Array = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("expected.json")))
	for entry in expected:
		var reader := Reader.new()
		check(reader.open(entry.path),"multi-chunk source opens")
		var sample: Dictionary = reader.read_sample("p",int(entry.index))
		check(not sample.is_empty(),"multi-chunk source decodes")
		if not sample.is_empty():
			check(sample.count == int(entry.count),"anonymous population count preserved")
			check(sample.channels.velocity is PackedFloat64Array,"source velocity remains float64")
			for value in entry.values:
				check(sample.channels.velocity[int(value.index)] == Exact.exact_float(value.value).value,"bit-exact source velocity across chunk boundary")
		reader.close()
	var file := FileAccess.open(directory.path_join("checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures}));file.close()
	print("G3 MULTICHUNK: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

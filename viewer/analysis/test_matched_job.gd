extends SceneTree
const Job = preload("res://video/render_job.gd")
const State = preload("res://analysis/inspection_v3.gd")
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:push_error(label);quit(1)
func _initialize() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matched-job="):path = arg.trim_prefix("--matched-job=")
	var job = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not job is Dictionary:quit(1);return
	job.state = State.unpack(job.exact_state)
	var timing = State.unpack(job.exact_timing)
	for key in timing:job[key] = timing[key]
	job.output_path = path.get_base_dir().path_join("validation-only-new.mp4")
	check(Job.validate(job).is_empty(),"Valid exact matched job: "+Job.validate(job))
	for fault in ["source","camera","time","range","frames","inputs"]:
		var bad: Dictionary = job.duplicate(true);var c: Dictionary = State.unpack(bad.comparison)
		match fault:
			"source":c.inputs[0].source.sha256 = "wrong"
			"camera":c.common.camera = {}
			"time":c.common.timing.start_time = .1
			"range":c.common.range[0] = -.1
			"frames":c.frames = 99
			"inputs":c.inputs = []
		bad.comparison = State.pack(c)
		check(not Job.validate(bad).is_empty(),"Refuse altered matched "+fault)
	for field in ["state","fps","playback_rate","source"]:
		var bad: Dictionary = job.duplicate(true);bad[field] = null
		check(not Job.validate(bad).is_empty(),"Malformed base field rejected before matched arithmetic: "+field)
	print("Matched job: %d checks PASS" % checks);quit()

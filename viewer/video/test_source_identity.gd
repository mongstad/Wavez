extends SceneTree
const Reader = preload("res://layers/scene_reader.gd")
const Source = preload("res://video/source_identity.gd")
const Job = preload("res://video/render_job.gd")
var checks: Array = []
func check(value: bool, label: String) -> void: checks.append({"ok":value,"label":label})
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var reader := Reader.new()
	check(reader.open(out.path_join("field.ssc")),"Strict reader opens current fixture")
	var identity := Source.capture(reader)
	check(not identity.is_empty() and not identity.has("sha256"),"Local identity has no payload-prefix hash")
	check(Source.matches(reader,identity),"Metadata/header/stamp identity round trips")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(identity))
	check(Source.matches(reader,parsed),"JSON preserves identity including nanosecond stamps")
	parsed.path = "ignored locator"
	check(Source.matches(reader,parsed),"Path text never establishes identity")
	for key in ["uuid","header_sha256","record_headers_sha256","committed_bytes","complete_records","complete_frames","format","version"]:
		var changed := identity.duplicate(true);changed[key] = "wrong"
		check(not Source.matches(reader,changed),"Reject changed identity field: "+key)
	var other := Reader.new();other.open(out.path_join("field-copy.ssc"))
	check(not Source.matches(other,identity),"Byte-identical replacement inode is not the same local source")
	var callbacks := [0]
	reader.cancellation = func():callbacks[0] += 1;return callbacks[0] >= 3
	check(not reader.reload_source() and "cancelled" in reader.error,"Index scan cancellation stops before completion")
	reader.cancellation = Callable();reader.open(out.path_join("field.ssc"))
	reader.cancellation = func():return true
	check(reader.read_sample("field",0).is_empty() and "cancelled" in reader.error,"Strict sample read cancellation refuses a partial sample")
	reader.close();other.close()
	Job.write_json(out.path_join("identity-checks.json"),{"checks":checks})
	quit(0 if checks.all(func(row):return row.ok) else 1)

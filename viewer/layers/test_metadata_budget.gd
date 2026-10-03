extends SceneTree
const Reader = preload("res://layers/scene_reader.gd")
const Hash = preload("res://data/capture_index.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;push_error(label)
func _initialize() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("fixture.json")))
	var path := directory.path_join("long.wvz")
	var previous_env := OS.get_environment("WAVEZ_METADATA_BUDGET_MIB")
	OS.set_environment("WAVEZ_METADATA_BUDGET_MIB","1")
	var configured := Reader.new()
	check(configured.metadata_limit == 1048576 and not configured.open(path) and configured.error_code == "metadata_capacity", "Environment configures reader admission")
	OS.set_environment("WAVEZ_METADATA_BUDGET_MIB","invalid")
	configured = Reader.new()
	check(not configured.open(path) and configured.error_code == "metadata_capacity", "Invalid configuration cannot disable admission")
	OS.set_environment("WAVEZ_METADATA_BUDGET_MIB","8192")
	configured = Reader.new()
	check(configured.metadata_limit == 8192*1048576, "A larger native budget is configurable")
	OS.set_environment("WAVEZ_METADATA_BUDGET_MIB",previous_env)
	var reader := Reader.new()
	reader.metadata_limit = 128
	check(not reader.open(path) and reader.error_code == "metadata_capacity", "Small metadata budget gives a capacity error")
	check(reader.records.is_empty() and reader.metadata_reserved == 0 and reader.file == null, "Failed admission releases the partial index")
	reader.metadata_limit = Reader.DEFAULT_METADATA_BYTES
	check(reader.open(path), "Same valid capture opens after increasing the budget")
	check(reader.records.size() == int(report.records) and report.aggregate_descriptor_charge > 32*1048576, "All records beyond the old aggregate boundary are indexed")
	check(reader.records.all(func(row):return row.descriptor.is_empty()), "Opening keeps lazy descriptors")
	var reserved := reader.metadata_reserved
	check(reserved <= reader.metadata_limit, "Future descriptor and parse workspace reservation is bounded")
	for i in range(reader.records.size()):
		check(not reader.describe("field",i).is_empty(), "Every descriptor/commit validates: %d" % i)
	check(reader.metadata_reserved == reserved, "Materialization uses already admitted metadata capacity")
	for row in report.oracle:
		var sample := reader.read_sample("field",int(row.index))
		check(not sample.is_empty(), "Requested payload decodes beyond the old limit")
		if sample.is_empty():continue
		check(sample.time == row.time and sample.channels.size() == 64, "Exact clock and all channels preserved")
		for name in sample.channels:
			check(Hash.digest(sample.channels[name].to_byte_array()) == row.sha256, "Exact float64/nonfinite/signed-zero bytes: "+name)
	reader.metadata_limit = reserved-1
	check(not reader.reload_source() and reader.error_code == "metadata_capacity", "Late admission failure remains a capacity error")
	check(reader.records.is_empty() and reader.metadata_reserved == 0, "Late refusal clears partial metadata")
	reader.metadata_limit = reserved
	check(reader.open(path) and reader.metadata_reserved == reserved, "Exact budget boundary admits reproducibly")
	for kind in ["descriptor","commit","payload"]:
		check(reader.open(directory.path_join(kind+".wvz")), "Lazy open defers corruption validation: "+kind)
		check(reader.read_sample("field",int(report.records)-1).is_empty() and reader.error.contains("checksum") and reader.error_code != "metadata_capacity", "Corruption remains distinct from capacity: "+kind)
	check(not reader.open(directory.path_join("oversized.wvz")) and reader.error_code != "metadata_capacity", "Per-record descriptor ceiling still refuses before parsing")
	reader.close()
	check(reader.metadata_reserved == 0 and reader.records.is_empty(), "Close releases metadata")
	var result := {"checks":checks,"failures":failures,"metadata_reserved":reserved,"metadata_limit":Reader.DEFAULT_METADATA_BYTES,"records":report.records}
	preload("res://video/render_job.gd").write_json(directory.path_join("native-metadata.json"),result)
	print("METADATA BUDGET: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

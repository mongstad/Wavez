extends SceneTree
# Headless allocation experiment: isolate retained decoded data from the extra
# prepared-pair allocations. It does not measure playback or GPU memory.
const Reader = preload("res://layers/scene_reader.gd")
const Buffer = preload("res://layers/playback_buffer.gd")
const Prepare = preload("res://layers/particle_prepare.gd")
const Job = preload("res://video/render_job.gd")
func _initialize() -> void:run.call_deferred()
func memory() -> Dictionary:
	var proc := FileAccess.open("/proc/self/status",FileAccess.READ)
	var text := proc.get_buffer(65536).get_string_from_utf8() if proc != null else ""
	var rss := 0
	for line in text.split("\n"):
		if line.begins_with("VmRSS:"):rss = int(line.substr(6).strip_edges().split(" ",false)[0])*1024
	return {"rss_bytes":rss,"static_bytes":OS.get_static_memory_usage()}
func run() -> void:
	var job := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preload-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--preload-job=")))
	if job.is_empty():quit(1);return
	var reader := Reader.new()
	if not reader.open(job.capture):push_error(reader.error);quit(1);return
	var id := ""
	for key in reader.objects:
		if reader.objects[key].kind == "particles":id = key
	if id.is_empty():push_error("Particle capture required");quit(1);return
	var entries: Array = reader.samples[id]
	var estimate := Buffer.estimate(entries,false)
	if estimate.total*1.25 > Buffer.memory_headroom().safe_cache_bytes:
		push_error("Full allocation probe exceeds safe physical RAM headroom");quit(1);return
	var worker := Buffer.new() # Deliberately no thread: isolates allocator counts.
	worker.decoded.configure(int(estimate.decoded_total*1.25))
	worker.desired.assign(range(entries.size()))
	var context := {"entries":entries}
	var file := FileAccess.open(job.capture,FileAccess.READ)
	var source_before := Buffer.Stamp.read(job.capture)
	var before := memory();var decoded_rows: Array = []
	for i in range(entries.size()):
		worker.working_index = i
		var data := worker._read(i,context,file)
		if data.is_empty() or data.has("error"):push_error("Decode failed");quit(1);return
		if (i+1)%16==0 or i+1==entries.size():
			var row := memory();row.samples = i+1;row.cache_charge = worker.decoded.used;decoded_rows.append(row)
	var decoded_memory := memory()
	var config := {"color_channel":"fixed","size_channel":"fixed","brightness_channel":"fixed","normalization":"frame","manual_min":0.,"manual_max":1.,"logarithmic":false,"clamp_map":true,"cyclic":false,"invert_map":false,"hidden_types":{},"trails":false}
	var pairs: Array = [];var pair_rows: Array = [];var charge := 0
	for i in range(entries.size()):
		worker.working_index = i
		var a := worker.decoded.get_frame(i);var b := worker.decoded.get_frame(mini(i+1,entries.size()-1))
		var pair := Prepare.pair(a,b,[],config,worker)
		if pair.is_empty():push_error("Pair preparation failed");quit(1);return
		pairs.append(pair);charge += int(pair.bytes)
		if (i+1)%16==0 or i+1==entries.size():
			var row := memory();row.pairs = i+1;row.cache_charge = charge;pair_rows.append(row)
	var final := memory()
	var result := {"capture":job.capture,"samples":entries.size(),"pairs":pairs.size(),"before":before,"decoded_only":decoded_memory,"decoded_and_prepared":final,"decoded_rows":decoded_rows,"pair_rows":pair_rows,"decoded_cache_charge":worker.decoded.used,"prepared_cache_charge":charge,"source_unchanged":source_before==Buffer.Stamp.read(job.capture)}
	result.decoded_static_bytes_per_sample = (decoded_memory.static_bytes-before.static_bytes)/float(entries.size())
	result.additional_prepared_static_bytes_per_pair = (final.static_bytes-decoded_memory.static_bytes)/float(pairs.size())
	result.decoded_rss_bytes_per_sample = (decoded_memory.rss_bytes-before.rss_bytes)/float(entries.size())
	result.additional_prepared_rss_bytes_per_pair = (final.rss_bytes-decoded_memory.rss_bytes)/float(pairs.size())
	Job.write_json(job.output,result);print("CACHE MEMORY ",JSON.stringify(result))
	pairs.clear();worker.decoded.clear();reader.close();quit(0 if result.source_unchanged else 1)

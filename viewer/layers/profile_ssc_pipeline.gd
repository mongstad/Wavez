extends SceneTree
# Serial CPU-only stage probe. Integrity hashes below are outside stage timers.
const Reader = preload("res://layers/scene_reader.gd")
const Channels = preload("res://layers/scene_channels.gd")
const Prepare = preload("res://layers/field_prepare.gd")
const Hash = preload("res://data/capture_index.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args := OS.get_cmdline_user_args();var reader := Reader.new()
	var began := Time.get_ticks_usec()
	if not reader.open(args[0]):push_error(reader.error);quit(1);return
	var report := {"open_ms":(Time.get_ticks_usec()-began)/1000.0,"records":reader.records.size(),"fields":[]}
	for id in reader.objects:
		if reader.objects[id].kind != "volume":continue
		for index in [0,reader.samples[id].size()/2,reader.samples[id].size()-1]:
			var start := Time.get_ticks_usec();var desc := reader.describe(id,index)
			var descriptor_ms := (Time.get_ticks_usec()-start)/1000.0
			if desc.is_empty():push_error(reader.error);quit(1);return
			var entry: Dictionary = reader.samples[id][index]
			start = Time.get_ticks_usec()
			var decoded := Channels.read(reader.file,entry,reader.objects[id])
			if decoded.is_empty() or decoded.has("error"):push_error(str(decoded));quit(1);return
			var row := {"id":id,"index":index,"time":entry.time,"descriptor_ms":descriptor_ms,"decode_ms":(Time.get_ticks_usec()-start)/1000.0,"decode_stages":decoded.timings,"channels":{}}
			var sample := {"channels":decoded.channels,"shapes":decoded.shapes,"geometry":desc.geometry,"statistics":decoded.get("statistics",{})}
			for channel in decoded.channels:
				var ready := Prepare.prepare(reader.objects[id],sample,channel,512*1024*1024)
				if ready.is_empty() or ready.has("error"):push_error(str(ready));quit(1);return
				var raw := PackedByteArray()
				for plane in ready.planes:raw.append_array(plane.get_data())
				row.channels[channel] = {"stages":ready.timings,"statistics":ready.color_stats,"source_sha256":Hash.digest(sample.channels[channel].to_byte_array()),"planes_sha256":Hash.digest(raw),"lod":ready.lod}
				sample = ready.sample
			report.fields.append(row)
	var file := FileAccess.open(args[1],FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t",false,true));file.close()
	reader.close();quit()

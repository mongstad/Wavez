extends SceneTree
const R = preload("res://layers/scene_reader.gd")
const Hash = preload("res://data/capture_index.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;push_error(label)
func _initialize() -> void:
	var base := ProjectSettings.globalize_path("res://../results/g3")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene-fixture="):base = arg.trim_prefix("--scene-fixture=")
	var expected = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("interop.json")))
	for fixture in expected:
		var r := R.new();check(r.open(base.path_join(fixture.file)),"Scene opens "+fixture.file)
		for row in fixture.samples:
			var a := r.read_sample(row.object,int(row.index));check(not a.is_empty(),"Sample decodes")
			if a.is_empty():continue
			check(a.time == row.time,"Timestamp exact")
			for name in row.arrays:
				if row.arrays[name].dtype == "u4" and name != "triangles":continue
				check(Hash.digest(a.channels[name].to_byte_array()) == row.arrays[name].sha256,"Python/Godot bitwise "+name)
		check(r.cache.used <= r.cache.limit,"Decoded cache bounded")
		r.close()
	var r := R.new();var source := base.path_join("affine.ssc");check(r.open(source),"Affine opens")
	var a := r.read_sample("field",0);var original: float = a.channels.f[0];a.channels.f[0] = -999;a.geometry.shape[0] = 999;a.shapes.f[0] = 888
	var again := r.read_sample("field",0)
	check(again.channels.f[0] == original and again.geometry.shape[0] == 35 and r.records[0].descriptor.geometry.shape[0] == 35,"Caller cannot mutate cached values or trusted geometry")
	check(r.open(source) and r.index_state == "lazy record index" and r.records[0].descriptor.is_empty(),"Open indexes headers without descriptor validation")
	var index_path := r.cache_dir.path_join(r.source_path.sha256_text()+".sidx3.json")
	DirAccess.make_dir_recursive_absolute(r.cache_dir)
	var f := FileAccess.open(index_path,FileAccess.WRITE);f.store_string("corrupt");f.close()
	check(r.open(source) and r.index_state == "lazy record index","Legacy disposable index is ignored without startup parsing or writes")
	var bytes := FileAccess.get_file_as_bytes(source);var path := base.path_join("storage-working.ssc")
	f = FileAccess.open(path,FileAccess.WRITE);f.store_buffer(bytes.slice(0,bytes.size()-20));f.close()
	check(r.open(path) and r.records.size() == 1,"Interrupted final commit remains unavailable")
	f = FileAccess.open(path,FileAccess.WRITE);f.store_buffer(bytes);f.close()
	check(r.refresh() and r.records.size() == 2,"Growing committed tail discovered")
	var offset: int = r.records[0].offset;bytes[offset] ^= 1
	f = FileAccess.open(path,FileAccess.WRITE);f.store_buffer(bytes);f.close()
	check(r.read_sample("field",0).is_empty(),"Source mutation invalidates cache and fails checksum")
	r.close();DirAccess.remove_absolute(path)
	preload("res://video/render_job.gd").write_json(base.path_join("godot-storage.json"),{"checks":checks,"failures":failures})
	print("G3 STORAGE: ",checks," checks, ",failures," failures");quit(1 if failures else 0)

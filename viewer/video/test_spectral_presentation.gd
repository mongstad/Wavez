extends RefCounted
## CPU-only contracts shared by the graphical export acceptance harness.
const Spectral = preload("res://video/spectral_presentation.gd")
const Reader = preload("res://layers/scene_reader.gd")
const Identity = preload("res://video/source_identity.gd")
const Job = preload("res://video/render_job.gd")
var checks: Array = []

func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":"Pinned video snapshot: "+label})

func run(snapshot: Dictionary, directory: String, tree: SceneTree) -> Array:
	checks.clear()
	check(Spectral.validate(snapshot).is_empty(),"real verified reconstruction validates")
	var reader := Reader.new()
	check(reader.open(snapshot.source.path),"native scene opens")
	var identity := Identity.capture(reader)
	check(not identity.is_empty(),"local source identity captured")
	check(Spectral.binding_problem(snapshot,snapshot.source.path,identity).is_empty(),"analysis nanosecond stamp matches local source binding")
	check(Spectral.native_problem(snapshot,reader).is_empty(),"pinned native record and geometry match the scene reader")
	var changed := identity.duplicate(true); changed.uuid = "different-source"
	check(not Spectral.binding_problem(snapshot,snapshot.source.path,changed).is_empty(),"different source identity is refused")
	reader.close()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		check(false,"private test directory is writable"); return checks
	var staged := Spectral.stage(snapshot,directory)
	check(staged.get("ok",false),"bounded artifact copy succeeds: "+str(staged.get("error","")))
	if not staged.get("ok",false): return checks
	var job_path := directory.path_join("roundtrip-job.json")
	check(Job.write_json(job_path,{"capture_path":snapshot.source.path,"spectral_presentation":staged.snapshot}) == OK,"persisted job can be written")
	var persisted = JSON.parse_string(FileAccess.get_file_as_string(job_path))
	check(persisted is Dictionary and persisted.get("spectral_presentation") is Dictionary,"persisted job can be parsed")
	if not persisted is Dictionary or not persisted.get("spectral_presentation") is Dictionary: Spectral.cleanup(directory); return checks
	var decoded := Spectral.decode(persisted.spectral_presentation)
	check(decoded.get("data") == staged.snapshot.data and decoded.get("display") == staged.snapshot.display,"exact codec preserves every scientific and display value through JSON")
	var invalid_wire: Dictionary = persisted.spectral_presentation.duplicate(true); invalid_wire.numeric_encoding = "unknown"
	check(not Spectral.validate(Spectral.decode(invalid_wire)).is_empty(),"unknown numeric encoding is refused")
	var prepared := await Spectral.prepare(persisted.spectral_presentation,directory,tree,func():return false)
	check(not prepared.has("error") and prepared.get("planes",[]).size() == int(snapshot.data.geometry.shape[0]),"owned hash and full-resolution RF planes validate")
	prepared.clear()
	var cancelled := await Spectral.prepare(staged.snapshot,directory,tree,func():return true)
	check(cancelled.has("error") and "cancelled" in cancelled.error,"display preparation honors cancellation")
	var bad: Dictionary = staged.snapshot.duplicate(true); bad.data.algorithm = "tampered"
	var refused := await Spectral.prepare(bad,directory,tree,func():return false)
	check(refused.has("error") and "algorithm" in refused.error,"manifest algorithm mismatch refuses presentation")
	bad = snapshot.duplicate(true); bad.display.lower = -3e38; bad.display.upper = 3e38
	check(not Spectral.validate(bad).is_empty(),"float32 span overflow is refused")
	bad = snapshot.duplicate(true); bad.data.geometry.data_to_world[0] = 2.
	check(not Spectral.validate(bad).is_empty(),"unsupported transform is refused after JSON numeric conversion")
	var field := FileAccess.open(directory.path_join(Spectral.FIELD_FILE),FileAccess.READ_WRITE)
	if field == null: check(false,"test copy can be changed without touching source")
	else:
		var value := field.get_float(); field.seek(0); field.store_float(93. if value != 93. else 94.); field.close()
		refused = await Spectral.prepare(staged.snapshot,directory,tree,func():return false)
		check(refused.has("error") and "hash" in refused.error,"tampered copied field refuses presentation")
	var retained := FileAccess.open(directory.path_join("spectral/unknown.txt"),FileAccess.WRITE)
	if retained == null: check(false,"cleanup sentinel can be created")
	else: retained.store_string("Retained unknown file proves cleanup is bounded."); retained.close()
	Spectral.cleanup(directory)
	check(not FileAccess.file_exists(directory.path_join(Spectral.FIELD_FILE)) and not FileAccess.file_exists(directory.path_join(Spectral.MANIFEST_FILE)) and FileAccess.file_exists(directory.path_join("spectral/unknown.txt")),"cleanup removes only known private artifacts")
	return checks

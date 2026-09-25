extends SceneTree
const Index = preload("res://data/capture_index.gd")
const Reader = preload("res://layers/scene_reader.gd")
const Typed = preload("res://data/typed_decode.gd")
const Identity = preload("res://data/particle_identity.gd")
const Job = preload("res://video/render_job.gd")
class Worker extends RefCounted:
	var timings := {}
	func stopped() -> bool:return false
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(message);push_error(message)
func old_hex(value, length: int) -> bool:
	if not value is String or value.length() != length:return false
	for c in value:
		if c not in "0123456789abcdef":return false
	return true
func old_decimal(value) -> int:
	if not value is String or value.is_empty() or value.length()>19:return -1
	for c in value:
		if c not in "0123456789":return -1
	var result := int(value)
	return result if result>=0 and str(result)==value else -1
func parity(value) -> void:
	for length in [0,1,2,19,32,64,160]:check(Index.valid_hex(value,length)==old_hex(value,length),"Exact hex grammar: "+str(value))
	check(Index.decimal(value)==old_decimal(value),"Exact decimal grammar: "+str(value))
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for value in [null,0,1.0,true,[],{},"","0","00","+1","-0","-1","0x1","0X1","12_3"," 1","1\n","１２","١٢","9223372036854775807","9223372036854775808","9999999999999999999"]:parity(value)
	for code in range(1,256):
		var c := String.chr(code)
		for value in [c,"a"+c,c+"0","a".repeat(31)+c,"0".repeat(63)+c]:parity(value)
	var random := RandomNumberGenerator.new();random.seed = 100
	for i in range(2000):
		var value := ""
		for j in range(random.randi_range(0,24)):value += String.chr(random.randi_range(1,127))
		parity(value)
	var out := OS.get_cmdline_user_args()[0]
	var reader := Reader.new();check(reader.open(out.path_join("identity.ssc")),"Open identity fixture")
	var previous := {};var worker := Worker.new()
	for index in range(4):
		reader.describe("p",index)
		var entry: Dictionary = reader.samples.p[index];var descriptors: Array = []
		for a in entry.descriptor.arrays:descriptors.append({"name":a.name,"dtype":a.dtype,"components":int(a.shape[1]) if a.shape.size()==2 else 1,"required":true,"chunks":a.chunks})
		var descriptor := {"offset":entry.offset,"time":entry.time,"count":3,"has_ids":true,"channels":descriptors}
		var data := Typed.read(reader.file,descriptor,worker,previous)
		check(not data.has("error") and not data.is_empty(),"Read validated IDs")
		if index == 1:check(data.identity_map == previous.identity_map,"Identical ordered IDs share immutable map")
		elif index > 1:check(data.identity_map != previous.identity_map,"Reordered/changed IDs rebuild map")
		check(data.identity_map.rows.is_read_only(),"Identity lookup is immutable")
		var ids: PackedInt64Array = data.channels.particle_id
		for i in ids.size():check(data.identity_map.rows[ids[i]] == i,"Exact int64 row including IDs above 2^53")
		check(data.decoded_bytes == 4096+descriptors.size()*256+3*3*4+3*8+3*160,"Shared map retains full conservative memory charge")
		previous = data
	check(Identity.build(PackedInt64Array([1,1]),worker).has("error"),"Duplicate IDs still rejected")
	check(Identity.build(PackedInt64Array([-1,1]),worker).has("error"),"Negative IDs still rejected")
	reader.close()
	Job.write_json(out.path_join("load-checks.json"),{"checks":checks,"failures":failures})
	print("LOAD OPTIMIZATIONS: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

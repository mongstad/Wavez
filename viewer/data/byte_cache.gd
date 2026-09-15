extends RefCounted
var limit := 256*1024*1024
var used := 0
var entries: Dictionary = {}
var order: Array[int] = []
var hits := 0
var misses := 0
var evictions := 0
func clear() -> void:
	entries.clear(); order.clear(); used = 0
func configure(bytes: int) -> void:
	limit = maxi(0,bytes)
	_trim(0)
func _trim(incoming: int) -> void:
	while not order.is_empty() and used + incoming > limit:
		var oldest: int = order.pop_front()
		used -= int(entries[oldest].bytes)
		entries.erase(oldest); evictions += 1
func get_frame(index: int) -> Dictionary:
	if not entries.has(index): misses += 1; return {}
	hits += 1
	order.erase(index); order.append(index)
	# Containers are private to the caller; packed arrays detach on mutation.
	return entries[index].value.duplicate(true)
func put(index: int, value: Dictionary, bytes: int) -> void:
	if bytes > limit or limit == 0: return
	if entries.has(index):
		used -= int(entries[index].bytes); order.erase(index); entries.erase(index)
	_trim(bytes)
	entries[index] = {"value":value.duplicate(true),"bytes":bytes}
	order.append(index); used += bytes

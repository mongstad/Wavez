extends RefCounted
# Definition ownership only. Source validation/membership stays on the worker.
const VERSION := 1
const MAX_JSON := 1048576
var revision := 0
var definitions: Array = []
var groups: Array = []
var active := ""
var overlay := {"show_hidden":false,"visible":true,"maximum":256}
var error := ""

func find(key: String) -> Dictionary:
	for definition in definitions:
		if definition.key == key: return definition
	return {}

func snapshot() -> Dictionary:
	return {"version":VERSION,"revision":revision,"active":active,"definitions":definitions.duplicate(true),"groups":groups.duplicate(true),"overlay":overlay.duplicate(true)}

func put(definition: Dictionary) -> bool:
	var candidates := definitions.duplicate()
	var index := -1
	for i in range(candidates.size()):
		if candidates[i].key == definition.key: index = i;break
	if index < 0: candidates.append(definition.duplicate(true))
	else: candidates[index] = definition.duplicate(true)
	if candidates.size() > 256 or JSON.stringify({"definitions":candidates,"groups":groups}).to_utf8_buffer().size() > MAX_JSON-4096:
		error = "Selection state exceeds its 1 MiB / 256-definition budget; reduce definitions or group references.";return false
	definitions = candidates;active = definition.key;revision += 1;error = ""
	for group in groups:
		for member in group.members:
			if member.key == definition.key:member.revision = definition.revision;group.revision += 1
	return true

func remove(key: String) -> void:
	definitions = definitions.filter(func(d):return d.key != key)
	for group in groups:group.members = group.members.filter(func(m):return m.key != key);group.revision += 1
	if active == key:active = definitions[0].key if not definitions.is_empty() else ""
	revision += 1

func rename_active(name: String) -> bool:
	var d := find(active).duplicate(true)
	if d.is_empty() or name.is_empty() or name.length() > 128:return false
	d.name = name;d.revision += 1
	return put(d)

func group(name: String, members: Array) -> bool:
	if groups.size() >= 64 or name.is_empty() or name.length() > 128 or members.is_empty():
		error = "Group requires a name and selections; at most 64 groups.";return false
	var refs: Array = []
	var seen := {}
	for key in members:
		var d := find(key)
		if d.is_empty():error = "Group refers to an unavailable selection.";return false
		if not seen.has(key):refs.append({"key":key,"revision":d.revision});seen[key] = true
	var next := groups.duplicate();next.append({"key":"group-%d" % (revision+1),"revision":1,"name":name,"members":refs})
	if JSON.stringify({"definitions":definitions,"groups":next}).to_utf8_buffer().size() > MAX_JSON-4096:
		error = "Group references exceed the selection state budget.";return false
	groups = next
	revision += 1;return true

func rename_group(index: int, name: String) -> bool:
	if index<0 or index>=groups.size() or name.is_empty() or name.length()>128:return false
	var next := groups.duplicate(true);next[index].name = name;next[index].revision += 1
	if JSON.stringify({"definitions":definitions,"groups":next}).to_utf8_buffer().size() > MAX_JSON-4096:return false
	groups = next;revision += 1;return true

func remove_group(index: int) -> void:
	if index<0 or index>=groups.size():return
	groups.remove_at(index);revision += 1

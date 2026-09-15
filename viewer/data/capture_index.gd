extends RefCounted
# Native scene storage primitives. No capture format scanner or dispatch lives here.
const MAX_INDEX := 32*1024*1024
const MAX_CHUNK := 4*1024*1024
const MAX_DESC := 4*1024*1024
const MAX_IDS := 1000000
const TYPES := {"f4":4,"f8":8,"u4":4,"i8":8}

static func digest(bytes: PackedByteArray) -> String:
	var h := HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes)
	return h.finish().hex_encode()

static func parse_json(text: String):
	var parsed := JSON.new()
	if parsed.parse(text) != OK: return null
	return parsed.data
static func valid_hex(value, length: int) -> bool:
	if not value is String or value.length() != length: return false
	for c in value:
		if c not in "0123456789abcdef": return false
	return true

static func decimal(value) -> int:
	if not value is String or value.is_empty() or value.length() > 19: return -1
	for c in value:
		if c not in "0123456789": return -1
	var result := int(value)
	if result < 0 or str(result) != value: return -1
	return result

static func whole(value) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= 0 and value <= 9007199254740991 and int(value) == value

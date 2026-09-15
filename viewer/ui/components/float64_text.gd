extends RefCounted
## Bounded decimal -> IEEE-754 binary64, round-to-nearest/ties-to-even.
## Godot String.to_float underflows valid subnormals and misrounds some long mantissas.
## Integer limbs avoid both that parser and any intermediate floating-point rounding.
const LIMB_BITS := 30
const BASE := 1 << LIMB_BITS
const MASK := BASE - 1
const MAX_TEXT := 768

static func format_value(value: float) -> String:
	var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0, value)
	if value == 0.0 and bytes.decode_s64(0) < 0: return "-0.0"
	return JSON.stringify(value, "", false, true)

static func parse(text: String) -> Dictionary:
	var value := text.strip_edges()
	if value.length() > MAX_TEXT: return {"error": "Use at most 768 characters for a float64 value."}
	var syntax := RegEx.new()
	syntax.compile("^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$")
	if syntax.search(value) == null: return {"error": "Enter a finite decimal number; scientific notation is supported."}
	var negative := value.begins_with("-")
	value = value.trim_prefix("-").trim_prefix("+").to_lower()
	var parts := value.split("e")
	var mantissa: String = parts[0]
	var exponent := 0
	if parts.size() > 1:
		var exp_text: String = parts[1].trim_prefix("-").trim_prefix("+")
		while exp_text.length() > 1 and exp_text.begins_with("0"): exp_text = exp_text.substr(1)
		# Larger exponents cannot be compensated within the bounded mantissa length.
		if exp_text.length() > 4: return {"error": "Exponent is outside the finite float64 range."}
		exponent = exp_text.to_int() * (-1 if parts[1].begins_with("-") else 1)
	var dot := mantissa.find(".")
	if dot >= 0: exponent -= mantissa.length() - dot - 1
	var digits := mantissa.replace(".", "")
	while digits.length() > 1 and digits.begins_with("0"): digits = digits.substr(1)
	if digits == "0": return {"value": _from_bits(0, negative)}
	while digits.ends_with("0"): digits = digits.left(-1); exponent += 1
	var magnitude := digits.length() + exponent - 1
	if magnitude > 308: return {"error": "The value exceeds finite float64; the draft has been retained."}
	if magnitude < -324: return {"error": "The value underflows float64; the draft has been retained."}
	var numerator := PackedInt64Array([0])
	for digit in digits: numerator = _multiply_add(numerator, 10, digit.unicode_at(0) - 48)
	var denominator := PackedInt64Array([1])
	for index in absi(exponent):
		if exponent > 0: numerator = _multiply_add(numerator, 10, 0)
		else: denominator = _multiply_add(denominator, 10, 0)
	var binary_exponent := _bits(numerator) - _bits(denominator)
	if binary_exponent >= 0:
		if _compare(numerator, _shift(denominator, binary_exponent)) < 0: binary_exponent -= 1
	elif _compare(_shift(numerator, -binary_exponent), denominator) < 0: binary_exponent -= 1
	binary_exponent = maxi(binary_exponent, -1022)
	var shift := 52 - binary_exponent
	if shift >= 0: numerator = _shift(numerator, shift)
	else: denominator = _shift(denominator, -shift)
	var quotient := 0
	for bit in range(_bits(numerator) - _bits(denominator), -1, -1):
		var divisor := _shift(denominator, bit)
		if _compare(numerator, divisor) >= 0:
			numerator = _subtract(numerator, divisor)
			quotient |= 1 << bit
	var halfway := _compare(_shift(numerator, 1), denominator)
	if halfway > 0 or (halfway == 0 and quotient & 1): quotient += 1
	if quotient == 0: return {"error": "The value underflows float64; the draft has been retained."}
	if quotient == 1 << 53: quotient >>= 1; binary_exponent += 1
	if binary_exponent > 1023: return {"error": "The value exceeds finite float64; the draft has been retained."}
	var bits := quotient
	if quotient >= 1 << 52: bits = ((binary_exponent + 1023) << 52) | (quotient - (1 << 52))
	return {"value": _from_bits(bits, negative)}

static func _from_bits(bits: int, negative: bool) -> float:
	if negative: bits |= -9223372036854775807 - 1
	var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_s64(0, bits)
	return bytes.decode_double(0)

static func _multiply_add(number: PackedInt64Array, multiplier: int, carry: int) -> PackedInt64Array:
	var result := number.duplicate()
	for index in result.size():
		var product := result[index] * multiplier + carry
		result[index] = product & MASK; carry = product >> LIMB_BITS
	if carry: result.append(carry)
	return result

static func _bits(number: PackedInt64Array) -> int:
	var result := (number.size() - 1) * LIMB_BITS
	var last := number[-1]
	while last: last >>= 1; result += 1
	return result

static func _shift(number: PackedInt64Array, count: int) -> PackedInt64Array:
	var result := PackedInt64Array(); result.resize(count / LIMB_BITS)
	var carry := 0
	for limb in number:
		var shifted := (limb << (count % LIMB_BITS)) | carry
		result.append(shifted & MASK); carry = shifted >> LIMB_BITS
	if carry: result.append(carry)
	return result

static func _compare(a: PackedInt64Array, b: PackedInt64Array) -> int:
	if a.size() != b.size(): return 1 if a.size() > b.size() else -1
	for index in range(a.size() - 1, -1, -1):
		if a[index] != b[index]: return 1 if a[index] > b[index] else -1
	return 0

static func _subtract(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var result := a.duplicate(); var borrow := 0
	for index in result.size():
		var value := result[index] - (b[index] if index < b.size() else 0) - borrow
		borrow = 1 if value < 0 else 0; result[index] = value + BASE if value < 0 else value
	while result.size() > 1 and result[-1] == 0: result.resize(result.size() - 1)
	return result

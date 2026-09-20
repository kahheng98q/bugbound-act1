class_name SeededRng
extends RefCounted
## FNV-1a + Mulberry32, matching the original JavaScript uint32 operations.
var seed_text: String
var state: int
var calls := 0

func _init(value: String = "DEBUG-0001") -> void:
	seed_text = normalize(value)
	state = 2166136261
	for character in seed_text:
		state = ((state ^ character.unicode_at(0)) * 16777619) & 0xffffffff
	if state == 0:
		state = 0x6d2b79f5

static func normalize(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^A-Z0-9_-]")
	var cleaned := regex.sub(value.strip_edges().to_upper(), "", true).left(24)
	return cleaned if not cleaned.is_empty() else "DEBUG-0001"

static func mul32(a: int, b: int) -> int:
	# Split the product to avoid signed int64 overflow.
	return ((a & 0xffff) * b + (((a >> 16) * b & 0xffff) << 16)) & 0xffffffff

func next() -> float:
	state = (state + 0x6d2b79f5) & 0xffffffff
	var value := mul32(state ^ (state >> 15), state | 1)
	value = (value ^ ((value + mul32(value ^ (value >> 7), value | 61)) & 0xffffffff)) & 0xffffffff
	calls += 1
	return float((value ^ (value >> 14)) & 0xffffffff) / 4294967296.0

func pick(items: Array) -> Variant:
	return items[int(floor(next() * items.size()))]

func shuffled(items: Array) -> Array:
	var result := items.duplicate(true)
	for i in range(result.size() - 1, 0, -1):
		var j := int(floor(next() * (i + 1)))
		var temporary = result[i]
		result[i] = result[j]
		result[j] = temporary
	return result

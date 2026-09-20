class_name Catalog
extends RefCounted

static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
const STARTER := ["strike", "strike", "strike", "strike", "hotfix", "hotfix", "hotfix", "hotfix", "duck", "pair"]
const BEE := ["nectar", "pollen", "waggle", "comb", "guard", "sting", "swarm", "jelly"]
const BUG_KEYS := ["overflow", "memory", "hotPath", "firewall", "loop"]

static func card(key: String) -> Dictionary:
	for entry in data.cards:
		if entry.key == key:
			return entry.duplicate(true)
	return {}

static func describe(card_data: Dictionary) -> String:
	if card_data.has("description"):
		return card_data.description
	var parts: Array[String] = []
	for pair in [["damage", "Deal %d damage"], ["block", "Gain %d Block"], ["heal", "Repair %d HP"], ["draw", "Draw %d"], ["energy", "Gain %d Energy"], ["selfDamage", "Lose %d HP"]]:
		if card_data.get(pair[0], 0):
			parts.append(pair[1] % card_data[pair[0]])
	return " · ".join(parts)

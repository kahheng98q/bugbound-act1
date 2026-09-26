class_name Catalog
extends RefCounted

static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
const STARTER := ["strike", "strike", "strike", "strike", "hotfix", "hotfix", "hotfix", "hotfix", "duck", "pair"]
const BEE := ["nectar", "pollen", "waggle", "comb", "guard", "sting", "swarm", "jelly"]
const BUG_KEYS := ["overflow", "memory", "hotPath", "firewall", "loop"]
const LOADOUTS := {
	"balanced": {"name": "Balanced", "hint": "Learn the basics: attacks, Block, and draw.", "cards": STARTER},
	"nectar": {"name": "Nectar", "hint": "Grow Nectar, then turn it into damage and Block.", "cards": ["strike", "strike", "strike", "hotfix", "hotfix", "hotfix", "duck", "pair", "forage", "lance"]},
	"fortress": {"name": "Fortress", "hint": "Build Block, then strike with your defenses.", "cards": ["strike", "strike", "strike", "hotfix", "hotfix", "hotfix", "duck", "pair", "patch", "bash"]},
	"overdrive": {"name": "Overdrive", "hint": "Chain attacks to power up Threaded Strike.", "cards": ["strike", "strike", "strike", "hotfix", "hotfix", "hotfix", "duck", "pair", "thread", "trace"]},
	"spider": {"name": "Spider Debugger", "hint": "Capture triggered Bugs in a 2-slot Web, then release them as commands.", "cards": ["strike", "strike", "strike", "hotfix", "hotfix", "hotfix", "duck", "pair", "web_trap", "inject"]},
}
const REWARD_POOLS := {
	"nectar": ["forage", "lance", "wax", "nectar", "swarm", "jelly"],
	"fortress": ["bash", "patch", "guard", "cache", "rollback"],
	"overdrive": ["thread", "pollen", "waggle", "comb", "sting", "trace"],
	"spider": ["web_trap", "inject", "breakpoint", "stack_overflow", "release_candidate"],
}

static func reward_styles(loadout_key: String) -> Array:
	return ["spider", "fortress", "overdrive"] if loadout_key == "spider" else ["nectar", "fortress", "overdrive"]

static func reward_style(key: String) -> String:
	for style in REWARD_POOLS:
		if key in REWARD_POOLS[style]: return style
	return "balanced"

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

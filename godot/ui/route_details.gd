class_name RouteDetails
extends RefCounted
## Presentation copy for route nodes. Values are English source strings so GameUI.localize() can translate them.

static func kind_text(node: Dictionary) -> String:
	match node.get("kind", ""):
		"battle": return "BATTLE"
		"elite": return "ELITE"
		"event": return "ROUTE ANOMALY" if node.get("anomaly", false) else "EVENT"
		"secret": return "SECRET"
		"boss": return "BOSS"
	return "PATH"

static func title_text(node: Dictionary) -> String:
	return str(node.get("label", "PATH"))

static func trait_text(node: Dictionary) -> String:
	var enemy_key := str(node.get("enemy", ""))
	if not enemy_key.is_empty() and Catalog.data.enemies.has(enemy_key):
		var traits := {"folder": "Attacks or blocks", "cursor": "First Attack -3", "trash": "Growing attacks", "frozen": "Bugs add Block", "memoryHog": "Bugs add Strength", "antivirus": "Bugs raise Threat", "sentinel": "Skills strip Block", "wasp": "Third hit: 14"}
		return "%d HP\n%s" % [Catalog.data.enemies[enemy_key].hp, traits.get(enemy_key, "")]
	var event_key := str(node.get("event", ""))
	if not event_key.is_empty() and Catalog.data.events.has(event_key):
		var choices := {"update": "Repair or\nadd Unit Test", "unknownExe": "Risk for a card\nor gain max HP", "recursiveFolder": "Investigate\nor repair", "printerGhost": "Repair or\nadd Rollback", "secretRoot": "A card plus\nHP benefits"}
		return choices.get(event_key, Catalog.data.events[event_key].eyebrow)
	return "Route details unavailable."

static func status_text(unlocked: bool, passed: bool) -> String:
	if passed: return "COMPLETED"
	return "OPEN →" if unlocked else "LOCKED"

static func tooltip_text(node: Dictionary, unlocked: bool, passed: bool) -> String:
	var detail := trait_text(node)
	if node.has("enemy"): detail = Catalog.data.enemies[node.enemy].feature
	if node.has("event"): detail = Catalog.data.events[node.event].body
	return "%s\n%s\n%s\n%s" % [kind_text(node), title_text(node), detail, status_text(unlocked, passed)]

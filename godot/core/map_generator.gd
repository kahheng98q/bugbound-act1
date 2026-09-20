class_name MapGenerator
extends RefCounted

const BATTLES := [
	["folder", "Documents", "C:\\Desktop\\Documents"],
	["cursor", "Pointer Cache", "C:\\Desktop\\System32"],
	["trash", "Recycle Bin", "C:\\Desktop\\$Recycle.Bin"],
	["frozen", "Frozen App", "C:\\Desktop\\Programs"]]
const EVENTS := [
	["update", "System Update", "C:\\Desktop\\Updates"],
	["unknownExe", "Unknown.exe", "C:\\Desktop\\Downloads"],
	["recursiveFolder", "Folder (1) (1)", "C:\\Desktop\\Desktop"],
	["printerGhost", "Offline Printer", "C:\\Desktop\\Devices"]]

static func generate(rng: SeededRng) -> Array:
	var nodes: Array = []
	for tier in range(10):
		for lane in range(2):
			var roll := rng.next()
			var force_battle := tier == 0 or (lane == 0 and tier < 3)
			var kind := "battle" if force_battle else ("event" if roll < 0.2 else ("elite" if roll < 0.34 and tier > 2 else "battle"))
			var node := {"id": "t%dl%d" % [tier, lane], "tier": tier, "lane": lane, "kind": kind}
			if kind == "event":
				var event = rng.pick(EVENTS)
				var anomaly := rng.next() < 0.22
				node.merge({"event": "unknownExe" if anomaly else event[0], "label": "CORRUPTED ROUTE" if anomaly else event[1], "path": "C:\\Desktop\\???\\..\\YOU" if anomaly else event[2], "anomaly": anomaly})
			elif kind == "elite":
				node.merge({"enemy": "memoryHog", "label": "Memory Hog", "path": "C:\\Desktop\\TaskManager"})
			else:
				var battle = rng.pick(BATTLES.slice(0, 2) if tier < 3 else BATTLES)
				node.merge({"enemy": battle[0], "label": battle[1], "path": battle[2]})
			nodes.append(node)
	nodes.append({"id": "secret-root", "tier": 8, "lane": 2, "kind": "secret", "event": "secretRoot", "label": "C:\\Users\\???", "path": "ACCESS_REDACTED", "anomaly": true, "hidden": rng.next() >= 0.12})
	nodes.append({"id": "boss", "tier": 10, "lane": 0, "kind": "boss", "enemy": "antivirus", "label": "Security Center", "path": "C:\\Desktop\\Security"})
	return nodes

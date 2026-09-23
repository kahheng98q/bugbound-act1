class_name RunState
extends RefCounted
## Owns run persistence across screens; UI submits commands and observes changed.
signal changed
var rng: SeededRng
var screen := "menu"
var hp := 48
var max_hp := 48
var cards: Array = []
var serial := 1
var map: Array = []
var tier := 0
var completed: Array = []
var current: Dictionary = {}
var battle: Combat
var rewards: Array = []
var battles_won := 0
var bugs_triggered := 0
var elites_defeated := 0
var loadout_key := "balanced"
var flags := {"daemonDraw": 0, "startingBlock": 0, "secretFragments": 0, "secretUnlocked": false, "printerDebt": false}

func start(seed_text: String, starting_build := "balanced") -> void:
	if battle: battle.run = null
	battle = null
	rng = SeededRng.new(seed_text)
	map = MapGenerator.generate(rng)
	hp = 48
	max_hp = 48
	cards = []
	loadout_key = starting_build if Catalog.LOADOUTS.has(starting_build) else "balanced"
	for key in Catalog.LOADOUTS[loadout_key].cards: cards.append(Catalog.card(key))
	serial = 1
	tier = 0
	completed = []
	current = {}
	rewards = []
	battles_won = 0
	bugs_triggered = 0
	elites_defeated = 0
	flags = {"daemonDraw": 0, "startingBlock": 0, "secretFragments": 0, "secretUnlocked": false, "printerDebt": false}
	screen = "map"
	changed.emit()

func enter(id: String) -> void:
	if screen != "map": return
	for node in map:
		if node.id != id or node.tier != tier: continue
		if node.kind == "secret" and not flags.secretUnlocked: return
		current = node
		if node.has("event"): screen = "event"
		else:
			battle = Combat.new(self, node.enemy)
			screen = "battle"
		changed.emit()
		return

func play(id: int) -> void:
	if screen == "battle" and battle.play(id): settle()

func end_turn() -> void:
	if screen == "battle" and battle.end_turn(): settle()

func popup(allow: bool) -> void:
	if screen != "battle": return
	battle.resolve_popup(allow)
	settle()

func choose(id: int) -> void:
	if screen != "battle": return
	battle.choose_card(id)
	changed.emit()

func settle() -> void:
	hp = battle.hp
	if hp <= 0:
		screen = "defeat"
	elif battle.enemy_hp <= 0:
		bugs_triggered += battle.triggers
		battles_won += 1
		completed.append(current.id)
		if Catalog.data.enemies[battle.enemy_key].kind == "elite": elites_defeated += 1
		screen = "victory" if battle.enemy_key == "antivirus" else "reward"
		if screen == "reward":
			rewards = []
			# Each offer supports a different strategy; the pools do not overlap.
			for style in Catalog.REWARD_POOLS:
				rewards.append(Catalog.card(rng.pick(Catalog.REWARD_POOLS[style])))
	if screen != "battle":
		battle.run = null
		battle = null
	changed.emit()

func reward(index: int) -> void:
	if screen != "reward" or index < -1 or index >= rewards.size(): return
	if index >= 0: cards.append(rewards[index].duplicate(true))
	rewards = []
	advance()

func event(left: bool) -> void:
	if screen != "event": return
	match current.event:
		"update":
			if left: hp = mini(max_hp, hp + 14)
			else: cards.append(Catalog.card("test"))
		"unknownExe":
			if left:
				hp = maxi(1, hp - 5)
				cards.append(rng.pick(Catalog.data.cards.filter(func(card): return card.key not in ["strike", "hotfix"])).duplicate(true))
				flags.daemonDraw = 1
				if current.get("anomaly", false): flags.secretFragments += 1
			else:
				flags.startingBlock += 9
				max_hp += 2
				hp += 2
		"recursiveFolder":
			if left:
				hp = maxi(1, hp - 3)
				flags.secretFragments += 1
				cards.append(Catalog.card("trace"))
			else: hp = mini(max_hp, hp + 7)
		"printerGhost":
			if left:
				hp = mini(max_hp, hp + 4 + int(floor(rng.next() * 6)))
				flags.printerDebt = true
			else: cards.append(Catalog.card("rollback"))
		"secretRoot":
			if left:
				cards.append(Catalog.card("ship"))
				max_hp += 4
				hp += 4
			else:
				cards.append(Catalog.card("cache"))
				hp = mini(max_hp, hp + 12)
	for node in map:
		if node.kind == "secret" and not node.hidden and flags.secretFragments > 0: flags.secretUnlocked = true
	completed.append(current.id)
	advance()

func advance() -> void:
	tier += 1
	current = {}
	screen = "map"
	changed.emit()

func abandon() -> void:
	if battle: battle.run = null
	battle = null
	screen = "menu"
	changed.emit()

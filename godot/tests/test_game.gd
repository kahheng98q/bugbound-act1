extends SceneTree
## Run: godot --headless --path godot --script res://tests/test_game.gd
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func map_signature(nodes: Array) -> String:
	var result := ""
	for node in nodes:
		result += "%s:%s:%s:%s|" % [node.id, node.kind, node.get("enemy", node.get("event", "")), node.get("anomaly", false)]
	return result

func map_topology_signature(nodes: Array) -> String:
	var result := ""
	for node in nodes:
		# Encounters after tier 3 may expand, but route kind, event/anomaly rolls, and node ids stay seeded.
		result += "%s:%s:%s|" % [node.id, node.kind, node.get("event", ""), node.get("anomaly", false)]
	return result

func _initialize() -> void:
	seed_parity()
	combat_rules()
	bee_rules()
	run_flow()
	print("BUGBOUND: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func seed_parity() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/legacy_fixtures.json"))
	check(SeededRng.normalize("  bug 404!!  ") == "BUG404", "Seed normalization")
	for fixture in fixtures:
		var rng := SeededRng.new(fixture.seed)
		for expected in fixture.values: check(abs(rng.next() - expected) < 0.000000001, "JavaScript RNG parity: " + fixture.seed)
		rng = SeededRng.new(fixture.seed)
		var map := MapGenerator.generate(rng)
		var legacy_early := map.filter(func(node): return node.tier < 3)
		var generated_early := fixture.map.nodes.filter(func(node): return node.tier < 3)
		check(map_signature(legacy_early) == map_signature(generated_early), "JavaScript early-map identity parity: " + fixture.seed)
		check(map_topology_signature(map) == map_topology_signature(fixture.map.nodes), "JavaScript map topology parity after encounter expansion: " + fixture.seed)
		check(rng.calls == fixture.map.rng.calls and rng.state == fixture.map.rng.state, "Map RNG cursor parity")
		var replay_rng := SeededRng.new(fixture.seed)
		check(map_signature(map) == map_signature(MapGenerator.generate(replay_rng)), "Known seeded encounter map is reproducible: " + fixture.seed)

func fresh(enemy := "folder") -> RunState:
	var run := RunState.new()
	run.start("TEST-RUN")
	run.current = {"id": "test"}
	run.screen = "battle"
	run.battle = Combat.new(run, enemy)
	run.battle.enemy_hp = 1000
	run.battle.bug = "hotPath"
	run.battle.deck.clear()
	run.battle.hand.clear()
	run.battle.discard.clear()
	return run

func give(b: Combat, key: String) -> Dictionary:
	var card := Catalog.card(key)
	card.id = b.run.serial
	b.run.serial += 1
	b.hand.append(card)
	return card

func dispose(run: RunState) -> void:
	if run.battle: run.battle.run = null
	run.battle = null

func combat_rules() -> void:
	for bug in Catalog.BUG_KEYS:
		var run := fresh()
		var b := run.battle
		b.bug = bug
		b.energy = 1
		var key := "strike"
		if bug == "memory": key = "duck"
		if bug == "firewall": key = "hotfix"
		if bug == "hotPath": b.progress = 1
		if bug == "loop": b.progress = 2
		var card := give(b, key)
		b.play(card.id)
		check(b.triggers == 1 and b.bug != bug and b.progress == 0, "One mutation per player action: " + bug)
		match bug:
			"overflow": check(b.energy == 1 and b.strength == 1, "Overflow reward and risk")
			"memory": check(b.hp == 46, "Memory risk")
			"hotPath": check(b.enemy_hp == 988 and b.hp == 46, "Hot Path reward and risk")
			"firewall":
				check(b.block == 14 and b.debt == 1, "Firewall reward and debt")
				b.end_turn()
				check(b.energy == 2 and b.debt == 0, "Debt consumed next turn")
			"loop": check(b.energy == 2 and b.hp == 45, "Infinite Loop reward and risk")
		dispose(run)
	var run := fresh("antivirus")
	var b := run.battle
	for i in range(8): b.trigger_bug()
	check(b.threat == 6 and b.intent_damage() == b.intent.damage + b.strength + 12, "Boss threat cap and damage")
	b.popup_open = true
	var card := give(b, "strike")
	check(not b.play(card.id) and not b.end_turn(), "Popup locks combat")
	b.hp = 4
	run.popup(true)
	check(run.screen == "defeat" and run.battle == null, "Popup damage can end the run")
	dispose(run)
	run = fresh("cursor")
	b = run.battle
	b.play(give(b, "strike").id)
	check(b.enemy_hp == 997 and b.bee.nectar == 1, "Cursor first attack and nectar")
	dispose(run)

func bee_rules() -> void:
	var run := fresh()
	var b := run.battle
	b.play(give(b, "nectar").id)
	check(b.energy == 0 and b.bee.bank == 3 and b.discard.is_empty(), "Nectar caches and exhausts")
	b.end_turn()
	check(b.energy == 6 and b.bee.bank == 0, "Cached energy returns once")
	b.bug = "loop"
	b.play(give(b, "pollen").id)
	b.play(give(b, "hotfix").id)
	b.play(give(b, "strike").id)
	check(b.bee.pollen >= 0 and b.block >= 0, "Pollen pipeline remains valid after chained cards")
	dispose(run)
	run = fresh()
	b = run.battle
	b.bee.nectar = 2
	var target := give(b, "cache")
	b.play(give(b, "jelly").id)
	check(not b.choice.is_empty() and not b.end_turn(), "Jelly requires target choice")
	b.choose_card(target.id)
	check(target.cost == 1 and b.choice.is_empty(), "Jelly reduces battle-copy cost")
	run.cards.append(Catalog.card("sting"))
	b.play(give(b, "sting").id)
	check(not run.cards.any(func(c): return c.key == "sting"), "Sting permanently removes a run copy")
	dispose(run)
	run = fresh()
	b = run.battle
	var top: Array = []
	for key in ["strike", "hotfix", "duck"]:
		top.append(give(b, key))
	b.hand.clear()
	b.deck = top.duplicate()
	b.play(give(b, "waggle").id)
	b.choose_card(top[1].id)
	b.choose_card(top[2].id)
	b.choose_card(top[0].id)
	check(b.choice.is_empty() and b.hand[0].key == "hotfix" and b.deck[0].key == "duck" and b.deck[1].key == "strike", "Waggle draw and ordered return")
	dispose(run)
	run = fresh()
	b = run.battle
	b.energy = 100
	b.play(give(b, "comb").id)
	b.play(give(b, "hotfix").id)
	for i in range(5): b.play(give(b, "pair").id)
	check(b.bee.comb == 0 and b.block >= 12, "Compiler repeats first printed block every six cards")
	dispose(run)
	run = fresh()
	b = run.battle
	b.play(give(b, "guard").id)
	b.enemy_hp = 8
	b.intent = {"damage": 10, "block": 0, "label": "hit"}
	run.end_turn()
	check(run.screen == "reward", "Hive retaliation can win a battle")
	dispose(run)

func run_flow() -> void:
	var run := RunState.new()
	run.start("FLOW")
	run.enter("boss")
	check(run.screen == "map", "Future nodes cannot be entered")
	run.enter("t0l0")
	check(run.battle != null and run.battle.hand.size() == 5, "Opening battle")
	run.battle.enemy_hp = 0
	run.settle()
	check(run.screen == "reward" and run.rewards.size() == 3, "Three seeded rewards")
	var count := run.cards.size()
	run.reward(0)
	check(run.cards.size() == count + 1 and run.tier == 1 and run.screen == "map", "Reward preserves deck and advances")
	for key in Catalog.data.events.keys():
		for left in [true, false]:
			run.current = {"id": "event-test", "event": key, "anomaly": true}
			run.screen = "event"
			run.event(left)
			check(run.screen == "map" and run.hp > 0 and run.hp <= run.max_hp, "Event resolution: " + key)
	run.tier = 10
	run.enter("boss")
	run.battle.enemy_hp = 0
	run.settle()
	check(run.screen == "victory", "Boss completes Act 1")
	run.abandon()
	check(run.screen == "menu", "Return to menu")
	dispose(run)

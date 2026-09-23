extends SceneTree
## Run: .\run-godot.ps1 --headless --path godot --script res://tests/test_variety.gd

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func card_keys(cards: Array) -> Array:
	return cards.map(func(card): return card.key)

func map_signature(nodes: Array) -> String:
	var result := ""
	for node in nodes:
		result += "%s:%s:%s:%s|" % [node.id, node.kind, node.get("enemy", node.get("event", "")), node.get("anomaly", false)]
	return result

func fresh(enemy := "folder") -> RunState:
	var run := RunState.new()
	run.start("VARIETY", "balanced")
	run.current = {"id": "test"}
	run.screen = "battle"
	run.battle = Combat.new(run, enemy)
	run.battle.enemy_hp = 1000
	run.battle.deck.clear()
	run.battle.hand.clear()
	run.battle.discard.clear()
	return run

func give(battle: Combat, key: String) -> Dictionary:
	var card := Catalog.card(key)
	card.id = battle.run.serial
	battle.run.serial += 1
	battle.hand.append(card)
	return card

func dispose(run: RunState) -> void:
	if run.battle: run.battle.run = null
	run.battle = null

func _initialize() -> void:
	catalog_and_loadouts()
	card_scaling_and_nectar()
	enemy_rules()
	map_and_rewards()
	print("BUGBOUND variety: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func catalog_and_loadouts() -> void:
	var loadout_keys := ["balanced", "nectar", "fortress", "overdrive"]
	check(Catalog.LOADOUTS.keys().size() == loadout_keys.size(), "Catalog exposes exactly the four loadouts")
	for key in loadout_keys:
		check(Catalog.LOADOUTS.has(key) and Catalog.LOADOUTS[key].cards.size() == 10, "Ten-card loadout: " + key)
	check(Catalog.LOADOUTS.balanced.cards == Catalog.STARTER, "Balanced loadout preserves the original starter deck")
	check("forage" in Catalog.LOADOUTS.nectar.cards and "lance" in Catalog.LOADOUTS.nectar.cards, "Nectar loadout starts its Nectar engine")
	check("patch" in Catalog.LOADOUTS.fortress.cards and "bash" in Catalog.LOADOUTS.fortress.cards, "Fortress loadout starts its Block engine")
	check("thread" in Catalog.LOADOUTS.overdrive.cards and "trace" in Catalog.LOADOUTS.overdrive.cards, "Overdrive loadout starts its attack chain")
	for key in ["forage", "lance", "wax", "bash", "patch", "thread"]:
		check(not Catalog.card(key).is_empty(), "Catalog contains " + key)
	check(Catalog.card("forage").cost == 1 and Catalog.card("forage").kind == "skill" and Catalog.card("forage").block == 4 and Catalog.card("forage").nectarGain == 2, "Forage definition")
	check(Catalog.card("lance").cost == 1 and Catalog.card("lance").damage == 5 and Catalog.card("lance").scaling == "nectar_damage", "Lance definition")
	check(Catalog.card("wax").cost == 1 and Catalog.card("wax").block == 4 and Catalog.card("wax").scaling == "nectar_block", "Wax definition")
	check(Catalog.card("bash").cost == 1 and Catalog.card("bash").damage == 3 and Catalog.card("bash").scaling == "block_damage", "Bash definition")
	check(Catalog.card("patch").cost == 0 and Catalog.card("patch").block == 3 and Catalog.card("patch").exhausted, "Patch definition")
	check(Catalog.card("thread").cost == 1 and Catalog.card("thread").damage == 4 and Catalog.card("thread").scaling == "attacks_damage", "Thread definition")
	var run := RunState.new()
	run.start("LOADOUT-SEED", "nectar")
	check(run.loadout_key == "nectar" and card_keys(run.cards) == Catalog.LOADOUTS.nectar.cards, "Selected loadout resets the deck")
	var first_map := map_signature(run.map)
	run.start("LOADOUT-SEED", "nectar")
	check(card_keys(run.cards) == Catalog.LOADOUTS.nectar.cards and map_signature(run.map) == first_map, "Selected loadout is deterministic")
	run.start("LOADOUT-SEED", "missing")
	check(run.loadout_key == "balanced" and card_keys(run.cards) == Catalog.STARTER, "Unknown loadout falls back to balanced")

func card_scaling_and_nectar() -> void:
	var run := fresh()
	var battle := run.battle
	battle.bee.nectar = 3
	battle.block = 10
	battle.attacks = 2
	for expected in [
		["forage", 0, 4], ["lance", 11, 0], ["wax", 0, 10], ["bash", 13, 0], ["patch", 0, 3], ["thread", 10, 0]
	]:
		var preview := battle.preview_card(Catalog.card(expected[0]))
		check(preview.damage == expected[1] and preview.block == expected[2], "Preview resolves scaling for " + expected[0])
	battle.bee.nectar = 2
	battle.attacks = 0
	battle.energy = 3
	var lance := give(battle, "lance")
	battle.play(lance.id)
	check(battle.enemy_hp == 991 and battle.bee.nectar == 3, "Lance resolves from current Nectar before first-Attack Nectar gain")
	battle.energy = 3
	var forage := give(battle, "forage")
	battle.play(forage.id)
	check(battle.bee.nectar == 5 and battle.block >= 4, "Forage gains two Nectar")
	battle.energy = 3
	var patch := give(battle, "patch")
	battle.play(patch.id)
	check(not battle.discard.any(func(card): return card.id == patch.id), "Patch exhausts")
	battle.attacks = 4
	battle.end_turn()
	check(battle.attacks == 0, "Attack counter resets at end of turn")
	dispose(run)

func enemy_rules() -> void:
	var run := fresh("sentinel")
	var battle := run.battle
	check(battle.enemy_hp == 42 and battle.intent.damage == 6 and battle.intent.block == 8, "Sentinel opens with its odd-turn intent")
	var calls := run.rng.calls
	battle.next_intent()
	check(run.rng.calls == calls + 1, "Sentinel intent still consumes one RNG value")
	battle.turn = 2
	battle.next_intent()
	check(battle.intent.damage == 11 and battle.intent.block == 0, "Sentinel alternates to its even-turn intent")
	battle.enemy_shield = 7
	battle.energy = 3
	var wax := give(battle, "wax")
	battle.play(wax.id)
	check(battle.enemy_shield == 5, "Skills strip two Sentinel Block before their effects")
	dispose(run)
	run = fresh("wasp")
	battle = run.battle
	check(battle.enemy_hp == 38 and battle.intent.damage == 4, "Wasp opens with its regular sting")
	battle.turn = 2
	battle.next_intent()
	check(battle.intent.damage == 4, "Wasp second turn remains regular")
	battle.turn = 3
	battle.next_intent()
	check(battle.intent.damage == 14, "Wasp stings hard every third turn")
	dispose(run)

func map_and_rewards() -> void:
	var seen := {}
	for seed in ["ROUTE-%d" % i for i in range(24)]:
		var map := MapGenerator.generate(SeededRng.new(seed))
		var replay := MapGenerator.generate(SeededRng.new(seed))
		check(map_signature(map) == map_signature(replay), "Expanded encounter map is reproducible: " + seed)
		for node in map:
			if node.has("enemy"): seen[node.enemy] = true
			if node.tier < 3 and node.kind == "battle":
				check(node.enemy in ["folder", "cursor"], "Early route remains safe: " + node.id)
	check(seen.has("sentinel") and seen.has("wasp"), "New encounters are reachable across seeded maps")
	var expected_pools := {
		"nectar": ["forage", "lance", "wax", "nectar", "swarm", "jelly"],
		"fortress": ["bash", "patch", "guard", "cache", "rollback"],
		"overdrive": ["thread", "pollen", "waggle", "comb", "sting", "trace"]
	}
	check(Catalog.REWARD_POOLS.keys().size() == expected_pools.size(), "Catalog exposes the three themed reward groups")
	for style in expected_pools:
		check(Catalog.REWARD_POOLS[style] == expected_pools[style], "Reward group membership: " + style)
	var first := RunState.new()
	first.start("REWARD-GROUPS", "balanced")
	first.enter("t0l0")
	first.battle.enemy_hp = 0
	first.settle()
	var rewards := card_keys(first.rewards)
	var unique := {}
	var styles := {}
	for key in rewards:
		unique[key] = true
		styles[Catalog.reward_style(key)] = true
	check(rewards.size() == 3 and unique.size() == 3, "Reward offers three unique cards")
	check(styles.size() == 3 and styles.has("nectar") and styles.has("fortress") and styles.has("overdrive"), "Reward offers one pick from each strategy group")
	var replay := RunState.new()
	replay.start("REWARD-GROUPS", "balanced")
	replay.enter("t0l0")
	replay.battle.enemy_hp = 0
	replay.settle()
	check(rewards == card_keys(replay.rewards), "Reward offer is reproducible")

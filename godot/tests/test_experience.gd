extends SceneTree
## Focused rule tests for card previews. Run from the repository root:
## .\run-godot.bat --headless --path godot --script res://tests/test_experience.gd

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func fresh(enemy := "folder") -> RunState:
	var run := RunState.new()
	run.start("PREVIEW-TEST")
	run.current = {"id": "test"}
	run.screen = "battle"
	run.battle = Combat.new(run, enemy)
	run.battle.enemy_hp = 1000
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

func _initialize() -> void:
	preview_matches_resolution()
	preview_effects()
	preview_turn_and_bug_consequences()
	preview_is_read_only()
	incoming_damage_rules()
	print("BUGBOUND EXPERIENCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func preview_matches_resolution() -> void:
	var cases := [
		{"bug": "overflow", "card": "strike", "energy": 1},
		{"bug": "memory", "card": "duck", "energy": 1},
		{"bug": "hotPath", "card": "strike", "energy": 1, "progress": 1},
		{"bug": "firewall", "card": "guard", "energy": 1},
		{"bug": "loop", "card": "strike", "energy": 1, "progress": 2},
	]
	for fixture in cases:
		var run := fresh()
		var b := run.battle
		b.bug = fixture.bug
		b.energy = fixture.energy
		b.progress = fixture.get("progress", 0)
		var card := give(b, fixture.card)
		var preview := b.preview_card(card)
		check(preview.triggers_bug, "Preview predicts bug trigger: " + fixture.bug)
		b.play(card.id)
		check(b.triggers == 1, "Resolved card triggers predicted bug: " + fixture.bug)
		dispose(run)

	# Waggle only triggers Memory Leak when it can present a card choice.
	var run := fresh()
	var b := run.battle
	b.bug = "memory"
	b.energy = 1
	b.deck.append(Catalog.card("strike"))
	var waggle := give(b, "waggle")
	check(b.preview_card(waggle).triggers_bug, "Waggle preview detects an available draw choice")
	b.play(waggle.id)
	check(b.triggers == 1, "Waggle resolution triggers Memory Leak with a choice")
	dispose(run)
	run = fresh()
	b = run.battle
	b.bug = "memory"
	b.energy = 1
	waggle = give(b, "waggle")
	check(not b.preview_card(waggle).triggers_bug, "Waggle preview rejects an empty draw choice")
	b.play(waggle.id)
	check(b.triggers == 0, "Empty Waggle does not trigger Memory Leak")
	dispose(run)

func preview_effects() -> void:
	var run := fresh("cursor")
	var b := run.battle
	b.bug = "memory"
	b.energy = 3
	b.bee.pollen = 1
	b.bee.damage = 4
	b.bee.block = 3
	var strike := give(b, "strike")
	var preview := b.preview_card(strike)
	check(preview.damage == 7 and preview.block == 3, "Preview includes Pollen and Cursor's first-attack reduction")
	var hp_before := b.enemy_hp
	b.play(strike.id)
	check(hp_before - b.enemy_hp == preview.damage, "Pollen/Cursor preview damage resolves exactly")
	dispose(run)

	run = fresh()
	b = run.battle
	b.energy = 3
	b.bee.nectar = 2
	var swarm := give(b, "swarm")
	preview = b.preview_card(swarm)
	check(preview.damage == 9 and preview.nectar_spent == 2, "Swarm preview reports Nectar-scaled direct damage")
	hp_before = b.enemy_hp
	b.play(swarm.id)
	check(hp_before - b.enemy_hp == preview.damage and b.bee.nectar == 1, "Swarm resolution spends previewed Nectar before its first-attack gain")
	dispose(run)

	run = fresh()
	b = run.battle
	b.energy = 2
	b.bee.nectar = 2
	var target := give(b, "cache")
	var jelly := give(b, "jelly")
	preview = b.preview_card(jelly)
	check(preview.nectar_spent == 2 and preview.damage == 0 and not preview.triggers_bug, "Jelly preview exposes its Nectar cost without turn effects")
	check(b.can_play(jelly), "Jelly is enabled with Nectar and a valid target")
	b.bee.nectar = 1
	check(not b.can_play(jelly) and not b.preview_card(jelly).triggers_bug, "Disabled Jelly cannot preview a bug trigger")
	b.bee.nectar = 2
	target.cost = 0
	check(not b.can_play(jelly), "Jelly is disabled when no costly target remains")
	dispose(run)

	# A card that otherwise completes Hot Path must remain inert while unaffordable.
	run = fresh()
	b = run.battle
	b.bug = "hotPath"
	b.progress = 1
	b.energy = 0
	strike = give(b, "strike")
	check(not b.preview_card(strike).triggers_bug, "Unaffordable cards do not preview bug triggers")
	dispose(run)

func preview_turn_and_bug_consequences() -> void:
	var run := fresh()
	var b := run.battle
	b.debt = 5
	b.bee.bank = 4
	check(b.next_turn_energy() == 4, "Next-turn Energy floors stacked debt before adding banked Energy")
	b.debt = 0
	b.bee.bank = 2
	b.energy = 3
	var nectar := give(b, "nectar")
	var preview := b.preview_card(nectar)
	check(preview.next_turn_bank == 5 and preview.next_turn_debt == 0 and preview.next_turn_energy == 8, "Nectar preview banks current Energy for the next turn")
	dispose(run)
	run = fresh()
	b = run.battle
	b.bug = "firewall"
	b.energy = 1
	var guard := give(b, "guard")
	preview = b.preview_card(guard)
	check(preview.next_turn_bank == 0 and preview.next_turn_debt == 1 and preview.next_turn_energy == 2, "Bug debt reduces projected next-turn Energy")
	dispose(run)

	var cases := [
		{"bug": "overflow", "damage": 0, "block": 0, "draw": 2, "energy": 1, "hp_loss": 0, "debt": 0, "enemy_strength": 1},
		{"bug": "memory", "damage": 0, "block": 0, "draw": 2, "energy": 0, "hp_loss": 2, "debt": 0, "enemy_strength": 0},
		{"bug": "hotPath", "damage": 6, "block": 0, "draw": 0, "energy": 0, "hp_loss": 2, "debt": 0, "enemy_strength": 0},
		{"bug": "firewall", "damage": 0, "block": 8, "draw": 0, "energy": 0, "hp_loss": 0, "debt": 1, "enemy_strength": 0},
		{"bug": "loop", "damage": 0, "block": 0, "draw": 0, "energy": 2, "hp_loss": 3, "debt": 0, "enemy_strength": 0},
	]
	for expected in cases:
		run = fresh()
		b = run.battle
		b.bug = expected.bug
		b.hp = 20
		b.energy = 3
		b.enemy_hp = 100
		b.deck.append(Catalog.card("strike"))
		var consequences := b.bug_consequences()
		var expected_consequences: Dictionary = expected.duplicate()
		expected_consequences.erase("bug")
		check(consequences == expected_consequences, "Bug consequence schema matches " + expected.bug)
		var hp_before := b.hp
		var enemy_hp_before := b.enemy_hp
		var block_before := b.block
		var energy_before := b.energy
		var debt_before := b.debt
		var strength_before := b.strength
		b.trigger_bug()
		check(enemy_hp_before - b.enemy_hp == expected.damage and b.block - block_before == expected.block and b.energy - energy_before == expected.energy and hp_before - b.hp == expected.hp_loss and b.debt - debt_before == expected.debt and b.strength - strength_before == expected.enemy_strength, "Bug resolution matches preview consequences: " + expected.bug)
		check(b.triggers == 1 and b.bug != expected.bug, "Bug resolution records and mutates " + expected.bug)
		dispose(run)

func preview_is_read_only() -> void:
	var run := fresh()
	var b := run.battle
	b.bug = "memory"
	b.energy = 1
	b.deck.append(Catalog.card("strike"))
	var waggle := give(b, "waggle")
	var rng_state := run.rng.state
	var rng_calls := run.rng.calls
	var deck_size := b.deck.size()
	var first := b.preview_card(waggle)
	var second := b.preview_card(waggle)
	check(first == second, "Repeated previews are stable")
	check(run.rng.state == rng_state and run.rng.calls == rng_calls and b.deck.size() == deck_size, "Repeated previews leave RNG and deck unchanged")
	dispose(run)

func incoming_damage_rules() -> void:
	var run := fresh("antivirus")
	var b := run.battle
	b.intent = {"damage": 10, "block": 0, "label": "test"}
	b.strength = 3
	b.threat = 2
	b.block = 4
	check(b.intent_damage() == 17 and b.incoming_damage() == 13, "Incoming damage includes Strength, Antivirus Threat, and Block")
	b.block = 20
	check(b.incoming_damage() == 0, "Incoming damage does not fall below zero")
	dispose(run)

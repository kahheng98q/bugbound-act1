extends SceneTree
## Focused Phase 2 combat-status HUD checks.
## Run: .\run-godot.ps1 --headless --path godot --script res://tests/test_status_hud.gd

var game: Control
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func settle() -> void:
	for _frame in range(5):
		await process_frame

func add_card(battle: Combat, key: String) -> Dictionary:
	var card := Catalog.card(key)
	card.id = battle.run.serial
	battle.run.serial += 1
	battle.hand.append(card)
	return card

func configure_battle() -> Combat:
	game.run.start("STATUS-HUD-SEED")
	game.run.current = {"id": "status-hud"}
	game.run.screen = "battle"
	game.run.battle = Combat.new(game.run, "folder")
	var battle: Combat = game.run.battle
	battle.enemy_hp = 999
	battle.deck.clear()
	battle.hand.clear()
	battle.discard.clear()
	battle.exhaust.clear()
	battle.hp = game.run.max_hp
	battle.block = 0
	battle.energy = 1
	battle.strength = 0
	battle.bug = "firewall"
	# The 20-point hit demonstrates that end turn uses the actual accumulated Block.
	battle.intent = {"damage": 20, "block": 0, "label": "status test"}
	game.render()
	await settle()
	return battle

func require_control(name_: String) -> Control:
	var control := game.find_child(name_, true, false) as Control
	check(control != null, "HUD control exists: " + name_)
	return control

func check_bounds(control: Control, viewport: Rect2, description: String) -> void:
	if control == null: return
	var rect := control.get_global_rect()
	check(rect.size.x > 0 and rect.size.y > 0, description + " has visible bounds")
	check(viewport.encloses(rect), description + " fits viewport")

func check_health(header: Control, expected_value: int, expected_maximum: int, expected_block: int, viewport: Rect2) -> void:
	var value := header.find_child("HPValue", true, false) as Label
	check(value != null, header.name + " HP value label exists")
	if value:
		check(value.text == "%d / %d" % [expected_value, expected_maximum], header.name + " HP text matches combat state")
		check_bounds(value, viewport, header.name + " HP value")
	var meter := header.find_child("HPMeter", true, false) as Control
	check(meter != null, header.name + " HP meter exists")
	if meter:
		check(int(meter.get("value")) == expected_value, header.name + " meter value matches combat state")
		check(int(meter.get("maximum")) == expected_maximum, header.name + " meter maximum matches combat state")
		check_bounds(meter, viewport, header.name + " HP meter")
	var block_badge := header.find_child("BlockBadge", true, false) as Label
	check(block_badge != null, header.name + " Block badge exists")
	if block_badge:
		check(block_badge.text == str(expected_block), header.name + " Block text matches combat state")
		check_bounds(block_badge, viewport, header.name + " Block badge")

func check_status(battle: Combat, dimensions: Vector2i, stage: String) -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(dimensions))
	var player := require_control("PlayerCombatHeader")
	var enemy := require_control("EnemyCombatHeader")
	var energy_module := require_control("EnergyModule")
	check_bounds(player, viewport, stage + " player header")
	check_bounds(enemy, viewport, stage + " enemy header")
	check_bounds(energy_module, viewport, stage + " energy module")
	if player:
		check_health(player, battle.hp, game.run.max_hp, battle.block, viewport)
	if enemy:
		var enemy_data: Dictionary = Catalog.data.enemies[battle.enemy_key]
		check_health(enemy, battle.enemy_hp, enemy_data.hp, battle.enemy_shield, viewport)
		var strength := enemy.find_child("EnemyStrength", true, false) as Label
		check(strength != null, "Enemy strength label exists")
		if strength:
			check(strength.text == "力量 +%d" % battle.strength, "Enemy strength text matches combat state")
			check_bounds(strength, viewport, "Enemy strength")
	if energy_module:
		var energy := energy_module.find_child("EnergyValue", true, false) as Label
		check(energy != null, "Energy value label exists")
		if energy:
			check(energy.text == str(battle.energy), "Energy text matches combat state")
			check_bounds(energy, viewport, "Energy value")

func exercise_hud(dimensions: Vector2i) -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = dimensions
	var battle := await configure_battle()
	var hotfix := add_card(battle, "hotfix")
	game.render()
	await settle()
	check_status(battle, dimensions, "Initial")

	# Real RunState action: Hotfix gains 6 Block and triggers Firewall for 8 more.
	game.run.play(int(hotfix.id))
	await settle()
	check(battle.block == 14 and battle.energy == 0 and battle.debt == 1, "Firewall fixture resolved through the combat API")
	check_status(battle, dimensions, "After Firewall card")

	# Real RunState end turn: 14 Block absorbs part of the 20-point hit, then resets.
	game.run.end_turn()
	await settle()
	check(battle.hp == game.run.max_hp - 6 and battle.block == 0 and battle.energy == 2 and battle.debt == 0, "End turn applies damage, clears Block, and consumes debt")
	check_status(battle, dimensions, "After end turn")

	# A second real play exercises the Energy reward and enemy Strength risk together.
	battle.hand.clear()
	battle.discard.clear()
	battle.bug = "overflow"
	battle.energy = 1
	var strike := add_card(battle, "strike")
	game.render()
	await settle()
	game.run.play(int(strike.id))
	await settle()
	check(battle.energy == 1 and battle.strength == 1, "Overflow fixture grants Energy and increases enemy Strength through the combat API")
	check_status(battle, dimensions, "After Overflow card")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for dimensions in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		await exercise_hud(dimensions)
	game.queue_free()
	print("BUGBOUND STATUS HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree
## Focused Phase 4 card interaction coverage.

var game: Control
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for _i in range(4): await process_frame

func card_views() -> Array[Button]:
	var result: Array[Button] = []
	var script := load("res://ui/card_view.gd")
	for node in game.find_children("*", "Button", true, false):
		if node.get_script() == script: result.append(node)
	return result

func card_for_view(view: Button) -> Dictionary:
	var name_label := view.get_node_or_null("Margin/Body/Name") as Label
	if name_label == null: return {}
	for card in game.run.battle.hand:
		if name_label.text == game.localize(card.name): return card
	return {}

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = code
	release.pressed = false
	Input.parse_input_event(release)
	await settle()

func build_battle() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.run.start("PHASE4-CARDS")
	game.run.enter("t0l0")
	game.run.battle.enemy_hp = 999
	game.run.battle.popup_resolved = true
	game.render()
	await settle()

func check_number_selection_and_play() -> void:
	var battle: Combat = game.run.battle
	var views := card_views()
	check(views.size() >= 2, "Battle renders at least two cards")
	if views.size() < 2: return
	var target := card_for_view(views[0])
	var target_id: int = target.id
	var before_hand := battle.hand.size()
	var before_discard := battle.discard.size()
	var before_energy := battle.energy
	await key(KEY_1)
	check(views[0].has_focus(), "Number shortcut focuses the first card")
	await key(KEY_ENTER)
	check(not battle.hand.any(func(card): return int(card.id) == target_id), "Enter plays the focused card")
	check(battle.hand.size() == before_hand - 1, "Playing a card removes it from hand")
	check(battle.discard.size() == before_discard + (0 if target.get("exhausted", false) or target.key == "sting" else 1), "Playing a normal card updates discard")
	check(battle.energy == before_energy - int(target.cost) + int(target.get("energy", 0)), "Playing a card updates energy")

func check_unplayable_focus_explains() -> void:
	var battle: Combat = game.run.battle
	battle.energy = 0
	game.render()
	await settle()
	var disabled: Button
	for view in card_views():
		if view.disabled:
			disabled = view
			break
	check(disabled != null, "An unaffordable card is rendered disabled")
	if disabled == null: return
	var before_hand := battle.hand.size()
	disabled.grab_focus()
	await process_frame
	var preview := game.find_child("CardPreview", true, false) as Label
	check(disabled.has_focus(), "Unplayable card remains keyboard focusable")
	check(preview != null and preview.text.contains(game.localize("Not enough energy")), "Focused unplayable card explains why it cannot play")
	await key(KEY_ENTER)
	check(battle.hand.size() == before_hand, "Enter does not play an unplayable card")

func check_end_turn_piles_and_energy() -> void:
	var battle: Combat = game.run.battle
	battle.energy = 1
	battle.deck.clear()
	for index in range(8):
		var card: Dictionary = Catalog.card("strike")
		card.id = 50000 + index
		battle.deck.append(card)
	var before_hand := battle.hand.size()
	var before_discard := battle.discard.size()
	var before_turn := battle.turn
	var expected_energy := battle.next_turn_energy()
	await key(KEY_E)
	check(battle.turn == before_turn + 1, "E advances the turn")
	check(battle.hand.size() == 5, "End turn draws a fresh five-card hand")
	check(battle.discard.size() == before_discard + before_hand, "End turn discards the previous hand")
	check(battle.energy == expected_energy, "End turn resets energy from next-turn calculation")

func check_long_hand_scroll() -> void:
	var battle: Combat = game.run.battle
	battle.hand.clear()
	for index in range(20):
		var card: Dictionary = Catalog.data.cards[index % Catalog.data.cards.size()].duplicate(true)
		card.id = 60000 + index
		battle.hand.append(card)
	game.render()
	await settle()
	var scroll := game.find_child("CombatHand", true, false) as ScrollContainer
	check(scroll != null, "Long hand uses a scroll container")
	if scroll == null: return
	check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"Long hand scrolls horizontally")
	check(scroll.get_h_scroll_bar().max_value > scroll.get_h_scroll_bar().page,
		"Long hand exposes content beyond the viewport")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await build_battle()
	await check_number_selection_and_play()
	await check_unplayable_focus_explains()
	await check_end_turn_piles_and_energy()
	await check_long_hand_scroll()
	game.queue_free()
	print("BUGBOUND PHASE4 CARDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

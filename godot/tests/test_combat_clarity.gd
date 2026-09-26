extends SceneTree
## Focused interaction and layout coverage for the combat clarity preview.

var game: Control
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for _i in range(4): await process_frame

func card_buttons() -> Array[Button]:
	var cards: Array[Button] = []
	for node in game.find_children("*", "Button", true, false):
		if node.get_script() == load("res://ui/card_view.gd"):
			cards.append(node)
	return cards

func preview_label() -> Label:
	return game.find_child("CardPreview", true, false) as Label

func card_for_view(view: Button) -> Dictionary:
	var name_label := view.get_node_or_null("Margin/Body/Name") as Label
	if name_label == null: return {}
	for card in game.run.battle.hand:
		if name_label.text == game.localize(card.name):
			return card
	return {}

func hover(view: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * view.get_global_rect().get_center()
	event.global_position = event.position
	Input.parse_input_event(event)
	await settle()

func move_pointer_outside(view: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(2, 2)
	event.global_position = event.position
	Input.parse_input_event(event)
	await process_frame

func visible_hand() -> void:
	var scroll := game.find_child("CombatHand", true, false) as ScrollContainer
	check(scroll != null, "Combat hand uses a scroll container")
	if scroll == null: return
	var viewport := scroll.get_global_rect()
	for view in card_buttons():
		var body := view.get_node_or_null("Margin/Body") as Control
		check(body != null and body.get_global_rect().position.y >= viewport.position.y and body.get_global_rect().end.y <= viewport.end.y, "Long-hand card remains vertically visible")
	check(scroll.get_h_scroll_bar().max_value > scroll.get_h_scroll_bar().page, "Long hand remains horizontally scrollable")

func set_battle(locale: String, size: Vector2i) -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = size
	game.build_matcher()
	game.run.start("COMBAT-CLARITY-SEED")
	game.run.enter("t0l0")
	game.run.battle.enemy_hp = 999
	game.render()
	await settle()

func check_preview_interactions() -> void:
	var cards := card_buttons()
	check(cards.size() >= 2, "Seeded battle supplies cards for preview interaction")
	if cards.size() < 2: return
	var preview := preview_label()
	check(preview != null, "Combat preview label is present")
	if preview == null: return
	var stable_bounds := preview.get_global_rect()
	var first := cards[0]
	var second := cards[1]
	first.grab_focus()
	await process_frame
	check(first.has_focus() and preview.text.contains(game.localize(card_for_view(first).name)), "CardPreview updates from keyboard focus")
	var focused_text := preview.text
	await move_pointer_outside(first)
	check(first.has_focus() and preview.text == focused_text, "CardPreview remains while its focused card loses pointer hover")
	await hover(second)
	check(preview.text.contains(game.localize(card_for_view(second).name)), "CardPreview updates from mouse hover")
	check(preview.get_global_rect().is_equal_approx(stable_bounds), "Preview area bounds remain stable while content changes")
	await move_pointer_outside(second)
	first.release_focus()
	await process_frame
	check(preview.text == game.localize("1–0 select · Enter play · E end turn · D deck · A draw · S discard · M map"), "CardPreview clears after focus exit")
	game.render()
	await settle()
	check(preview_label().text == game.localize("1–0 select · Enter play · E end turn · D deck · A draw · S discard · M map"), "CardPreview clears after combat state rebuild")
	var b = game.run.battle
	b.bug = "firewall"
	b.energy = 3
	var guard := Catalog.card("guard")
	guard.id = 9400
	b.hand.append(guard)
	game.render()
	await settle()
	var trigger_view: Button
	for view in card_buttons():
		if card_for_view(view).key == "guard":
			trigger_view = view
			break
	check(trigger_view != null, "Bug-trigger card is rendered")
	if trigger_view:
		trigger_view.grab_focus()
		await process_frame
		var prediction: Dictionary = b.preview_card(card_for_view(trigger_view))
		check(preview_label().text.contains(game.localize("GAIN")) and preview_label().text.contains(game.localize("COST")) and preview_label().text.contains(game.localize("Next turn: %d Energy") % prediction.next_turn_energy), "Focused bug-trigger preview shows reward, cost, and next-turn Energy")

func check_preview_rules() -> void:
	var b: Combat = game.run.battle
	var card: Dictionary = b.hand[0]
	var rng_state: int = b.run.rng.state
	var rng_calls: int = b.run.rng.calls
	var state := {"energy": b.energy, "hp": b.hp, "debt": b.debt, "bank": b.bee.bank, "deck": b.deck.size(), "hand": b.hand.size(), "discard": b.discard.size(), "bug": b.bug}
	b.preview_card(card)
	check(rng_state == b.run.rng.state and rng_calls == b.run.rng.calls and state == {"energy": b.energy, "hp": b.hp, "debt": b.debt, "bank": b.bee.bank, "deck": b.deck.size(), "hand": b.hand.size(), "discard": b.discard.size(), "bug": b.bug}, "Preview does not mutate combat state or RNG")
	b.debt = 5
	b.bee.bank = 4
	game.render()
	await settle()
	var next_energy := game.find_child("NextTurnEnergy", true, false) as Label
	check(next_energy != null and next_energy.text.contains(str(b.next_turn_energy())), "Next-turn Energy UI agrees with core debt and bank rules")
	b.energy = 0
	game.render()
	await settle()
	var disabled := card_buttons().filter(func(view): return view.disabled)
	check(not disabled.is_empty(), "Unaffordable cards are disabled")
	if not disabled.is_empty():
		var disabled_card := card_for_view(disabled[0])
		disabled[0].grab_focus()
		await process_frame
		check(disabled[0].has_focus() and preview_label().text.contains(game.localize("Not enough energy")), "Disabled card keyboard focus explains its energy requirement")
		await hover(disabled[0])
		check(preview_label().text.contains(game.localize(disabled_card.name)) and preview_label().text.contains(game.localize("Not enough energy")), "Disabled card pointer hover explains its energy requirement")

func check_nectar_help() -> void:
	var nectar: Label
	for node in game.find_children("*", "Label", true, false):
		if node.tooltip_text == game.localize("Nectar lasts this battle. It strengthens Nectar Lance and Wax Wall. Swarm Loop spends it for damage; Royal Jelly spends 2 to reduce another card's cost.") and node.focus_mode == Control.FOCUS_ALL:
			nectar = node
			break
	check(nectar != null, "Nectar status is keyboard focusable")
	if nectar:
		nectar.grab_focus()
		await process_frame
		check(nectar.has_focus() and preview_label().text == nectar.tooltip_text, "Nectar keyboard focus explains its battle effect")

func check_long_hand() -> void:
	var b: Combat = game.run.battle
	b.hand.clear()
	for index in range(20):
		var card: Dictionary = Catalog.data.cards[index % Catalog.data.cards.size()].duplicate(true)
		card.id = 10000 + index
		b.hand.append(card)
	game.render()
	await settle()
	visible_hand()

func compact_battle(enemy_key: String, bug_key: String, locale: String) -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game.build_matcher()
	game.run.start("COMPACT-CLARITY-SEED")
	game.run.screen = "battle"
	game.run.battle = Combat.new(game.run, enemy_key)
	var b: Combat = game.run.battle
	b.enemy_hp = Catalog.data.enemies[enemy_key].hp
	b.bug = bug_key
	b.hand.clear()
	b.deck.clear()
	b.discard.clear()
	b.energy = 1 if bug_key == "overflow" else 3
	b.progress = 1 if bug_key == "hotPath" else (2 if bug_key == "loop" else 0)
	for index in range(5):
		var card: Dictionary = Catalog.card(["strike", "hotfix", "duck", "guard", "nectar"][index])
		card.id = 20000 + index
		b.hand.append(card)
	game.render()
	await settle()

func check_compact_enemy_bug_matrix() -> void:
	for locale in ["zh"]:
		for enemy_key in Catalog.data.enemies.keys():
			for bug_key in Catalog.BUG_KEYS:
				await compact_battle(enemy_key, bug_key, locale)
				var representative: bool = (enemy_key == "folder" and bug_key == "firewall") or (enemy_key == "antivirus" and bug_key == "loop")
				check(game.content.get_global_rect().end.y <= root.size.y - 16, "Compact combat content fits viewport: %s %s %s" % [locale, enemy_key, bug_key])
				var triggered: Button
				for view in card_buttons():
					var card := card_for_view(view)
					if game.run.battle.preview_card(card).triggers_bug:
						triggered = view
						break
				check(triggered != null, "Representative hand contains a bug trigger: %s" % bug_key)
				if triggered:
					var preview := preview_label()
					var bounds := preview.get_global_rect()
					triggered.grab_focus()
					await process_frame
					if representative and "--capture" in OS.get_cmdline_user_args():
						await RenderingServer.frame_post_draw
						var path := ProjectSettings.globalize_path("res://../work/clarity-%s-%s-%s.png" % [locale, enemy_key, bug_key])
						root.get_texture().get_image().save_png(path)
						print("CLARITY COMPACT %s %s %s: content=%s viewport=%s preview-before=%s preview-after=%s text=%s capture=%s" % [locale, enemy_key, bug_key, game.content.get_global_rect(), Rect2(Vector2.ZERO, Vector2(root.size)), bounds, preview.get_global_rect(), preview.text, path])
					check(preview.text.contains(game.localize("Next turn: %d Energy") % game.run.battle.preview_card(card_for_view(triggered)).next_turn_energy) and preview.get_global_rect().is_equal_approx(bounds), "Bug preview stays compact and stable: %s %s %s" % [locale, enemy_key, bug_key])

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for dimensions in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for locale in ["zh"]:
			await set_battle(locale, dimensions)
			await check_preview_interactions()
			await check_preview_rules()
			await check_nectar_help()
			await check_long_hand()
	await check_compact_enemy_bug_matrix()
	game.queue_free()
	print("BUGBOUND COMBAT CLARITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

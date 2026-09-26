extends SceneTree
## UI flow check; a graphical run also saves screenshots into the ignored work folder.
var game: Control
var capture := false
var failures := 0

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if capture: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../work"))
	_run.call_deferred()

func settle() -> void:
	for i in range(5): await process_frame
	await create_timer(0.25).timeout

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func snapshot(name_: String) -> void:
	await settle()
	if name_ == "reward":
		for i in range(180):
			if game.content.visible: break
			await create_timer(0.01).timeout
		await settle()
		check(game.content.visible, "Reward appears after combat effects finish")
		check(game.game_feel.effects_root.get_child_count() == 0, "Reward content has no overlapping combat effects")
	if capture:
		await RenderingServer.frame_post_draw
		var target := ProjectSettings.globalize_path("res://../work/ui-" + name_ + ".png")
		check(root.get_texture().get_image().save_png(target) == OK, "Screenshot saved: " + name_)

func buttons(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is Button: result.append(child)
		result.append_array(buttons(child))
	return result

func check_card_bounds() -> void:
	for item in buttons(game):
		if item.get_script() != load("res://ui/card_view.gd"): continue
		var body = item.get_node("Margin/Body")
		check(body.get_global_rect().end.y <= item.get_global_rect().end.y + 1, "Card text fits: " + item.get_node("Margin/Body/Name").text)

func check_combat_matrix_layout() -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	var card_count := 0
	var end_turn_found := false
	for item in buttons(game):
		if item.get_script() == load("res://ui/card_view.gd"):
			card_count += 1
			var body := item.get_node_or_null("Margin/Body") as Control
			check(body != null, "Combat card has a body")
			if body:
				check(body.get_global_rect().size.x > 0 and body.get_global_rect().size.y > 0, "Combat card body is visible")
				# Extra draws may scroll horizontally; vertical clipping is never intended.
				check(body.get_global_rect().position.y >= 0 and body.get_global_rect().end.y <= viewport.end.y, "Combat card body fits viewport height")
				check(item.get_global_rect().encloses(body.get_global_rect()), "Combat card text fits its paper")
				if card_count <= 5: check(viewport.encloses(item.get_global_rect()), "Opening hand card fits viewport")
		if item.text == game.localize("END TURN  [E]"):
			end_turn_found = true
			check(viewport.encloses(item.get_global_rect()), "END TURN is within viewport")
	check(card_count > 0, "Combat hand has cards")
	check(end_turn_found, "Combat screen has END TURN")
	var hint := game.find_child("CombatHint", true, false) as Label
	check(hint != null and hint.size.y >= 20 and hint.size.x >= 120, "Combat action hint has readable space")

func combat_matrix_capture(dimensions: Vector2i, locale: String) -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = dimensions
	await settle()
	game.language = locale
	game.build_matcher()
	game.run.start("BUG-404-LOL")
	game.run.enter("t0l0")
	game.render()
	await settle()
	check(root.size == dimensions, "Capture viewport is exact: %s" % dimensions)
	check_combat_matrix_layout()
	await snapshot("combat-%d-%s" % [dimensions.x, locale])

func experience_flow() -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for locale in ["en", "zh"]:
			root.size = dimensions
			await settle()
			game.language = locale
			game.build_matcher()
			game.run.start("BUG-404-LOL")
			await settle()
			check(game.content.get_global_rect().end.y <= dimensions.y - 24, "Map and route context fit viewport: %s %s" % [dimensions, locale])
			for route in buttons(game).filter(func(item): return item.tooltip_text.begins_with("C:")):
				var body: Control = route.get_child(0)
				check(body.get_child(1).size.y > 0 and body.get_child(2).size.y > 0, "Route title and trait have visible space")
				check(body.get_child(3).get_global_rect().end.y <= route.get_global_rect().end.y, "Route details fit node")
			await snapshot("map-%d-%s" % [dimensions.x, locale])
	game.language = "en"
	game.build_matcher()
	game.guidance_dismissed = false
	game.run.enter("t0l0")
	game.run.battle.bug = "firewall"
	game.render()
	await settle()
	check(game.find_child("FirstBattleGuide", true, false) != null, "First battle has contextual guidance")
	var marked := buttons(game).filter(func(item): return item.get_script() == load("res://ui/card_view.gd") and item.get_node("Margin/Body/LockNotice").text == "TRIGGERS BUG")
	check(not marked.is_empty(), "Playable trigger cards are visibly marked")
	if not marked.is_empty():
		marked[0].grab_focus()
		check(marked[0].tooltip_text.contains("REWARD") and marked[0].tooltip_text.contains("RISK"), "Trigger preview explains reward and risk")
		await snapshot("experience-trigger")
		await click_control(marked[0])
		await settle()
		check(game.bug_lesson.contains("Reward and risk applied"), "First trigger is acknowledged")
		var incoming: Label = game.find_child("IncomingDamage", true, false)
		check(incoming.text == "After Block: %d damage" % game.run.battle.incoming_damage(), "Incoming preview updates after playing Block")
	await press_text("×")
	check(game.find_child("FirstBattleGuide", true, false) == null, "Guidance can be dismissed")
	game.run.abandon()

func combat_states_capture() -> void:
	await combat_matrix_capture(Vector2i(1280, 720), "en")
	var hand := buttons(game).filter(func(item): return item.get_script() == load("res://ui/card_view.gd"))
	hand[0].grab_focus()
	await snapshot("combat-focus")
	check(hand[0].has_focus(), "Card receives keyboard focus")
	hand[0].release_focus()
	var point: Vector2 = hand[1].get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await snapshot("combat-hover")
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	await snapshot("combat-pressed")
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await settle()
	game.run.battle.energy = 0
	game.render()
	await settle()
	check_combat_matrix_layout()
	await snapshot("combat-disabled")
	for item in buttons(game):
		if item.get_script() == load("res://ui/card_view.gd"):
			check(item.disabled, "Unaffordable card is disabled")
			check(item.get_node("Margin/Body/LockNotice").visible, "Disabled card explains its requirement")
	game.language = "zh"
	game.build_matcher()
	game.render()
	await settle()
	check_combat_matrix_layout()
	await snapshot("combat-disabled-zh")
	# Reward cards have longer effects than the starting hand; check compact text too.
	for locale in ["en", "zh"]:
		game.language = locale
		game.build_matcher()
		for start in range(0, Catalog.data.cards.size(), 5):
			game.run.battle.hand.clear()
			for index in range(start, mini(start + 5, Catalog.data.cards.size())):
				var card: Dictionary = Catalog.data.cards[index].duplicate(true)
				card.id = 1000 + index
				game.run.battle.hand.append(card)
			game.render()
			await settle()
			check_combat_matrix_layout()
			check_card_bounds()
		await snapshot("combat-long-cards-" + locale)

func click_control(item: Control) -> void:
	var point := item.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func press_text(part: String) -> void:
	for item in buttons(game):
		if part in item.text and not item.disabled:
			await click_control(item)
			await settle()
			return
	check(false, "Missing button: " + part)

func press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame

func named(name_: String) -> Control:
	return game.find_child(name_, true, false) as Control

func menu_button(name_: String) -> Button:
	var item := named(name_)
	check(item is Button, "Menu control exists: " + name_)
	return item as Button

func menu_preview_checks(keys: Array) -> void:
	for key in keys:
		var item := named("Signature_" + key)
		check(item != null, "Preview exists: " + key)
		if not item: continue
		var card := Catalog.card(key)
		check(item.get_meta("card_key") == key, "Preview card key: " + key)
		check(item.inspection_mode and not item.disabled, "Preview is focusable inspection: " + key)
		check(not item.get_node("Margin/Body/LockNotice").visible, "Inspection has no requirements warning")
		check(item.get_node("Margin/Body/Name").text == game.localize(card.name), "Preview name matches catalog")
		check(item.get_node("Margin/Body/Effect").text == game.localize(Catalog.describe(card)), "Preview rules match catalog")
		check(item.get_node("Margin/Body/Top/Cost/Value").text == str(int(card.cost)), "Preview cost matches catalog")
		check(item.get_node("Margin/Body/ArtFrame/Art").texture != null, "Preview uses card art")
	check_card_bounds()

func spider_translation_checks() -> void:
	var ui_translations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_translations.json"))
	var spider_copy := [
		"Spider Debugger",
		"Capture triggered Bugs in a 2-slot Web, then release them as commands.",
		"Web Trap",
		"Gain 5 Block. The next Bug you trigger fills your Web with two copies of it.",
		"Inject",
		"Deal 6 damage. If your Web holds a Bug, consume the oldest one and deal 8 extra damage.",
		"Breakpoint",
		"The next Bug you trigger ignores its Risk and is still captured. Exhaust.",
		"Stack Overflow",
		"Deal 7 damage per captured Bug, then clear your Web.",
		"Release Candidate",
		"Release the oldest captured Bug as a command. Its stored reward resolves again without its Risk.",
		"WEB",
		"Captured",
		"empty",
		"Triggered Bugs are captured in your 2-slot Web. Spider cards can consume or release them.",
		"Web Trap armed",
		"Breakpoint armed",
		"Web is empty",
		"WEB RELEASE",
	]
	for source in spider_copy:
		check(ui_translations.has(source) and game.localize(source) == ui_translations[source], "Chinese Spider translation: " + source)

func menu_layout_checks() -> void:
	var content_bottom: float = game.content.get_global_rect().end.y
	check(content_bottom <= root.size.y - 24, "Menu fits viewport: %s %s (bottom %.1f, limit %d)" % [root.size, game.language, content_bottom, root.size.y - 24])
	for build in Catalog.LOADOUTS:
		var choice := named("Build_" + build)
		var copy := choice.get_child(0).get_child(0)
		for child in copy.get_children():
			check(choice.get_global_rect().encloses(child.get_global_rect()), "Build text fits: " + build)
	menu_preview_checks(game.MENU_SIGNATURES[game.selected_loadout])

func check_starting_deck() -> void:
	var counts := {}
	for key in Catalog.LOADOUTS[game.selected_loadout].cards: counts[key] = counts.get(key, 0) + 1
	var found := 0
	for item in buttons(game.overlay):
		if not item.has_meta("card_key"): continue
		found += 1
		var key: String = item.get_meta("card_key")
		check(counts.has(key), "Deck dialog only includes starting cards")
		check(item.get_meta("copy_count") == counts.get(key, 0), "Deck duplicate count matches catalog")
		check(item.inspection_mode, "Deck cards are inspection-only")
	check(found == counts.size(), "Dialog shows every unique starting card")

func menu_flow() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game.language = "zh"
	game.build_matcher()
	game.render()
	await settle()
	check(game.selected_loadout == "balanced", "Balanced build is selected by default")
	check(game.menu_seed_text == "BUG-404-LOL", "Default seed")
	check(not game.menu_seed_expanded and named("MenuSeed") == null and named("SeedLaunch") == null, "Seed controls start collapsed")
	menu_layout_checks()
	spider_translation_checks()
	await snapshot("menu-first-zh")
	# All selections use real pointer input; inspecting never mutates the current run.
	game.run.start("MENU-PREVIEW-CHECK")
	game.run.abandon()
	await settle()
	var rng_calls: int = game.run.rng.calls
	var saved_cards: String = JSON.stringify(game.run.cards)
	for build in Catalog.LOADOUTS:
		await click_control(menu_button("Build_" + build))
		await settle()
		check(game.selected_loadout == build, "Build selection updates: " + build)
		check(menu_button("Build_" + build).has_focus(), "Selected build restores focus")
		menu_preview_checks(game.MENU_SIGNATURES[build])
		if capture and build == "spider": await snapshot("menu-spider-1280-zh")
		var preview := named("Signature_" + game.MENU_SIGNATURES[build][0])
		await click_control(preview)
		preview.grab_focus()
		await press_key(KEY_ENTER)
		check(game.run.screen == "menu" and game.run.rng.calls == rng_calls and JSON.stringify(game.run.cards) == saved_cards, "Preview leaves run and RNG untouched")
		await click_control(named("StartingDeck"))
		await settle()
		check_starting_deck()
		await click_control(named("CloseStartingDeck"))
		await settle()
		check(not is_instance_valid(game.overlay) and named("StartingDeck").has_focus(), "Close restores deck opener focus")
		await click_control(named("StartingDeck"))
		await settle()
		await press_key(KEY_ESCAPE)
		await settle()
		check(not is_instance_valid(game.overlay) and named("StartingDeck").has_focus(), "Escape restores deck opener focus")
	# Real text input and viewport rebuilds must preserve menu choices.
	await click_control(menu_button("Build_overdrive"))
	await settle()
	await click_control(named("SeedDisclosure"))
	await settle()
	var seed_input := named("MenuSeed") as LineEdit
	seed_input.grab_focus()
	seed_input.select_all()
	for character in "MENU-TEST-001":
		var typed := InputEventKey.new()
		typed.unicode = character.unicode_at(0)
		typed.pressed = true
		Input.parse_input_event(typed)
		await process_frame
	await settle()
	check(game.menu_seed_text == "MENU-TEST-001", "Text input updates stored seed")
	root.size = Vector2i(1440, 900)
	await settle()
	check(game.selected_loadout == "overdrive" and game.menu_seed_expanded and named("MenuSeed").text == "MENU-TEST-001", "Resize retains menu state")
	await click_control(named("SeedLaunch"))
	await settle()
	check(game.run.screen == "map" and game.run.loadout_key == "overdrive" and game.run.rng.seed_text == "MENU-TEST-001", "Seed launch uses entered seed and build")
	var actual: Array = []
	for card in game.run.cards: actual.append(card.key)
	check(actual == Catalog.LOADOUTS.overdrive.cards, "Seeded launch uses complete selected deck")
	game.run.abandon()
	await settle()
	await click_control(named("StartAdventure"))
	await settle()
	check(game.run.screen == "map" and game.run.loadout_key == "overdrive" and game.run.rng.seed_text != "MENU-TEST-001", "Random launch uses selected build and fresh seed")
	game.run.abandon()
	# Capture default, longest-copy build, expanded seed, and deck dialog at native sizes.
	for dimensions in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for locale in ["zh", "en"]:
			root.size = dimensions
			game.language = locale
			game.build_matcher()
			game.selected_loadout = "balanced"
			game.menu_seed_expanded = false
			game.render()
			await settle()
			menu_layout_checks()
			await snapshot("menu-%d-%s" % [dimensions.x, locale])
			await click_control(named("Build_nectar"))
			await settle()
			menu_layout_checks()
			await snapshot("menu-nectar-%d-%s" % [dimensions.x, locale])
			await click_control(named("SeedDisclosure"))
			await settle()
			menu_layout_checks()
			await snapshot("menu-seed-%d-%s" % [dimensions.x, locale])
			await click_control(named("StartingDeck"))
			await settle()
			check_starting_deck()
			check_card_bounds()
			await snapshot("menu-deck-%d-%s" % [dimensions.x, locale])
			await press_key(KEY_ESCAPE)
			await settle()
	game.language = "en"
	game.build_matcher()
	game.selected_loadout = "balanced"
	game.menu_seed_text = "BUG-404-LOL"
	game.menu_seed_expanded = true
	game.render()
	await settle()

func _run() -> void:
	if "--experience-only" in OS.get_cmdline_user_args():
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await experience_flow()
		print("BUGBOUND EXPERIENCE UI: %d failures" % failures)
		quit(1 if failures else 0)
		return
	if "--menu-only" in OS.get_cmdline_user_args():
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await menu_flow()
		print("BUGBOUND MENU: %d failures" % failures)
		quit(1 if failures else 0)
		return
	if "--combat-only" in OS.get_cmdline_user_args():
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		for dimensions in [Vector2i(1280, 720), Vector2i(1440, 900)]:
			for locale in ["en", "zh"]: await combat_matrix_capture(dimensions, locale)
		if "--states" in OS.get_cmdline_user_args(): await combat_states_capture()
		print("BUGBOUND COMBAT: %d failures" % failures)
		quit(1 if failures else 0)
		return
	root.size = Vector2i(1440, 900)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	check(game.language == "zh", "Chinese is the player-facing default language")
	check(buttons(game).all(func(item): return item.text != "中文 / EN"), "Language switch is hidden")
	game.language = "en"
	game.build_matcher()
	game.render()
	await menu_flow()
	game.render()
	await snapshot("menu")
	await press_text("BOOT →")
	check(game.run.screen == "map", "Seed button starts run")
	await snapshot("map")
	# Route buttons carry location paths in their tooltips.
	for item in buttons(game):
		if item.tooltip_text.begins_with("C:") and not item.disabled:
			await click_control(item)
			break
	await snapshot("battle")
	check(game.run.screen == "battle", "Route button starts battle")
	for item in buttons(game):
		if item.get_script() == load("res://ui/card_view.gd") and not item.disabled:
			await click_control(item)
			break
	await settle()
	check(not game.feedback.is_empty(), "Card button executes a command")
	await press_text("Pause")
	await snapshot("pause")
	await press_text("Resume run")
	game.run.battle.popup_open = true
	game.render()
	await snapshot("popup")
	await press_text("NOT NOW")
	check(not game.run.battle.popup_open, "Popup choice resolves")
	game.run.battle.enemy_hp = 0
	game.run.settle()
	check(not game.content.visible, "Reward content waits for defeat presentation")
	await snapshot("reward")
	await press_text("INSTALL →")
	check(game.run.screen == "map" and game.run.cards.size() == 11, "Reward installs and returns to map")
	game.run.current = {"event": "unknownExe", "id": "test-event", "label": "Unknown.exe"}
	game.run.screen = "event"
	game.render()
	await snapshot("event")
	await press_text("SANDBOX IT")
	check(game.run.screen == "map", "Event choice returns to map")
	game.collection(true)
	await snapshot("library")
	check_card_bounds()
	game.language = "zh"
	game.build_matcher()
	game.run.start("CHINESE-UI")
	game.run.enter("t0l0")
	await snapshot("battle-zh")
	game.collection(true)
	await settle()
	check_card_bounds()
	game.run.abandon()
	await combat_matrix_capture(Vector2i(1280, 720), "en")
	game.run.abandon()
	await combat_matrix_capture(Vector2i(1280, 720), "zh")
	game.run.abandon()
	await combat_matrix_capture(Vector2i(1440, 900), "en")
	game.run.abandon()
	await combat_matrix_capture(Vector2i(1440, 900), "zh")
	await combat_states_capture()
	await experience_flow()
	game.run.abandon()
	game.queue_free()
	await process_frame
	print("BUGBOUND UI: screen flows completed, %d failures" % failures)
	quit(1 if failures else 0)

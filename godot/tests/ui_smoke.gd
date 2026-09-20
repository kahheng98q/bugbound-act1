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
		if item.text == game.localize("END TURN  ↵"):
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

func _run() -> void:
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
	game.language = "en"
	game.build_matcher()
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
	game.run.abandon()
	game.queue_free()
	await process_frame
	print("BUGBOUND UI: screen flows completed, %d failures" % failures)
	quit(1 if failures else 0)

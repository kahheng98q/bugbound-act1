extends SceneTree
## Focused Phase 3 control interaction coverage.

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
	await create_timer(0.25).timeout

func buttons() -> Array[Button]:
	var result: Array[Button] = []
	for node in game.find_children("*", "Button", true, false): result.append(node)
	return result

func find_button(part: String) -> Button:
	var localized: String = game.localize(part)
	for item in buttons():
		if localized in item.text or part in item.text: return item
	return null

func click(item: Control) -> void:
	check(item != null, "Control exists: " + str(item))
	if item == null: return
	var point := item.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func key(code: Key) -> void:
	# Leave hovered overlay cards before a shortcut rebuilds the interface.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	motion.global_position = Vector2.ZERO
	Input.parse_input_event(motion)
	await settle()
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle()

func overlay_has(text: String) -> bool:
	if not is_instance_valid(game.overlay): return false
	var query: String = game.localize(text)
	for node in game.overlay.find_children("*", "Label", true, false):
		if query in (node as Label).text or text in (node as Label).text: return true
	return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.run.start("PHASE3-CONTROLS")
	game.run.enter("t0l0")
	game.run.battle.enemy_hp = 999
	# Keep normal-turn checks independent of the scheduled permission popup.
	game.run.battle.popup_resolved = true
	game.render()
	await settle()
	for action in [["Card Library", "Card Library"], ["Deck ·", "Current deck"], ["Pause  /  Esc", "Run paused"]]:
		await click(find_button(action[0]))
		check(overlay_has(action[1]), "Top action opens: " + action[0])
		await key(KEY_ESCAPE)

	# Pointer controls expose all three piles and the battle log.
	await click(find_button("抽牌"))
	check(overlay_has("抽牌"), "Draw pile opens from pointer control")
	await key(KEY_ESCAPE)
	await click(find_button("弃牌"))
	check(overlay_has("弃牌"), "Discard pile opens from pointer control")
	await key(KEY_ESCAPE)
	await click(find_button("消耗"))
	check(overlay_has("消耗"), "Exhaust pile opens from pointer control")
	await key(KEY_ESCAPE)
	await click(find_button("Battle log"))
	check(overlay_has("Battle log"), "Battle log opens from pointer control")
	await key(KEY_ESCAPE)
	var prior_turn: int = game.run.battle.turn
	await click(find_button("END TURN"))
	check(game.run.battle.turn == prior_turn + 1, "End turn runs from pointer control")
	await create_timer(1.0).timeout

	# Keyboard shortcuts open deck, draw, and discard overlays.
	await key(KEY_D)
	check(is_instance_valid(game.overlay), "D opens the current deck")
	await key(KEY_ESCAPE)
	await key(KEY_A)
	check(is_instance_valid(game.overlay), "A opens draw pile")
	await key(KEY_ESCAPE)
	await key(KEY_S)
	check(is_instance_valid(game.overlay), "S opens discard pile")
	await key(KEY_ESCAPE)

	# E ends a normal turn; the resulting energy reset proves the callback ran.
	game.run.battle.energy = 0
	prior_turn = game.run.battle.turn
	game.render()
	await settle()
	await key(KEY_E)
	check(game.run.battle.energy == 3 and game.run.battle.turn == prior_turn + 1, "E ends the turn")
	await create_timer(1.0).timeout

	# End turn is disabled while a popup or card choice is active.
	game.run.battle.popup_open = true
	game.render()
	await settle()
	var end_turn := find_button("END TURN")
	check(end_turn != null and end_turn.disabled, "End turn disabled during popup")
	prior_turn = game.run.battle.turn
	await click(end_turn)
	await key(KEY_E)
	check(game.run.battle.popup_open and game.run.battle.turn == prior_turn, "Disabled end turn does not resolve popup or advance turn")
	game.run.battle.popup_open = false
	var choice_card: Dictionary = Catalog.card("strike")
	choice_card.id = game.run.serial
	game.run.battle.choice = {"kind": "draw", "cards": [choice_card], "drawn": []}
	game.render()
	await settle()
	end_turn = find_button("END TURN")
	check(end_turn != null and end_turn.disabled, "End turn disabled during card choice")
	await click(end_turn)
	await key(KEY_E)
	check(not game.run.battle.choice.is_empty() and game.run.battle.turn == prior_turn, "Disabled end turn does not dismiss card choice or advance turn")

	print("BUGBOUND PHASE3 CONTROLS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

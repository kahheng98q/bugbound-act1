extends SceneTree
## Lifecycle, input, and gameplay parity tests for the presentation layer.
var checks := 0
var failures := 0
var impacts := 0
var game: Control
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func settle(seconds := 0.25) -> void:
	for i in range(3): await process_frame
	await create_timer(seconds).timeout

func screenshot(name_: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../work/feel-" + name_ + ".png")) == OK, "Saved " + name_)

func impact() -> void:
	impacts += 1

func move_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)

func state(run: RunState) -> Array:
	var result := [run.screen, run.hp, run.serial, run.rng.calls, run.rng.state,
		run.battles_won, run.bugs_triggered, run.completed.duplicate(), run.rewards.duplicate(true)]
	if run.battle:
		var b := run.battle
		result.append([b.enemy_hp, b.enemy_shield, b.hp, b.block, b.energy, b.turn,
			b.bug, b.progress, b.triggers, b.debt, b.strength, b.threat, b.attacks,
			b.hand.duplicate(true), b.deck.duplicate(true), b.discard.duplicate(true),
			b.choice.duplicate(true), b.popup_open, b.popup_resolved, b.bee.duplicate(true), b.log.duplicate()])
	return result

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	bee_frames()
	await service_lifecycle()
	await ui_integration()
	print("BUGBOUND GAME FEEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func bee_frames() -> void:
	var bee = load("res://ui/bee_portrait.gd").new()
	var source: Image = bee.SHEET.get_image()
	check(source.get_pixel(0, 0).a == 0.0, "Bee artwork has native transparency")
	var previous := PackedByteArray()
	for index in range(16):
		bee.restore_pose(Vector2((index + 0.1) * bee.IDLE_FRAME_SECONDS, -1.0) if index < 8 else Vector2(0.0, (index - 8 + 0.1) * bee.ATTACK_FRAME_SECONDS))
		check(bee.frame_index == index, "Animation selects frame %d" % index)
		var pixels := source.get_region(Rect2i(bee.atlas.region)).get_data()
		check(pixels != previous, "Frame %d contains distinct artwork" % index)
		previous = pixels
	bee.attack()
	bee._process(0.3)
	bee.attack()
	check(bee.frame_index == 8, "Rapid attacks restart from wind-up")
	bee._process(0.7)
	check(bee.frame_index < 8, "Attack completion resumes idle frames")
	bee.free()

func service_lifecycle() -> void:
	var host := Control.new()
	root.add_child(host)
	host.theme = Theme.new()
	host.theme.default_font_size = 21
	var feel := GameFeel.new()
	feel.settings = GameFeelSettings.new()
	host.add_child(feel)
	var actor := Button.new()
	actor.position = Vector2(250, 180)
	actor.size = Vector2(140, 100)
	actor.modulate = Color(0.8, 0.9, 1.0, 0.85)
	actor.pressed.connect(impact)
	host.add_child(actor)
	var origin := actor.position
	var color := actor.modulate
	var ghost := feel.snapshot(actor)
	check(ghost.get_script() == null and ghost.get_signal_connection_list("pressed").is_empty(), "Visual copies have no scripts or gameplay connections")
	check(ghost.mouse_filter == Control.MOUSE_FILTER_IGNORE and ghost.focus_mode == Control.FOCUS_NONE, "Copies cannot intercept input")
	check(not ghost.disabled and ghost.theme == host.theme, "Copy retains button state and inherited theme")
	var flight := feel.card_play(ghost, Vector2(500, 260), impact)
	flight.pause()
	flight.custom_step(feel.settings.anticipation_duration + feel.settings.play_duration * 0.25)
	check(impacts == 0, "Impact is not called before arrival")
	var halfway := ghost.get_global_transform() * (ghost.size * 0.5)
	check(halfway.distance_to(Vector2(500, 260)) > 30, "Flight visibly travels toward its target")
	flight.custom_step(feel.settings.play_duration)
	check(impacts == 1, "Impact fires once on arrival")
	check((ghost.get_global_transform() * (ghost.size * 0.5)).distance_to(Vector2(500, 260)) < 0.5, "Card center reaches impact target")
	await settle(0.02)
	check(not is_instance_valid(ghost), "Played visual is cleaned up")
	feel.card_hover(actor, true)
	await settle(0.16)
	check(actor.scale.is_equal_approx(Vector2.ONE * 1.05) and actor.position.is_equal_approx(origin - Vector2(0, 12)), "Hover reaches requested pose")
	feel.card_hover(actor, false)
	feel.card_hover(actor, true)
	feel.card_hover(actor, false)
	await settle(0.16)
	check(actor.position.is_equal_approx(origin) and actor.scale.is_equal_approx(Vector2.ONE), "Rapid hover reversal returns exactly to rest")
	ghost = feel.snapshot(actor)
	var attack := feel.enemy_attack(ghost, Vector2(80, 220), 7, host, actor)
	attack.pause()
	attack.custom_step(feel.settings.enemy_attack_windup_duration)
	check(is_instance_valid(ghost), "Enemy attack survives telegraph phase")
	attack.custom_step(feel.settings.enemy_attack_launch_duration + feel.settings.enemy_attack_flash_duration + feel.settings.enemy_attack_recover_duration * 2.0)
	await settle(0.05)
	check(not is_instance_valid(ghost), "Enemy attack visual cleans up after recovery")
	await settle(0.7)
	check(host.position.is_zero_approx() and actor.modulate.is_equal_approx(color), "Enemy attack restores screen shake and target flash")
	feel.enemy_damage(actor, 8)
	await settle(0.025)
	feel.enemy_damage(actor, 4)
	await settle(0.7)
	check(actor.position.is_equal_approx(origin) and actor.modulate.is_equal_approx(color), "Repeated damage restores position and color")
	feel.screen_shake(actor, 9, 0.1)
	feel.screen_shake(actor, 3, 0.16)
	await settle(0.24)
	check(actor.position.is_equal_approx(origin), "Overlapping shakes do not drift")
	feel.show_system_alert("CRITICAL ERROR", "red", host)
	await settle(0.9)
	check(feel.effects_root.get_child_count() == 0, "System alert cleans up overlay, scanline, and text")
	feel.enemy_damage(actor, 3)
	feel.screen_shake(host, 5, 0.3)
	await process_frame
	feel.clear()
	await settle(0.2)
	check(actor.position.is_equal_approx(origin) and actor.modulate.is_equal_approx(color) and host.position.is_zero_approx(), "Clear cancels flash and shake and restores controls")
	check(feel.effects_root.get_child_count() == 0, "Clear removes transient effects")
	ghost = feel.snapshot(actor)
	feel.card_play(ghost, Vector2.ZERO, impact)
	feel.clear()
	await settle(0.4)
	check(impacts == 1, "Cancelled flight never calls impact")
	ghost = feel.snapshot(actor)
	feel.enemy_damage(ghost, 5)
	ghost.queue_free()
	await settle(0.5)
	feel.settings.death_duration = 0.04
	feel.enemy_death(actor)
	await settle(0.08)
	check(actor.modulate.a < 0.01 and actor.scale.x < 0.1, "Death shrinks and fades the visual")
	feel.settings.play_duration = 0
	feel.settings.anticipation_duration = 0
	ghost = feel.snapshot(actor)
	feel.card_play(ghost, Vector2.ZERO, impact)
	await settle(0.02)
	check(impacts == 2 and not is_instance_valid(ghost), "Zero duration safely completes and cleans up")
	host.queue_free()
	await process_frame

func ui_integration() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.language = "en"
	game.build_matcher()
	game.run.start("BUG-404-LOL")
	game.run.enter("t0l0")
	var expected := RunState.new()
	expected.start("BUG-404-LOL")
	expected.enter("t0l0")
	await settle()
	var bee: Control = game.combat_feedback.player
	var bee_slot: Control = bee.get_parent()
	var bee_origin := bee.position
	var idle_frame: int = bee.frame_index
	var slot_origin := bee_slot.position
	await settle(0.3)
	check(bee.frame_index != idle_frame and bee.frame_index < 8, "Idle advances artwork frames")
	check(bee_slot.position == slot_origin and bee.position == bee_origin, "Idle changes artwork without translating the image")
	var pose := Vector2(bee.idle_time, bee.attack_time)
	game.render()
	check(Vector2(game.combat_feedback.player.idle_time, game.combat_feedback.player.attack_time) == pose, "UI rebuild preserves animation phase")
	# Snapshot the laid-out monitor, not the zero-size controls just rebuilt above.
	await settle()
	var monitor: Control = game.combat_feedback.monitor
	var monitor_copy: Control = game.game_feel.snapshot(monitor)
	await process_frame
	await process_frame
	check(monitor_copy.size.is_equal_approx(monitor.size), "Monitor copy preserves wrapped layout dimensions")
	monitor_copy.queue_free()
	var views: Array = game.combat_feedback.cards.values()
	var card: Control = views[1]
	var slot: Control = card.get_parent()
	move_pointer(slot.get_global_rect().get_center())
	await settle(0.18)
	check(card.scale.is_equal_approx(Vector2.ONE * 1.05), "Real pointer input hovers the card (scale %s, pointer %s, slot %s)" % [card.scale, card.get_global_mouse_position(), slot.get_global_rect()])
	check(slot.position.y == 0 and card.position.y == -12, "Hover leaves hand layout slot stationary")
	var scroll: Control = slot.get_parent().get_parent().get_parent()
	check(scroll.get_global_rect().encloses(card.get_global_rect()), "Lifted card stays inside scroll clip")
	await screenshot("hover-1280-en")
	move_pointer(Vector2(4, 4))
	await settle(0.16)
	check(card.scale.is_equal_approx(Vector2.ONE), "Pointer exit returns card to rest")
	card.grab_focus()
	await settle(0.16)
	check(card.scale.x > 1.04, "Keyboard focus receives hover feedback")
	card.release_focus()
	await settle(0.16)
	var id: int = game.run.battle.hand[1].id
	game.play_card(id)
	expected.play(id)
	check(state(game.run) == state(expected), "Combat resolves immediately before visual impact")
	await settle(0.10)
	check(game.combat_feedback.player.frame_index >= 8, "Attack artwork plays after the UI rebuild")
	await screenshot("card-flight")
	await settle(0.22)
	await screenshot("enemy-damage")
	await settle(0.7)
	check(game.combat_feedback.player.frame_index < 8 and game.combat_feedback.player.attack_time < 0.0, "Bee returns to idle artwork after attacking")
	check(state(game.run) == state(expected), "Finishing effects never changes gameplay or RNG")
	var hp_before_enemy := game.run.battle.hp
	game.end_turn()
	expected.end_turn()
	check(state(game.run) == state(expected), "Enemy attack presentation does not change end-turn rules or RNG")
	await settle(0.16)
	check(game.game_feel.effects_root.get_child_count() > 0, "Enemy attack creates visible transient effects")
	await screenshot("enemy-attack")
	await settle(1.0)
	check(game.run.battle == null or game.run.battle.hp <= hp_before_enemy, "Enemy turn resolves before its presentation finishes")
	# Two rapid actions, including a monitor trigger, must match direct rules exactly.
	for i in range(2):
		var playable: Array = game.run.battle.hand.filter(func(c): return game.run.battle.can_play(c))
		if playable.is_empty(): break
		id = playable[0].id
		game.play_card(id)
		expected.play(id)
		check(state(game.run) == state(expected), "Rapid action %d matches direct rules" % i)
		# A second real click can arrive while the first flight is still running.
		await process_frame
		await process_frame
	await settle(0.34)
	var completion: Array = game.game_feel.effects_root.get_children().filter(func(node): return node is Label and node.text == "BUG COMPLETE!")
	check(completion.size() == 1 and completion[0].modulate.a > 0.5, "Monitor completion text remains readable after impact")
	await screenshot("monitor-completion")
	await settle(1.0)
	check(state(game.run) == state(expected), "Bug reward animation grants no extra reward")
	check(game.game_feel.effects_root.get_child_count() == 0, "Card, damage, and completion effects clean up")
	# Isolate a lethal attack fixture through the same UI action.
	game.run.battle.energy = 10
	game.run.battle.enemy_hp = 1
	game.run.battle.bug = "hotPath"
	game.run.battle.progress = 1
	var lethal: Dictionary = Catalog.data.cards[0].duplicate(true)
	lethal.id = 9001
	game.run.battle.hand = [lethal]
	game.render()
	await settle()
	game.play_card(9001)
	check(game.run.screen == "reward" and game.run.battle == null, "Lethal attack transitions immediately")
	await settle(0.55)
	await screenshot("enemy-death")
	await settle(1.0)
	check(game.game_feel.effects_root.get_child_count() == 0, "Lethal and completion snapshots survive transition then clean up")
	# Leaving while a flight is pending must cancel presentation safely.
	game.run.start("BUG-404-LOL")
	game.run.enter("t0l0")
	await settle()
	game.play_card(game.run.battle.hand[1].id)
	game.run.abandon()
	await settle(1.0)
	check(game.run.screen == "menu" and game.game_feel.effects_root.get_child_count() == 0, "Navigation cancels pending effects without stale callbacks")
	if expected.battle: expected.battle.run = null
	game.queue_free()
	await process_frame

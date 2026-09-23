extends Control
## Presentation only; RunState owns every gameplay action.
const CARD_SCENE = preload("res://scenes/card.tscn")
const ROUTE_BOARD = preload("res://ui/route_board.gd")
const ROUTE_DETAILS = preload("res://ui/route_details.gd")
const PAPER_SHADER = preload("res://ui/paper_cutout.gdshader")
const FEEDBACK = preload("res://ui/combat_feedback.gd")
const BEE_PORTRAIT = preload("res://ui/bee_portrait.gd")
@export var game_feel_settings: GameFeelSettings = preload("res://ui/default_game_feel.tres")
var game_feel := GameFeel.new()
var combat_feedback := FEEDBACK.new()
const INK := Color("101b22")
const SURFACE := Color("182830")
const LINE := Color("30434b")
const TEXT := Color("f0f1e9")
const MUTED := Color("99afb1")
const HONEY := Color("e7b94c")
const MINT := Color("75cbb0")
const CORAL := Color("ee8c77")
var run := RunState.new()
var content: VBoxContainer
var overlay: Control
var language := "en"
var phrases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/translations.json"))
var matcher := RegEx.new()
var translations := {}
var mono := SystemFont.new()
var last_screen := ""
var feedback := ""
var guidance_dismissed := false
var bug_lesson := ""
var route_notice := ""
var selected_loadout := "balanced"

func _ready() -> void:
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		language = config.get_value("ui", "language", "en")
	build_matcher()
	theme = make_theme()
	game_feel.settings = game_feel_settings
	add_child(game_feel)
	combat_feedback.feel = game_feel
	combat_feedback.screen = self
	add_child(combat_feedback)
	run.changed.connect(render)
	resized.connect(func():
		queue_redraw()
		if is_node_ready(): render.call_deferred())
	render()

func _exit_tree() -> void:
	if run.battle: run.battle.run = null

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	for x in range(0, int(size.x), 36):
		for y in range(0, int(size.y), 36): draw_circle(Vector2(x, y), 1, Color(0.4, 0.6, 0.6, 0.09))
	draw_line(Vector2.ZERO, Vector2(size.x, 0), HONEY, 4)

func box(fill: Color, border := LINE, radius := 12, padding := 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 18
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_color("font_pressed_color", "Button", TEXT)
	result.set_color("font_focus_color", "Button", TEXT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fills := {"normal": SURFACE, "hover": Color("30474c"), "pressed": INK, "disabled": Color("152229")}
		result.set_stylebox(state, "Button", box(fills[state], MINT if state == "hover" else LINE, 8, 10))
	var focus := box(Color.TRANSPARENT, HONEY, 8, 0)
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_type_variation("PrimaryAction", "Button")
	for state in ["normal", "hover", "pressed"]:
		var fills := {"normal": HONEY, "hover": Color("f6d786"), "pressed": Color("c99a36")}
		result.set_stylebox(state, "PrimaryAction", box(fills[state], HONEY, 8, 12))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "PrimaryAction", INK)
	var primary_focus := focus.duplicate()
	primary_focus.border_color = TEXT
	result.set_stylebox("focus", "PrimaryAction", primary_focus)
	result.set_type_variation("PaperCard", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fills := {"normal": Color("f1eddc"), "hover": Color("fffbea"), "pressed": Color("e3d8b9"), "disabled": Color("d5d2c5")}
		var card_style := box(fills[state], HONEY if state == "hover" else Color("b4ad94"), 10, 0)
		card_style.set_border_width_all(2 if state == "hover" else 1)
		card_style.shadow_color = Color(0, 0, 0, 0.25)
		card_style.shadow_size = 3
		card_style.shadow_offset = Vector2(0, 3)
		result.set_stylebox(state, "PaperCard", card_style)
	result.set_stylebox("focus", "PaperCard", focus)
	result.set_stylebox("normal", "LineEdit", box(INK, LINE, 8, 14))
	result.set_stylebox("focus", "LineEdit", box(INK, HONEY, 8, 14))
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("caret_color", "LineEdit", HONEY)
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	result.set_constant("h_separation", "GridContainer", 16)
	result.set_constant("v_separation", "GridContainer", 16)
	return result

func build_matcher() -> void:
	translations.clear()
	var keys: Array = []
	var all_phrases := phrases.duplicate()
	var ui_phrases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_translations.json"))
	for english in ui_phrases: all_phrases.append([english, ui_phrases[english]])
	for pair in all_phrases:
		var key: String = pair[0] if language == "zh" else pair[1]
		translations[key] = pair[1] if language == "zh" else pair[0]
		if key not in keys: keys.append(key)
	keys.sort_custom(func(a, b): return a.length() > b.length())
	var patterns: Array[String] = []
	for key in keys:
		var escaped := ""
		for character in key:
			if character in "\\.^$|?*+()[]{}": escaped += "\\"
			escaped += character
		patterns.append("(?<![A-Za-z_])" + escaped + "(?![A-Za-z_])")
	matcher.compile("|".join(patterns))

func localize(value: String) -> String:
	var result := ""
	var cursor := 0
	for found in matcher.search_all(value):
		result += value.substr(cursor, found.get_start() - cursor) + translations[found.get_string()]
		cursor = found.get_end()
	return result + value.substr(cursor)

func label(parent: Node, value: String, font_size := 18, color := TEXT) -> Label:
	var item := Label.new()
	item.text = localize(value)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	return item

func tag(parent: Node, value: String, color := MUTED) -> Label:
	var item := label(parent, value, 14, color)
	item.add_theme_font_override("font", mono)
	return item

func button(parent: Node, value: String, action: Callable, disabled := false, accent := false) -> Button:
	var item := Button.new()
	item.text = localize(value)
	item.disabled = disabled
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(action)
	if accent:
		item.theme_type_variation = "PrimaryAction"
	parent.add_child(item)
	return item

func row(parent: Node, gap := 12) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", gap)
	parent.add_child(item)
	return item

func column(parent: Node, expand := true) -> VBoxContainer:
	var item := VBoxContainer.new()
	if expand: item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(item)
	return item

func panel(parent: Node, fill := SURFACE, border := LINE, padding := 20) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", box(fill, border, 14, padding))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	return column(frame)

func spacer(parent: Node, height := 8) -> void:
	var item := Control.new()
	item.custom_minimum_size.y = height
	parent.add_child(item)

func centered(parent: Node, width := 840) -> VBoxContainer:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	var body := column(center)
	body.custom_minimum_size.x = width
	return body

func render() -> void:
	combat_feedback.before_render(run)
	if run.screen in ["menu", "battle", "event"]: route_notice = ""
	if last_screen != "battle" and run.screen == "battle": bug_lesson = ""
	if last_screen != "battle" or run.screen != "battle": feedback = ""
	for child in get_children():
		if child == game_feel or child == combat_feedback: continue
		remove_child(child)
		child.queue_free()
	overlay = null
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 16 if run.screen == "battle" else 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	content = column(scroll)
	content.add_theme_constant_override("separation", 6 if run.screen == "map" else 12)
	var header := row(content, 20)
	var brand := column(header)
	brand.add_theme_constant_override("separation", 0)
	label(brand, "BUGBOUND_", 22 if run.screen == "battle" else 27, HONEY)
	if run.screen != "battle": tag(brand, "A BUG IN THE SYSTEM", MINT)
	button(header, "Card Library", func(): collection(true))
	button(header, "中文 / EN", toggle_language)
	if run.screen != "menu":
		button(header, "Deck · %d" % run.cards.size(), func(): collection(false))
		button(header, "Pause  /  Esc", pause_menu)
		if run.screen != "battle":
			var bar := row(content, 24)
			tag(bar, "ACT 1  /  DESKTOP", MINT)
			tag(bar, "HP %d / %d" % [run.hp, run.max_hp], MINT)
			tag(bar, "PATH %02d / 11" % mini(11, run.tier + 1), HONEY)
			tag(bar, "SEED  " + run.rng.seed_text).tooltip_text = "RNG CALLS %d" % run.rng.calls
	match run.screen:
		"menu": menu_screen()
		"map": map_screen()
		"battle": battle_screen()
		"reward": reward_screen()
		"event": event_screen()
		_: result_screen()
	if last_screen != run.screen:
		content.modulate.a = 0
		content.create_tween().tween_property(content, "modulate:a", 1.0, maxf(0.001, game_feel_settings.screen_enter_duration))
	last_screen = run.screen
	combat_feedback.after_render(run)

func toggle_language() -> void:
	language = "zh" if language == "en" else "en"
	build_matcher()
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("ui", "language", language)
	config.save("user://settings.cfg")
	render()

func dismiss_guidance() -> void:
	guidance_dismissed = true
	render()

func menu_screen() -> void:
	spacer(content, 8)
	var layout := row(content, 36)
	var intro := column(layout)
	intro.size_flags_stretch_ratio = 1.08
	tag(intro, "ROGUELIKE DECKBUILDER  /  ACT 01", HONEY)
	label(intro, "Small bug.\nBig system.", 54)
	label(intro, "You’re a programmer trapped inside a computer.\nTurn its bugs into your best commands.", 18, MUTED)
	spacer(intro, 8)
	var boot := panel(intro, SURFACE, LINE, 16)
	boot.add_theme_constant_override("separation", 8)
	tag(boot, "CHOOSE YOUR BUILD", MINT)
	var builds := OptionButton.new()
	builds.name = "StartingBuild"
	builds.custom_minimum_size.y = 40
	for key in Catalog.LOADOUTS:
		builds.add_item(localize(Catalog.LOADOUTS[key].name))
	builds.selected = Catalog.LOADOUTS.keys().find(selected_loadout)
	boot.add_child(builds)
	var build_hint := label(boot, Catalog.LOADOUTS[selected_loadout].hint, 15, MUTED)
	build_hint.name = "BuildHint"
	builds.item_selected.connect(func(index):
		selected_loadout = Catalog.LOADOUTS.keys()[index]
		build_hint.text = localize(Catalog.LOADOUTS[selected_loadout].hint))
	button(boot, "NEW RUN    →", func(): run.start(Crypto.new().generate_random_bytes(8).hex_encode(), selected_loadout), false, true).custom_minimum_size.y = 48
	tag(boot, "OR REPLAY A SEED")
	var seed_row := row(boot)
	var seed_input := LineEdit.new()
	seed_input.text = "BUG-404-LOL"
	seed_input.max_length = 24
	seed_input.custom_minimum_size.y = 50
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.add_theme_font_override("font", mono)
	seed_row.add_child(seed_input)
	seed_input.text_submitted.connect(func(value): run.start(value, selected_loadout))
	button(seed_row, "BOOT →", func(): run.start(seed_input.text, selected_loadout))
	var art := panel(layout, Color("dfe9d9"), Color("dfe9d9"), 30)
	art.get_parent().size_flags_stretch_ratio = 0.92
	tag(art, "PLAYER_PROCESS  /  BEE PROGRAMMER", Color("456754"))
	portrait(art, "player", 260)
	label(art, "Every bug has an address.", 28, INK)
	label(art, "Build your deck. Break the rules.\nFind your way out of the Desktop.", 20, Color("486454"))
	spacer(content, 8)
	var rules := row(content, 18)
	for entry in [["01", "Choose your path", "Battles, strange files, and hidden folders."], ["02", "Exploit the bugs", "Every reward comes with a risk."], ["03", "Face Antivirus", "The system thinks you’re malware."]]:
		var tile := panel(rules)
		tag(tile, entry[0], HONEY)
		label(tile, entry[1], 21)
		label(tile, entry[2], 16, MUTED)

func map_screen() -> void:
	var heading := row(content)
	var copy := column(heading)
	label(copy, "Choose a system path.", 30)
	label(copy, "One step deeper into the Desktop. Pick an open process to continue.", 16, MUTED)
	tag(heading, "%02d BATTLES WON  /  %02d BUG TRIGGERS" % [run.battles_won, run.bugs_triggered], HONEY)
	var board_frame := panel(content, Color("14232b"), LINE, 12)
	tag(board_frame, "FILE EXPLORER   /   C:\\Desktop\\Act_1", MINT)
	var scroll := ScrollContainer.new()
	var board_height: int = ROUTE_BOARD.BOARD_HEIGHT_WITH_SECRET if run.flags.secretUnlocked else ROUTE_BOARD.BOARD_HEIGHT
	scroll.custom_minimum_size.y = board_height
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_frame.add_child(scroll)
	var board := Control.new()
	board.set_script(ROUTE_BOARD)
	board.custom_minimum_size = Vector2(ROUTE_BOARD.BOARD_WIDTH, board_height)
	board.locations = run.map.filter(func(node): return node.kind != "secret" or run.flags.secretUnlocked)
	board.current_tier = run.tier
	board.visited = run.completed
	scroll.add_child(board)
	for node in board.locations:
		var unlocked: bool = node.tier == run.tier
		var passed: bool = node.id in run.completed
		var tone := HONEY if unlocked else (MINT if passed else LINE)
		var control := button(board, "", run.enter.bind(node.id), not unlocked)
		control.position = board.point(node) - ROUTE_BOARD.NODE_OFFSET
		control.size = ROUTE_BOARD.NODE_SIZE
		control.tooltip_text = node.path + "\n" + localize(ROUTE_DETAILS.tooltip_text(node, unlocked, passed))
		control.add_theme_stylebox_override("normal", box(Color("20323a"), tone))
		control.add_theme_stylebox_override("disabled", box(SURFACE, tone))
		var body := VBoxContainer.new()
		body.position = Vector2(10, 6)
		body.size = ROUTE_BOARD.NODE_SIZE - Vector2(20, 12)
		body.add_theme_constant_override("separation", 2)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.add_child(body)
		var kind_color := CORAL if node.kind in ["boss", "elite"] else (MINT if node.kind in ["event", "secret"] else MUTED)
		label(body, ROUTE_DETAILS.kind_text(node) + ("  ✓" if passed else ""), 12, kind_color)
		var node_title := label(body, ROUTE_DETAILS.title_text(node), 17, TEXT if unlocked or passed else MUTED)
		node_title.custom_minimum_size.y = 24
		node_title.max_lines_visible = 1
		node_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var trait_label := label(body, ROUTE_DETAILS.trait_text(node), 13, MUTED)
		trait_label.custom_minimum_size.y = 34
		label(body, ROUTE_DETAILS.status_text(unlocked, passed), 12, tone if unlocked or passed else MUTED)
		for child in body.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tier in range(11):
		var number := tag(board, "PATH %02d" % (tier + 1), HONEY if tier == run.tier else MUTED)
		number.position = Vector2(24 + tier * ROUTE_BOARD.TIER_WIDTH, ROUTE_BOARD.TIER_LABEL_Y_WITH_SECRET if run.flags.secretUnlocked else ROUTE_BOARD.TIER_LABEL_Y)
		number.size.x = 150
	scroll.set_deferred("scroll_horizontal", maxi(0, run.tier * ROUTE_BOARD.TIER_WIDTH - ROUTE_BOARD.TIER_WIDTH))
	var info := row(content, 18)
	var notes := panel(info, SURFACE, LINE, 12)
	notes.add_theme_constant_override("separation", 4)
	tag(notes, "YOUR NEXT MOVE", HONEY)
	label(notes, "Follow an open route above.", 18)
	var available: Array = run.map.filter(func(node): return node.tier == run.tier and node.has("enemy"))
	var matching := available.size() > 1 and available.all(func(node): return node.enemy == available[0].enemy)
	label(notes, "Matching encounters have the same rules; either route advances." if matching else "Elite processes hit harder. Events can repair your system or change your deck.", 14, MUTED)
	var build := panel(info, SURFACE, LINE, 12)
	build.add_theme_constant_override("separation", 4)
	tag(build, route_notice if not route_notice.is_empty() else "CURRENT BUILD", MINT)
	label(build, localize(Catalog.LOADOUTS[run.loadout_key].name) + " · " + localize("%d commands installed" % run.cards.size()), 18)
	label(build, "Same seed + build + decisions = same run.", 14, MUTED)
	if run.flags.daemonDraw or run.flags.printerDebt: tag(build, "BACKGROUND PROCESS PENDING", CORAL)

func portrait(parent: Node, key: String, height := 140) -> TextureRect:
	var sheet: Texture2D = load("res://assets/bee-rewards.png" if key == "player" else "res://assets/bugbound-characters.png")
	var index: int = ["player", "folder", "cursor", "trash", "frozen", "memoryHog", "antivirus"].find(key)
	if key != "player" and Catalog.data.enemies[key].has("artSlot"):
		sheet = load("res://assets/variety-icons.png")
		index = Catalog.data.enemies[key].artSlot
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var cell := Vector2(sheet.get_width() / 4.0, sheet.get_height() / 2.0)
	atlas.region = Rect2(Vector2(index % 4, int(index / 4.0)) * cell, cell)
	var view: TextureRect = BEE_PORTRAIT.new() if key == "player" else TextureRect.new()
	if key != "player": view.texture = atlas
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(height, height)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = PAPER_SHADER
	if key != "player": view.material = shader_material
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	return view

func health(parent: Node, value: int, maximum: int, color: Color) -> void:
	var line := row(parent)
	tag(line, "HP", color)
	label(line, "%d / %d" % [value, maximum], 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var meter := ProgressBar.new()
	meter.max_value = maximum
	meter.value = value
	meter.show_percentage = false
	meter.custom_minimum_size.y = 9
	meter.add_theme_stylebox_override("background", box(INK, INK, 4, 0))
	meter.add_theme_stylebox_override("fill", box(color, color, 4, 0))
	parent.add_child(meter)

func battle_screen() -> void:
	var b := run.battle
	var enemy: Dictionary = Catalog.data.enemies[b.enemy_key]
	var compact := get_viewport_rect().size.y < 800
	if compact: content.add_theme_constant_override("separation", 6)
	var stage := row(content, 16)
	var arena := panel(stage, Color("203337"), Color("415653"), 12 if compact else 16)
	if compact: arena.add_theme_constant_override("separation", 8)
	arena.get_parent().size_flags_stretch_ratio = 3.2
	var title := row(arena)
	tag(title, "ACT 1  /  DESKTOP" + "   ·   " + enemy.process).tooltip_text = "SEED " + run.rng.seed_text
	tag(title, "TURN %02d" % b.turn, HONEY).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var fighters := row(arena, 24)
	fighters.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var player := column(fighters)
	var enemy_side := column(fighters)
	for side in [player, enemy_side]: side.add_theme_constant_override("separation", 8)
	var player_row := row(player)
	# Artwork frames change inside a fixed slot without moving the battle layout.
	var player_slot := Control.new()
	player_slot.custom_minimum_size = Vector2.ONE * (120 if compact else 180)
	player_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_row.add_child(player_slot)
	combat_feedback.player = portrait(player_slot, "player", int(player_slot.custom_minimum_size.x))
	combat_feedback.player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var player_stats := column(player_row)
	player_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	label(player_stats, "Bee Programmer", 22)
	health(player_stats, b.hp, run.max_hp, MINT)
	tag(player_stats, "%d BLOCK" % b.block, MINT)
	var enemy_row := row(enemy_side)
	combat_feedback.enemy = portrait(enemy_row, b.enemy_key, 120 if compact else 180)
	var enemy_stats := column(enemy_row)
	enemy_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	label(enemy_stats, enemy.name, 22).tooltip_text = localize(enemy.feature)
	health(enemy_stats, b.enemy_hp, enemy.hp, CORAL)
	tag(enemy_stats, "%d BLOCK  ·  +%d STR" % [b.enemy_shield, b.strength], CORAL)
	if run.battles_won == 0 and not guidance_dismissed:
		var lesson_row := row(player, 6)
		var lesson := label(lesson_row, bug_lesson if not bug_lesson.is_empty() else "Spend Energy on cards. Block reduces the next hit.\nMarked cards trigger the bug: gain its reward and pay its risk.", 14, HONEY)
		lesson.name = "FirstBattleGuide"
		button(lesson_row, "×", dismiss_guidance).tooltip_text = localize("Dismiss guidance")
	else:
		label(player, enemy.feature, 15, MUTED)
	var intent := panel(enemy_side, Color("352c2b"), Color("85594d"), 8)
	intent.add_theme_constant_override("separation", 2)
	label(intent, "ENEMY INTENT  ·  %d DAMAGE" % b.intent_damage(), 18, CORAL)
	label(intent, b.intent.label + ("  ·  +%d BLOCK" % b.intent.block if b.intent.block else ""), 15)
	var incoming := label(intent, localize("After Block: %d damage") % b.incoming_damage(), 15, MINT if b.incoming_damage() == 0 else CORAL)
	if b.incoming_damage() >= b.hp: incoming.text += " · " + localize("LETHAL")
	incoming.name = "IncomingDamage"
	incoming.tooltip_text = localize("If you end your turn now. Block resets after the enemy acts.")
	var bug_panel := panel(stage, Color("18282b"), LINE, 14)
	bug_panel.name = "MonitorBody"
	combat_feedback.monitor = bug_panel.get_parent()
	combat_feedback.completion_text = localize("BUG COMPLETE!")
	bug_panel.add_theme_constant_override("separation", 6)
	bug_panel.get_parent().custom_minimum_size.x = 320
	var bug: Dictionary = Catalog.data.bugs[b.bug]
	var monitor_heading := tag(bug_panel, "BUG MONITOR", HONEY)
	label(bug_panel, bug.name, 22)
	for rule in [["TRIGGER", bug.trigger, TEXT], ["REWARD", bug.reward, MINT], ["RISK", bug.risk, CORAL]]:
		var line := column(bug_panel)
		line.add_theme_constant_override("separation", 2)
		label(line, rule[0], 12, rule[2])
		label(line, rule[1], 16, rule[2])
	if bug.has("target"): combat_feedback.progress = tag(bug_panel, "%d / %d  %s" % [b.progress, bug.target, bug.progressLabel], HONEY)
	else: combat_feedback.progress = tag(bug_panel, "%d BUG TRIGGERS" % b.triggers)
	combat_feedback.progress.name = "BugProgress"
	combat_feedback.progress.set_meta("complete_text", localize("%d / %d  %s" % [bug.target, bug.target, bug.progressLabel] if bug.has("target") else "%d BUG TRIGGERS" % (b.triggers + 1)))
	if b.enemy_key == "antivirus": tag(bug_panel, "THREAT LEVEL %d / 6" % b.threat, CORAL)
	var bee_bar := row(content, 18)
	var nectar := label(bee_bar, "NECTAR %d" % b.bee.nectar, 16, HONEY)
	nectar.autowrap_mode = TextServer.AUTOWRAP_OFF
	nectar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var states: Array[String] = []
	if b.bee.bank: states.append("Cached Energy: %d" % b.bee.bank)
	if b.bee.compiling: states.append("Compiler %d/6" % b.bee.comb)
	if b.bee.pollen: states.append("Pollen: " + ("collect next effect" if b.bee.pollen == 2 else "pass to next card"))
	if b.bee.guard: states.append("Retaliation %d" % b.bee.guard)
	if b.debt: states.append("NEXT TURN -%d ENERGY" % b.debt)
	var nectar_help := label(bee_bar, "  ·  ".join(states) if not states.is_empty() else "First Attack: +1 Nectar · grow it or spend it", 15, MUTED)
	var nectar_explanation := localize("Nectar lasts this battle. It strengthens Nectar Lance and Wax Wall. Swarm Loop spends it for damage; Royal Jelly spends 2 to reduce another card's cost.")
	nectar.tooltip_text = nectar_explanation
	nectar_help.tooltip_text = nectar_explanation
	var tools := row(content, 16)
	var energy := panel(tools, Color("24473f"), MINT, 8)
	energy.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(energy, "%d ENERGY" % b.energy, 22, TEXT).autowrap_mode = TextServer.AUTOWRAP_OFF
	var hand_info := column(tools)
	hand_info.add_theme_constant_override("separation", 0)
	label(hand_info, "Your commands", 20)
	var action_hint := label(hand_info, feedback if not feedback.is_empty() else "Click a card to play", 14, HONEY if not feedback.is_empty() else MUTED)
	action_hint.name = "CombatHint"
	action_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	action_hint.custom_minimum_size.y = 20
	action_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_hint.tooltip_text = localize(feedback)
	tag(tools, "HAND %d  ·  DRAW %d  ·  DISCARD %d" % [b.hand.size(), b.deck.size(), b.discard.size()], MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button(tools, "Battle log", show_log)
	button(tools, "END TURN  ↵", run.end_turn, b.popup_open or not b.choice.is_empty(), true)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 266 if compact else 326
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(hand_scroll)
	var hand_margin := MarginContainer.new()
	hand_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Reserve the hover lift and scaled top edge inside the scroll clip.
	hand_margin.add_theme_constant_override("margin_top", 22)
	hand_margin.add_theme_constant_override("margin_bottom", 6)
	hand_margin.add_theme_constant_override("margin_left", 8)
	hand_margin.add_theme_constant_override("margin_right", 8)
	hand_scroll.add_child(hand_margin)
	var cards := row(hand_margin)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for card in b.hand:
		var view = card_view(cards, card, play_card.bind(int(card.id)), not b.can_play(card))
		combat_feedback.cards[int(card.id)] = view
		view.custom_minimum_size = Vector2(222, 244 if compact else 302)
		view.art_height = 94.0 if compact else 126.0
		view.get_node("Margin/Body/ArtFrame").custom_minimum_size.y = view.art_height
		if b.can_play(card):
			var preview := b.preview_card(card)
			var details := ""
			if preview.nectar_spent > 0:
				details = localize("Spend %d Nectar") % preview.nectar_spent
			if card.key == "swarm" or card.has("scaling"):
				var current_effect: String = localize("Now: %d Block") % preview.block if card.get("scaling", "") == "nectar_block" else localize("Now: %d damage") % preview.damage
				details += "\n" + current_effect
				view.get_node("Margin/Body/Effect").text += "\n" + current_effect
			if preview.triggers_bug:
				var notice: Label = view.get_node("Margin/Body/LockNotice")
				notice.text = localize("TRIGGERS BUG")
				notice.add_theme_color_override("font_color", Color("775716"))
				notice.show()
				details += "\n" + localize("TRIGGERS BUG") + ": " + localize(bug.name) + "\n" + localize("REWARD") + ": " + localize(bug.reward) + "\n" + localize("RISK") + ": " + localize(bug.risk)
				var highlight := func(): monitor_heading.text = localize("THIS CARD TRIGGERS THE BUG")
				var unhighlight := func(): monitor_heading.text = localize("BUG MONITOR")
				view.mouse_entered.connect(highlight)
				view.focus_entered.connect(highlight)
				view.mouse_exited.connect(unhighlight)
				view.focus_exited.connect(unhighlight)
			view.tooltip_text += "\n" + details.strip_edges()
		if not b.can_play(card):
			var reason := "NOT ENOUGH ENERGY" if card.cost > b.energy else "REQUIREMENTS NOT MET"
			if b.popup_open or not b.choice.is_empty(): reason = "RESOLVE CHOICE FIRST"
			view.get_node("Margin/Body/LockNotice").text = localize(reason)
			view.tooltip_text += "\n" + localize(reason)
	if b.hand.is_empty(): label(cards, "HAND EMPTY  /  End your turn to draw again.", 22, MUTED)
	if b.popup_open:
		var dialog := modal("Allow background optimization?")
		label(dialog, "helper_undefined.exe wants to optimize this turn. Choose its permissions.", 19, MUTED)
		button(dialog, "ALLOW\nDraw 2, +1 Energy\nRisk: Lose 4 HP", run.popup.bind(true), false, true)
		button(dialog, "NOT NOW\nGain 9 Block\nNext turn -1 Energy", run.popup.bind(false))
	elif not b.choice.is_empty():
		var title_text := "Upgrade a card: cost reduced by 1" if b.choice.kind == "jelly" else ("Arrange remaining cards: next draw first" if b.choice.drawn else "Choose a card to draw")
		var dialog := modal(title_text)
		var choices: Array = b.hand.filter(func(card): return card.cost > 0) if b.choice.kind == "jelly" else b.choice.cards
		for card in choices: button(dialog, card.name, run.choose.bind(int(card.id)))

func play_card(id: int) -> void:
	if run.screen != "battle" or run.battle == null: return
	for card in run.battle.hand:
		if card.id == id and run.battle.can_play(card):
			feedback = "> " + card.name + "  /  " + Catalog.describe(card)
			if run.battle.preview_card(card).triggers_bug:
				bug_lesson = "Bug triggered! Reward and risk applied.\nThe monitor now shows a new bug."
			combat_feedback.prepare_card(id, card)
			break
	run.play(id)

func card_view(parent: Node, card: Dictionary, action: Callable, disabled := false) -> Button:
	# Containers own the slot; GameFeel owns the card's visual transform.
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	var view = CARD_SCENE.instantiate()
	slot.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.custom_minimum_size = view.get_combined_minimum_size()
	view.minimum_size_changed.connect(func(): slot.custom_minimum_size = view.get_combined_minimum_size())
	view.game_feel = game_feel
	view.hover_area = slot
	view.hover_allowed = func(): return not is_instance_valid(overlay)
	view.configure(card, localize, action, disabled)
	return view

func reward_screen() -> void:
	spacer(content, 24)
	var body := centered(content, 780)
	tag(body, "PROCESS TERMINATED  /  PACKAGE MANAGER", MINT)
	label(body, "A new command awaits.", 44)
	label(body, "Install one card in your deck, or keep your current build.", 20, MUTED)
	spacer(body, 18)
	var cards := row(body, 30)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(run.rewards.size()):
		var choice := column(cards, false)
		var style := Catalog.reward_style(run.rewards[i].key)
		tag(choice, Catalog.LOADOUTS[style].name, HONEY).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_view(choice, run.rewards[i], install_reward.bind(i))
		button(choice, "INSTALL →", install_reward.bind(i), false, true)
	spacer(body, 12)
	button(body, "Skip installation", install_reward.bind(-1))

func install_reward(index: int) -> void:
	if run.screen != "reward" or index < -1 or index >= run.rewards.size(): return
	route_notice = "Installed: " + run.rewards[index].name if index >= 0 else "Deck unchanged."
	run.reward(index)

func event_screen() -> void:
	spacer(content, 30)
	var body := centered(content, 890)
	var window := panel(body, SURFACE, LINE, 32)
	var copy: Dictionary = Catalog.data.events[run.current.event]
	tag(window, "[ ? ]   " + copy.eyebrow, HONEY)
	spacer(window, 12)
	label(window, copy.title, 40)
	label(window, copy.body, 22, MUTED)
	spacer(window, 24)
	for side in ["left", "right"]:
		var choice := button(window, "\n".join(copy[side]), run.event.bind(side == "left"))
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.custom_minimum_size.y = 108
		choice.add_theme_font_size_override("font_size", 20)
	tag(window, "C:\\Desktop\\" + run.current.get("label", "unknown"))

func result_screen() -> void:
	spacer(content, 30)
	var body := centered(content, 820)
	var won := run.screen == "victory"
	tag(body, "ACT 1 COMPLETE" if won else "FATAL ERROR", MINT if won else CORAL)
	label(body, "You’re still a bug.\nBut you’re free." if won else "Process terminated.", 48)
	label(body, "Antivirus has lifted quarantine." if won else "Your process crashed. A new run is one command away.", 22, MUTED)
	spacer(body, 20)
	var stats := row(body)
	for entry in [["BATTLES", run.battles_won], ["BUG TRIGGERS", run.bugs_triggered], ["DECK", run.cards.size()]]:
		var tile := panel(stats)
		tag(tile, entry[0])
		label(tile, str(entry[1]), 40, HONEY)
	spacer(body, 20)
	button(body, "RETURN TO RUN MENU  →", run.abandon, false, true)

func modal(title_text: String, wide := false) -> VBoxContainer:
	disable_background_focus(self)
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.045, 0.055, 0.91)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1120 if wide else 760, 0)
	frame.add_theme_stylebox_override("panel", box(SURFACE, Color("53645d"), 16, 28))
	center.add_child(frame)
	var shell := column(frame)
	tag(shell, "BUGBOUND  /  SYSTEM WINDOW", HONEY)
	label(shell, title_text, 29)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 490 if wide else 340
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	return column(scroll)

func disable_background_focus(node: Node) -> void:
	for child in node.get_children():
		if child is Control: child.focus_mode = Control.FOCUS_NONE
		disable_background_focus(child)

func pause_menu() -> void:
	var body := modal("Run paused")
	label(body, "Your run is paused. Resume to continue exactly where you left off.", 20, MUTED)
	button(body, "Resume run", render, false, true).grab_focus()
	button(body, "Inspect current deck", func(): collection(false))
	button(body, "Return to home…", func():
		var confirm := modal("Abandon this run?")
		label(confirm, "Abandon this run? All progress in this run will be lost.", 20, MUTED)
		button(confirm, "Abandon run and return home", run.abandon)
		button(confirm, "Cancel", pause_menu, false, true))

func collection(library: bool) -> void:
	var body := modal("Card Library" if library else "Current deck", true)
	button(body, "Close", render).grab_focus()
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	for card in (Catalog.data.cards if library else run.cards): card_view(grid, card, func(): pass)

func show_log() -> void:
	var body := modal("Battle log")
	button(body, "Close", render).grab_focus()
	for entry in run.battle.log: label(body, entry, 17, MUTED)

func _unhandled_key_input(event: InputEvent) -> void:
	if not content.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(overlay): render()
			elif run.screen != "menu": pause_menu()
		elif event.keycode == KEY_ENTER and run.screen == "battle" and not is_instance_valid(overlay): run.end_turn()

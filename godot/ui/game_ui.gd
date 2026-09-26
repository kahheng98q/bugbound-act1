extends Control
## Presentation only; RunState owns every gameplay action.
const CARD_SCENE = preload("res://scenes/card.tscn")
const ROUTE_BOARD = preload("res://ui/route_board.gd")
const ROUTE_DETAILS = preload("res://ui/route_details.gd")
const PAPER_SHADER = preload("res://ui/paper_cutout.gdshader")
const FEEDBACK = preload("res://ui/combat_feedback.gd")
const BEE_PORTRAIT = preload("res://ui/bee_portrait.gd")
const SPIDER_PORTRAIT = preload("res://ui/spider_portrait.gd")
const SHRINE_BACKDROP = preload("res://ui/shrine_backdrop.gd")
@export var game_feel_settings: GameFeelSettings = preload("res://ui/default_game_feel.tres")
var game_feel := GameFeel.new()
var combat_feedback := FEEDBACK.new()
var shrine_backdrop := SHRINE_BACKDROP.new()
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
var language := "zh"
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
var menu_seed_text := "BUG-404-LOL"
var menu_seed_expanded := false
var menu_deck_open := false
var preview_label: Label
var preview_card_id := -1
const MENU_SIGNATURES := {
	"balanced": ["strike", "hotfix"], "nectar": ["forage", "lance"],
	"fortress": ["patch", "bash"], "overdrive": ["thread", "trace"],
	"spider": ["web_trap", "inject"],
}

func _ready() -> void:
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
	build_matcher()
	theme = make_theme()
	game_feel.settings = game_feel_settings
	add_child(game_feel)
	combat_feedback.feel = game_feel
	combat_feedback.screen = self
	add_child(combat_feedback)
	shrine_backdrop.name = "ShrineBackdrop"
	add_child(shrine_backdrop)
	shrine_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	for role in ["CombatRule", "CombatSecondary"]:
		result.set_type_variation(role, "Label")
		result.set_font_size("font_size", role, 16 if role == "CombatRule" else 14)
		result.set_color("font_color", role, TEXT if role == "CombatRule" else MUTED)
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
	if run.screen == "battle" and font_size in [14, 16]:
		item.theme_type_variation = "CombatRule" if font_size == 16 else "CombatSecondary"
	else:
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
	preview_label = null
	preview_card_id = -1
	combat_feedback.before_render(run)
	if run.screen in ["menu", "battle", "event"]: route_notice = ""
	if last_screen != "battle" and run.screen == "battle": bug_lesson = ""
	if last_screen != "battle" or run.screen != "battle": feedback = ""
	for child in get_children():
		if child == game_feel or child == combat_feedback or child == shrine_backdrop: continue
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
	content.add_theme_constant_override("separation", 6 if run.screen == "map" else (8 if run.screen == "menu" else 12))
	var header := row(content, 20)
	var brand := column(header)
	brand.add_theme_constant_override("separation", 0)
	label(brand, "BUGBOUND_", 22 if run.screen in ["battle", "menu"] else 27, HONEY)
	if run.screen != "battle": tag(brand, "A BUG IN THE SYSTEM", MINT)
	button(header, "Card Library", func(): collection(true))
	if run.screen != "menu":
		button(header, "Deck · %d  [D]" % run.cards.size(), func(): collection(false))
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
	# Keep the room behind the retained battle while defeat/reward effects finish.
	shrine_backdrop.visible = run.screen == "battle" or not content.visible
	shrine_backdrop.set_process(shrine_backdrop.visible)
	if run.screen != "battle" and not content.visible:
		content.visibility_changed.connect(func():
			shrine_backdrop.hide()
			shrine_backdrop.set_process(false), CONNECT_ONE_SHOT)
	if menu_deck_open and run.screen == "menu": starting_deck()

func dismiss_guidance() -> void:
	guidance_dismissed = true
	render()

func menu_screen() -> void:
	label(content, "Small bug. Big system.", 34)
	label(content, "Trapped inside a computer. Build your deck and exploit its bugs to escape.", 18, Color("bdcdce"))
	var layout := row(content, 24)
	layout.name = "MenuLayout"
	var boot := column(layout)
	boot.size_flags_stretch_ratio = 0.4
	boot.add_theme_constant_override("separation", 6)
	label(boot, "CHOOSE YOUR BUILD", 16, MINT)
	var builds := GridContainer.new()
	builds.columns = 2
	builds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	builds.add_theme_constant_override("h_separation", 8)
	builds.add_theme_constant_override("v_separation", 6)
	boot.add_child(builds)
	for key in Catalog.LOADOUTS:
		var choice := button(builds, "", func():
			selected_loadout = key
			render()
			find_child("Build_" + key, true, false).grab_focus())
		choice.name = "Build_" + key
		choice.custom_minimum_size = Vector2(0, 97)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.tooltip_text = localize(Catalog.LOADOUTS[key].hint)
		if key == selected_loadout:
			var selected_style := box(Color("263b3e"), HONEY, 8, 10)
			selected_style.set_border_width_all(2)
			choice.add_theme_stylebox_override("normal", selected_style)
		var inset := MarginContainer.new()
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 6)
		choice.add_child(inset)
		var copy := column(inset)
		copy.add_theme_constant_override("separation", 2)
		label(copy, ("✓ " if key == selected_loadout else "") + localize(Catalog.LOADOUTS[key].name), 17, HONEY if key == selected_loadout else TEXT)
		label(copy, Catalog.LOADOUTS[key].hint, 13, Color("bdcdce"))
		if key == "balanced": label(copy, "Recommended for first run", 12, MINT)
		menu_ignore_mouse(inset)
	button(boot, "Start Adventure  →", func(): run.start(Crypto.new().generate_random_bytes(8).hex_encode(), selected_loadout), false, true).name = "StartAdventure"
	var disclosure := button(boot, ("▾ " if menu_seed_expanded else "▸ ") + localize("Seeded run"), func():
		menu_seed_expanded = not menu_seed_expanded
		render()
		find_child("SeedDisclosure", true, false).grab_focus())
	disclosure.name = "SeedDisclosure"
	disclosure.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if menu_seed_expanded:
		label(boot, "Same seed + build + decisions = same run.", 16, Color("bdcdce"))
		var seed_row := row(boot, 8)
		var seed_input := LineEdit.new()
		seed_input.name = "MenuSeed"
		seed_input.text = menu_seed_text
		seed_input.max_length = 24
		seed_input.custom_minimum_size.y = 42
		seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seed_input.add_theme_font_override("font", mono)
		seed_row.add_child(seed_input)
		seed_input.text_changed.connect(func(value): menu_seed_text = value)
		seed_input.text_submitted.connect(func(value): run.start(value, selected_loadout))
		button(seed_row, "BOOT →", func(): run.start(menu_seed_text, selected_loadout)).name = "SeedLaunch"
	var preview := panel(layout, Color("14242b"), LINE, 14)
	preview.get_parent().size_flags_stretch_ratio = 0.6
	preview.add_theme_constant_override("separation", 6)
	label(preview, "STARTUP / BUILD PREVIEW", 16, MINT)
	var player := row(preview, 12)
	var player_portrait := portrait(player, "spider" if selected_loadout == "spider" else "player", 64)
	player_portrait.custom_minimum_size.x = 84
	player_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var details := column(player)
	details.add_theme_constant_override("separation", 4)
	label(details, Catalog.LOADOUTS[selected_loadout].name, 28)
	label(details, Catalog.LOADOUTS[selected_loadout].hint, 18, Color("bdcdce")).name = "BuildHint"
	label(preview, "Signature starting cards", 16, MINT)
	var cards := row(preview, 18)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for key in MENU_SIGNATURES[selected_loadout]:
		var view := menu_inspection_card(cards, key)
		view.name = "Signature_" + key
	button(preview, "View starting deck", starting_deck).name = "StartingDeck"
	if not menu_seed_expanded:
		var journey := label(content, "Choose your path  →  Exploit the bugs  →  Face Antivirus", 16, Color("bdcdce"))
		journey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func menu_ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: menu_ignore_mouse(child)

func menu_inspection_card(parent: Node, key: String) -> Button:
	var view := card_view(parent, Catalog.card(key), func(): pass, false, true)
	view.set_meta("card_key", key)
	view.custom_minimum_size = Vector2(238, 270)
	view.get_node("Margin/Body/Effect").add_theme_font_size_override("font_size", 16)
	view.get_node("Margin/Body/Top/Type").add_theme_font_size_override("font_size", 16)
	return view

func starting_deck() -> void:
	menu_deck_open = true
	var body := modal("Starting deck", true)
	button(body, "Close", close_starting_deck).name = "CloseStartingDeck"
	body.get_child(0).grab_focus()
	label(body, Catalog.LOADOUTS[selected_loadout].name, 20, MINT)
	var counts := {}
	for key in Catalog.LOADOUTS[selected_loadout].cards: counts[key] = counts.get(key, 0) + 1
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	for key in counts:
		var entry := column(grid, false)
		label(entry, "× %d" % counts[key], 18, HONEY)
		var view := menu_inspection_card(entry, key)
		view.name = "Deck_" + key
		view.set_meta("copy_count", counts[key])

func close_starting_deck() -> void:
	menu_deck_open = false
	render()
	find_child("StartingDeck", true, false).grab_focus()

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
	if key == "spider":
		var spider: TextureRect = SPIDER_PORTRAIT.new()
		spider.custom_minimum_size = Vector2(height, height)
		spider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(spider)
		return spider
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

func health(parent: Node, value: int, maximum: int, color: Color, status := "HP", block_amount := -1) -> void:
	var line := row(parent)
	if block_amount >= 0:
		var badge := label(line, "%d BLOCK" % block_amount, 20, INK if block_amount > 0 else MINT)
		badge.name = "BlockBadge"
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var badge_style := box(MINT if block_amount > 0 else Color("24473f"), MINT, 6, 6)
		badge_style.content_margin_top = 0
		badge_style.content_margin_bottom = 0
		badge.add_theme_stylebox_override("normal", badge_style)
		badge.tooltip_text = localize("If you end your turn now. Block resets after the enemy acts.")
		if status != "HP": tag(line, status, color)
	else:
		tag(line, status, color)
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
	if compact: content.add_theme_constant_override("separation", 2)
	var stage := row(content, 16)
	var arena := panel(stage, Color(0.035, 0.075, 0.1, 0.68), Color("415e69"), 9 if compact else 16)
	if compact: arena.add_theme_constant_override("separation", 8)
	arena.get_parent().size_flags_stretch_ratio = 3.2
	var title := row(arena)
	var total_tiers := 1
	for node in run.map: total_tiers = maxi(total_tiers, int(node.tier) + 1)
	var context := tag(title, localize("ACT 1  /  DESKTOP") + " · " + localize("Route %d / %d") % [run.tier + 1, total_tiers] + " · " + localize(str(enemy.kind).capitalize()) + " · " + localize(Catalog.LOADOUTS[run.loadout_key].name))
	context.name = "RunContext"
	context.tooltip_text = enemy.process + " · SEED " + run.rng.seed_text
	tag(title, "TURN %02d" % b.turn, HONEY).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var fighters := row(arena, 24)
	fighters.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var player := column(fighters)
	var enemy_side := column(fighters)
	for side in [player, enemy_side]: side.add_theme_constant_override("separation", 8)
	var player_row := row(player)
	# Artwork frames change inside a fixed slot without moving the battle layout.
	var player_slot := Control.new()
	player_slot.custom_minimum_size = Vector2.ONE * (72 if compact else 140)
	player_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_row.add_child(player_slot)
	combat_feedback.player = portrait(player_slot, "spider" if run.loadout_key == "spider" else "player", int(player_slot.custom_minimum_size.x))
	combat_feedback.player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var player_stats := column(player_row)
	player_stats.add_theme_constant_override("separation", 6)
	player_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	label(player_stats, "Spider Debugger" if run.loadout_key == "spider" else "Bee Programmer", 22)
	health(player_stats, b.hp, run.max_hp, MINT, "HP", b.block)
	var enemy_row := row(enemy_side)
	combat_feedback.enemy = portrait(enemy_row, b.enemy_key, 72 if compact else 140)
	var enemy_stats := column(enemy_row)
	enemy_stats.add_theme_constant_override("separation", 6)
	enemy_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	label(enemy_stats, enemy.name, 22).tooltip_text = localize(enemy.feature)
	health(enemy_stats, b.enemy_hp, enemy.hp, CORAL, "+%d STR" % b.strength, b.enemy_shield)
	if run.battles_won == 0 and not guidance_dismissed:
		var lesson_row := row(player, 6)
		var lesson := label(lesson_row, "Play cards with Energy. Block reduces the next hit.", 16, HONEY)
		lesson.name = "FirstBattleGuide"
		button(lesson_row, "×", dismiss_guidance).tooltip_text = localize("Dismiss guidance")
	else:
		label(player, enemy.feature, 16, MUTED)
	var intent := panel(enemy_side, Color("352c2b"), Color("85594d"), 8)
	intent.add_theme_constant_override("separation", 2)
	label(intent, localize("Attack: %d · Block: %d") % [b.intent_damage(), b.intent.block], 18, CORAL)
	var incoming := label(intent, localize("After Block: %d damage") % b.incoming_damage(), 18, MINT if b.incoming_damage() == 0 else CORAL)
	if b.incoming_damage() >= b.hp: incoming.text += " · [!] " + localize("LETHAL")
	intent.tooltip_text = localize(b.intent.label) + (localize("  ·  +%d BLOCK") % b.intent.block if b.intent.block else "")
	incoming.name = "IncomingDamage"
	incoming.tooltip_text = localize("If you end your turn now. Block resets after the enemy acts.")
	var bug_panel := panel(stage, Color("18282b"), LINE, 10 if compact else 14)
	bug_panel.name = "MonitorBody"
	combat_feedback.monitor = bug_panel.get_parent()
	combat_feedback.completion_text = localize("BUG COMPLETE!")
	bug_panel.add_theme_constant_override("separation", 6)
	bug_panel.get_parent().custom_minimum_size.x = 380
	var bug: Dictionary = Catalog.data.bugs[b.bug]
	var trigger_text: String = {"memory": "Draw 1+ cards with a card", "firewall": "Gain 5+ Block with one card"}.get(b.bug, bug.trigger)
	var monitor_title := row(bug_panel, 8)
	var monitor_heading := tag(monitor_title, "BUG MONITOR", HONEY)
	label(monitor_title, bug.name, 20)
	for rule in [["TRIGGER", trigger_text, TEXT], ["GAIN", bug.reward, MINT], ["COST", bug.risk, CORAL]]:
		var rule_label := label(bug_panel, localize(rule[0]) + ": " + localize(rule[1]), 16, rule[2])
		if rule[0] == "TRIGGER": rule_label.name = "BugTrigger"
	var bug_status := row(bug_panel, 8)
	bug_status.name = "BugStatus"
	if bug.has("target"): combat_feedback.progress = tag(bug_status, "%d / %d  %s" % [b.progress, bug.target, bug.progressLabel], HONEY)
	else: combat_feedback.progress = tag(bug_status, "%d BUG TRIGGERS" % b.triggers)
	combat_feedback.progress.name = "BugProgress"
	combat_feedback.progress.set_meta("complete_text", localize("%d / %d  %s" % [bug.target, bug.target, bug.progressLabel] if bug.has("target") else "%d BUG TRIGGERS" % (b.triggers + 1)))
	if b.enemy_key == "antivirus": tag(bug_status, "THREAT LEVEL %d / 6" % b.threat, CORAL)
	label(bug_panel, "Triggers replace this bug.", 16, MUTED)
	var bee_bar := row(content, 18)
	var energy := panel(bee_bar, Color("24473f"), MINT, 8)
	energy.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(energy, "%d ENERGY" % b.energy, 22, TEXT).autowrap_mode = TextServer.AUTOWRAP_OFF
	var states: Array[String] = []
	if run.loadout_key == "spider":
		var web_group := column(bee_bar)
		web_group.add_theme_constant_override("separation", 0)
		var captured_names: Array[String] = []
		for key in b.web: captured_names.append(localize(Catalog.data.bugs[key].name))
		var web_label := label(web_group, "WEB %d / 2" % b.web.size(), 16, HONEY)
		web_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var web_help := label(web_group, "Captured: " + ("empty" if captured_names.is_empty() else " · ".join(captured_names)), 16, TEXT)
		web_help.name = "CombatHint"
		web_help.custom_minimum_size.y = 20
		var web_explanation := localize("Triggered Bugs are captured in your 2-slot Web. Spider cards can consume or release them.")
		for node in [web_label, web_help]:
			node.tooltip_text = web_explanation
			node.focus_mode = Control.FOCUS_ALL
			node.mouse_filter = Control.MOUSE_FILTER_STOP
			node.focus_entered.connect(func(): show_combat_help(web_explanation))
			node.focus_exited.connect(clear_combat_help)
		if b.web_trap: states.append("Web Trap armed")
		if b.breakpoint_armed: states.append("Breakpoint armed")
	else:
		var nectar_group := column(bee_bar)
		nectar_group.add_theme_constant_override("separation", 0)
		var nectar := label(nectar_group, "NECTAR %d" % b.bee.nectar, 16, HONEY)
		nectar.autowrap_mode = TextServer.AUTOWRAP_OFF
		nectar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if b.bee.compiling: states.append("Compiler %d/6" % b.bee.comb)
		if b.bee.pollen: states.append("Pollen: " + ("collect next effect" if b.bee.pollen == 2 else "pass to next card"))
		if b.bee.guard: states.append("Retaliation %d" % b.bee.guard)
		var nectar_help := label(nectar_group, "First attack: +1 Nectar available" if b.attacks == 0 else "First attack: Nectar collected", 16, TEXT)
		nectar_help.name = "CombatHint"
		nectar_help.custom_minimum_size.y = 20
		var nectar_explanation := localize("Nectar lasts this battle. It strengthens Nectar Lance and Wax Wall. Swarm Loop spends it for damage; Royal Jelly spends 2 to reduce another card's cost.")
		nectar.tooltip_text = nectar_explanation
		nectar_help.tooltip_text = nectar_explanation
		nectar.focus_mode = Control.FOCUS_ALL
		nectar.mouse_filter = Control.MOUSE_FILTER_STOP
		nectar.focus_entered.connect(func(): show_combat_help(nectar_explanation))
		nectar.focus_exited.connect(clear_combat_help)
	var next_energy := label(bee_bar, localize("Next turn: %d Energy") % b.next_turn_energy(), 16, HONEY)
	next_energy.name = "NextTurnEnergy"
	next_energy.tooltip_text = localize("Base 3 · Debt -%d · Cached +%d") % [b.debt, b.bee.bank]
	var pending := label(content, localize("Base 3 · Debt -%d · Cached +%d") % [b.debt, b.bee.bank] + (" · " + localize(" · ".join(states)) if not states.is_empty() else ""), 14, MUTED)
	pending.name = "PendingEffects"
	var tools := column(bee_bar, false)
	tools.add_theme_constant_override("separation", 0)
	var piles := tag(tools, "HAND %d  ·  DRAW %d  ·  DISCARD %d" % [b.hand.size(), b.deck.size(), b.discard.size()], MUTED)
	piles.autowrap_mode = TextServer.AUTOWRAP_OFF
	button(tools, "Battle log", show_log)
	button(bee_bar, "END TURN  [E]", end_turn, b.popup_open or not b.choice.is_empty(), true)
	preview_label = label(content, "1–0 select · Enter play · E end turn · D deck · A draw · S discard · M map", 16, TEXT)
	preview_label.name = "CardPreview"
	preview_label.custom_minimum_size.y = 56
	preview_label.theme_type_variation = "CombatRule"
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "CombatHand"
	hand_scroll.custom_minimum_size.y = 284 if compact else 326
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
	for i in range(b.hand.size()):
		var card: Dictionary = b.hand[i]
		var view = card_view(cards, card, play_card.bind(int(card.id)), not b.can_play(card))
		if i < 10:
			var shortcut_badge := Label.new()
			shortcut_badge.text = "[%s]" % str((i + 1) % 10)
			shortcut_badge.add_theme_font_override("font", mono)
			shortcut_badge.add_theme_font_size_override("font_size", 13)
			shortcut_badge.add_theme_color_override("font_color", HONEY)
			shortcut_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			shortcut_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var top_row := view.get_node("Margin/Body/Top")
			top_row.add_child(shortcut_badge)
			top_row.move_child(shortcut_badge, 1)
			view.tooltip_text = "[%s]  " % str((i + 1) % 10) + view.tooltip_text
		combat_feedback.cards[int(card.id)] = view
		view.custom_minimum_size = Vector2(222, 256 if compact else 302)
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
				var highlight := func(): monitor_heading.add_theme_color_override("font_color", TEXT)
				var unhighlight := func(): monitor_heading.add_theme_color_override("font_color", HONEY)
				view.mouse_entered.connect(highlight)
				view.focus_entered.connect(highlight)
				view.mouse_exited.connect(unhighlight)
				view.focus_exited.connect(unhighlight)
			view.tooltip_text += "\n" + details.strip_edges()
		if not b.can_play(card):
			var reason: String = b.unplayable_reason(card)
			view.get_node("Margin/Body/LockNotice").text = localize(reason)
			view.tooltip_text += "\n" + localize(reason)
		view.focus_mode = Control.FOCUS_ALL
		view.set_meta("preview_card", card)
		view.mouse_entered.connect(show_card_preview.bind(card))
		view.focus_entered.connect(show_card_preview.bind(card))
		view.mouse_exited.connect(clear_card_preview.bind(int(card.id), view))
		view.focus_exited.connect(clear_card_preview.bind(int(card.id), view))
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

func show_combat_help(value: String) -> void:
	if is_instance_valid(preview_label): preview_label.text = value

func clear_combat_help() -> void:
	preview_card_id = -1
	var trigger := find_child("BugTrigger", true, false) as Label
	if trigger: trigger.add_theme_color_override("font_color", TEXT)
	show_combat_help(localize("1–0 select · Enter play · E end turn · D deck · A draw · S discard · M map"))

func clear_card_preview(id: int, view: Control) -> void:
	if view.has_focus(): return
	if preview_card_id == id:
		clear_combat_help()
		var focused := get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and focused.has_meta("preview_card"):
			show_card_preview(focused.get_meta("preview_card"))

func show_card_preview(card: Dictionary) -> void:
	if run.screen != "battle" or not is_instance_valid(preview_label): return
	preview_card_id = int(card.id)
	var b := run.battle
	var trigger := find_child("BugTrigger", true, false) as Label
	if trigger: trigger.add_theme_color_override("font_color", TEXT)
	var reason: String = b.unplayable_reason(card)
	if not reason.is_empty():
		show_combat_help(localize(card.name) + " · " + localize(reason))
		return
	var prediction: Dictionary = b.preview_card(card)
	if trigger: trigger.add_theme_color_override("font_color", HONEY if prediction.triggers_bug else TEXT)
	var details: Array[String] = [localize("Cost %d Energy") % card.cost]
	for item in [[prediction.damage, "Deal %d damage"], [prediction.block, "Gain %d Block"], [card.get("draw", 0), "Draw %d"], [card.get("energy", 0), "Gain %d Energy"], [card.get("heal", 0), "Repair %d HP"], [card.get("selfDamage", 0), "Lose %d HP"], [prediction.nectar_spent, "Spend %d Nectar"]]:
		if item[0] > 0: details.append(localize(item[1]) % item[0])
	var summary := localize(card.name) + " · " + " · ".join(details)
	if prediction.triggers_bug:
		var consequence: Dictionary = prediction.bug_consequences
		var gains: Array[String] = []
		var costs: Array[String] = []
		for item in [["damage", "Deal %d damage"], ["block", "Gain %d Block"], ["draw", "Draw %d"], ["energy", "Gain %d Energy"]]:
			if consequence[item[0]] > 0: gains.append(localize(item[1]) % consequence[item[0]])
		for item in [["hp_loss", "Lose %d HP"], ["debt", "Next turn -%d Energy"], ["enemy_strength", "Enemy +%d Strength"]]:
			if consequence[item[0]] > 0: costs.append(localize(item[1]) % consequence[item[0]])
		summary += "\n" + localize("GAIN") + ": " + " · ".join(gains) + " / " + localize("COST") + ": " + " · ".join(costs)
	summary += " · " + localize("Next turn: %d Energy") % prediction.next_turn_energy
	show_combat_help(summary)

func end_turn() -> void:
	if run.screen != "battle" or run.battle == null: return
	var battle := run.battle
	if battle.popup_open or not battle.choice.is_empty() or battle.hp <= 0 or battle.enemy_hp <= 0: return
	combat_feedback.prepare_enemy_attack()
	run.end_turn()


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

func card_view(parent: Node, card: Dictionary, action: Callable, disabled := false, inspect := false) -> Button:
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
	view.configure(card, localize, action, disabled, inspect)
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

func modal(title_text: String, wide := false, close_action: Callable = Callable()) -> VBoxContainer:
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
	var header := row(shell, 8)
	tag(header, "BUGBOUND  /  SYSTEM WINDOW", HONEY)
	if close_action.is_valid():
		var close := button(header, "×", close_action)
		close.name = "ModalClose"
		close.tooltip_text = localize("Close")
		close.custom_minimum_size = Vector2(44, 44)
		close.add_theme_font_size_override("font_size", 24)
		close.grab_focus()
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
	var body := modal("Card Library" if library else "Current deck", true, render)
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	for card in (Catalog.data.cards if library else run.cards): card_view(grid, card, func(): pass, false, true)

func show_card_pile(title_text: String, cards: Array) -> void:
	if run.screen != "battle" or run.battle == null: return
	var body := modal(title_text, true, render)
	if cards.is_empty():
		label(body, "No cards here.", 20, MUTED)
		return
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	for card in cards: card_view(grid, card, func(): pass, false, true)

func show_route_preview() -> void:
	if run.screen == "menu": return
	var body := modal("Route preview  [M]", true, render)
	tag(body, "ACT 1  /  DESKTOP", MINT)
	label(body, "Current path %02d / 11" % mini(11, run.tier + 1), 18, HONEY)
	for tier in range(11):
		var nodes: Array = run.map.filter(func(node): return int(node.tier) == tier and (node.kind != "secret" or run.flags.secretUnlocked))
		if nodes.is_empty(): continue
		var line := row(body, 10)
		var path_tag := tag(line, "PATH %02d" % (tier + 1), HONEY if tier == run.tier else MUTED)
		path_tag.custom_minimum_size.x = 92
		var names: Array[String] = []
		for node in nodes:
			var marker := " ✓" if node.id in run.completed else (" ←" if tier == run.tier else "")
			names.append(localize(ROUTE_DETAILS.title_text(node)) + marker)
		label(line, "  /  ".join(names), 16, TEXT if tier >= run.tier else MUTED)

func focus_hand_shortcut(index: int) -> void:
	if run.screen != "battle" or run.battle == null or is_instance_valid(overlay): return
	if index < 0 or index >= run.battle.hand.size(): return
	var card: Dictionary = run.battle.hand[index]
	show_card_preview(card)
	var view = combat_feedback.cards.get(int(card.id))
	if is_instance_valid(view) and not view.disabled:
		view.grab_focus()

func hand_shortcut_index(keycode: Key) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
		KEY_0: return 9
		_: return -1

func show_log() -> void:
	var body := modal("Battle log")
	button(body, "Close", render).grab_focus()
	for entry in run.battle.log: label(body, entry, 17, MUTED)

func _unhandled_key_input(event: InputEvent) -> void:
	if not content.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(overlay):
				if menu_deck_open: close_starting_deck()
				else: render()
			elif run.screen != "menu": pause_menu()
			return
		if is_instance_valid(overlay): return
		var hand_index := hand_shortcut_index(event.keycode)
		if hand_index >= 0 and run.screen == "battle":
			focus_hand_shortcut(hand_index)
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_E:
				if run.screen == "battle":
					end_turn()
					get_viewport().set_input_as_handled()
			KEY_D:
				if run.screen != "menu":
					collection(false)
					get_viewport().set_input_as_handled()
			KEY_A:
				if run.screen == "battle":
					show_card_pile("Draw pile  [A]", run.battle.deck)
					get_viewport().set_input_as_handled()
			KEY_S:
				if run.screen == "battle":
					show_card_pile("Discard pile  [S]", run.battle.discard)
					get_viewport().set_input_as_handled()
			KEY_M:
				if run.screen != "menu":
					show_route_preview()
					get_viewport().set_input_as_handled()

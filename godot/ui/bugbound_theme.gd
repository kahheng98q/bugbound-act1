extends RefCounted
## Shared BUGBOUND terminal palette and geometry. Accents carry semantic meaning.
const INK := Color("070c19")
const SURFACE := Color("101a2c")
const LINE := Color("34516a")
const TEXT := Color("e5f5fa")
const MUTED := Color("9fb5c9")
const CYAN := Color("50e5ee")
const MAGENTA := Color("ff70bd")
const ACID := Color("c4f76a")
const DANGER := Color("ff786f")
const SECONDARY_TEXT := MUTED
const MUTED_TEXT := Color("7f95ab")
const SURFACE_ELEVATED := Color("18263b")
const SURFACE_SELECTED := Color("153342")
const SURFACE_HOVER := Color("1d354b")
const SURFACE_DISABLED := Color("111725")
const CARD_HOVER := Color("1b3046")
const CARD_DISABLED := Color("141c29")
# Semantic tokens are independent of the legacy component aliases.
const HP := DANGER
const BLOCK := CYAN
const ENERGY := ACID
const ATTACK := MAGENTA
const SKILL := CYAN
const STATUS := ACID
const GAP_SMALL := 6
const GAP := 12
const PANEL_PADDING := 12
const SECTION_SPACING := 24
const FONT_SCREEN_TITLE := 27
const FONT_SECTION_TITLE := 20
const FONT_UI := 18
const FONT_HELP := 14
const FONT_STATUS := 22
const RADIUS := 3
const TERMINAL_FONT = preload("res://ui/themes/terminal_font.tres")

static func panel_style(fill: Color, border: Color, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(RADIUS)
	style.corner_radius_top_right = 9
	style.set_content_margin_all(padding)
	style.shadow_color = Color(border, 0.12)
	style.shadow_size = 4
	return style

static func decorate(frame: Control, accent: Color) -> void:
	# Static packet marks stay off text and never intercept input or flicker.
	var marks := Control.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(marks)
	marks.draw.connect(func():
		var w := marks.size.x
		var h := marks.size.y
		marks.draw_line(Vector2(10, 2), Vector2(minf(42, w - 10), 2), accent, 2)
		for i in range(3):
			marks.draw_rect(Rect2(w - 30 + i * 7, h - 4, 4, 2), Color(accent, 0.65))
	)
	marks.resized.connect(marks.queue_redraw)

static func populate_theme(result: Theme) -> void:
	# Existing control defaults retain their metrics; new roles are opt-in.
	var colors := {
		"background": INK, "surface": SURFACE, "elevated": SURFACE_ELEVATED,
		"selected": SURFACE_SELECTED, "border": LINE, "cyan": CYAN,
		"magenta": MAGENTA, "danger": DANGER, "hp": HP, "block": BLOCK,
		"energy": ENERGY, "primary_text": TEXT, "secondary_text": SECONDARY_TEXT,
		"muted_text": MUTED_TEXT, "attack": ATTACK, "skill": SKILL, "status": STATUS,
	}
	for token in colors: result.set_color(token, "Bugbound", colors[token])
	var spacing := {"small_gap": GAP_SMALL, "normal_gap": GAP,
		"panel_padding": PANEL_PADDING, "section_spacing": SECTION_SPACING}
	for token in spacing: result.set_constant(token, "Bugbound", spacing[token])
	var panels := {
		"CombatBackground": [INK, INK], "CombatPanel": [SURFACE, LINE],
		"CombatElevated": [SURFACE_ELEVATED, LINE],
		"CombatSelected": [SURFACE_SELECTED, CYAN],
		"CombatCyan": [SURFACE, CYAN], "CombatMagenta": [SURFACE, MAGENTA],
		"CombatDanger": [SURFACE, DANGER],
	}
	for role in panels:
		result.set_type_variation(role, "PanelContainer")
		var style := panel_style(panels[role][0], panels[role][1], PANEL_PADDING)
		if role == "CombatBackground":
			style.set_border_width_all(0)
			style.set_corner_radius_all(0)
			style.shadow_size = 0
		result.set_stylebox("panel", role, style)
	var typography := {
		"CombatScreenTitle": [FONT_SCREEN_TITLE, TEXT],
		"CombatSectionTitle": [FONT_SECTION_TITLE, TEXT],
		"CombatText": [FONT_UI, TEXT],
		"CombatHelp": [FONT_HELP, SECONDARY_TEXT],
		"CombatMuted": [FONT_HELP, MUTED_TEXT],
		"CombatValue": [FONT_STATUS, TEXT],
	}
	for role in typography:
		result.set_type_variation(role, "Label")
		result.set_font_size("font_size", role, typography[role][0])
		result.set_color("font_color", role, typography[role][1])
	result.set_font("font", "CombatValue", TERMINAL_FONT)
	# Meter backgrounds and fills are shared resources, not per-control copies.
	var meter_background := panel_style(INK, LINE, 0)
	for role in ["CombatHP", "CombatBlock", "CombatEnergy"]:
		var accent: Color = HP if role == "CombatHP" else (BLOCK if role == "CombatBlock" else ENERGY)
		result.set_type_variation(role, "ProgressBar")
		result.set_stylebox("background", role, meter_background)
		result.set_stylebox("fill", role, panel_style(accent, accent, 0))
		result.set_color("font_color", role, TEXT)
	for role in ["CombatRule", "CombatSecondary"]:
		result.set_type_variation(role, "Label")
		result.set_font_size("font_size", role, 16 if role == "CombatRule" else 14)
		result.set_color("font_color", role, TEXT if role == "CombatRule" else MUTED)
	result.default_font_size = FONT_UI
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_color("font_pressed_color", "Button", TEXT)
	result.set_color("font_focus_color", "Button", TEXT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fills := {"normal": SURFACE, "hover": SURFACE_HOVER, "pressed": INK, "disabled": SURFACE_DISABLED}
		result.set_stylebox(state, "Button", panel_style(fills[state], CYAN if state == "hover" else LINE, 10))
	var focus := panel_style(Color.TRANSPARENT, ACID, 0)
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_type_variation("CompactAction", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var compact_style := result.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		compact_style.content_margin_top = 3
		compact_style.content_margin_bottom = 3
		result.set_stylebox(state, "CompactAction", compact_style)
	result.set_type_variation("PrimaryAction", "Button")
	for state in ["normal", "hover", "pressed"]:
		var fills := {"normal": ACID, "hover": ACID.lightened(0.2), "pressed": ACID.darkened(0.2)}
		result.set_stylebox(state, "PrimaryAction", panel_style(fills[state], ACID, 12))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "PrimaryAction", INK)
	var primary_focus := focus.duplicate()
	primary_focus.border_color = TEXT
	result.set_stylebox("focus", "PrimaryAction", primary_focus)
	result.set_type_variation("PaperCard", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fills := {"normal": SURFACE, "hover": CARD_HOVER, "pressed": INK, "disabled": CARD_DISABLED}
		var card_style := panel_style(fills[state], ACID if state == "hover" else LINE, 0)
		card_style.set_border_width_all(2 if state == "hover" else 1)
		card_style.shadow_color = Color(CYAN, 0.15)
		card_style.shadow_size = 3
		card_style.shadow_offset = Vector2(0, 3)
		result.set_stylebox(state, "PaperCard", card_style)
	result.set_stylebox("focus", "PaperCard", focus)
	result.set_stylebox("normal", "LineEdit", panel_style(INK, LINE, 14))
	result.set_stylebox("focus", "LineEdit", panel_style(INK, ACID, 14))
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("caret_color", "LineEdit", ACID)
	result.set_stylebox("panel", "TooltipPanel", panel_style(INK, CYAN, 12))
	result.set_color("font_color", "TooltipLabel", TEXT)
	result.set_constant("separation", "VBoxContainer", GAP)
	result.set_constant("separation", "HBoxContainer", GAP)
	result.set_constant("h_separation", "GridContainer", 16)
	result.set_constant("v_separation", "GridContainer", 16)

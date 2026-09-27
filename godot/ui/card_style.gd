extends RefCounted
## Shared command-card surfaces. State changes use cheap styleboxes, not effects.
const Palette = preload("res://ui/bugbound_theme.gd")

static func accent_for(kind: String) -> Color:
	match kind:
		"attack": return Palette.ATTACK
		"power", "system", "bee": return Palette.ACID
		"curse", "bug", "error": return Palette.DANGER
		_: return Palette.SKILL

static func frame(accent: Color, state: String) -> StyleBoxFlat:
	var edge := Palette.LINE.lerp(accent, 0.15)
	var fill := Palette.SURFACE
	var width := 1
	var glow := 0.0
	match state:
		"playable": edge = Palette.LINE.lerp(accent, 0.48)
		"hover":
			edge = accent
			fill = Palette.SURFACE_ELEVATED
			glow = 0.16
		"selected", "pressed":
			edge = accent.lightened(0.32)
			fill = Palette.SURFACE_ELEVATED
			width = 2
			glow = 0.26
		"disabled":
			edge = Palette.LINE.darkened(0.22)
			fill = Palette.CARD_DISABLED
	var box := Palette.panel_style(fill, edge, 0)
	box.set_border_width_all(width)
	box.border_width_top = 3 if state in ["selected", "pressed"] else width
	box.shadow_color = Color(accent, glow)
	box.shadow_size = 6 if glow > 0 else 0
	box.shadow_offset = Vector2.ZERO
	return box

static func art_well(accent: Color) -> StyleBoxFlat:
	var box := Palette.panel_style(Palette.INK.lightened(0.045), Palette.LINE.lerp(accent, 0.18), 4)
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.shadow_size = 0
	return box

static func cost_chip(accent: Color) -> StyleBoxFlat:
	var box := Palette.panel_style(accent, accent.lightened(0.15), 0)
	box.set_corner_radius_all(3)
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.shadow_size = 0
	return box

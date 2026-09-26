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
const GAP := 12
const RADIUS := 3

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

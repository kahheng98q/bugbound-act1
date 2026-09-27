extends Control
## Read-only, segmented integrity rail. Partial cells preserve exact HP ratios.
const V = preload("res://ui/bugbound_theme.gd")
var value := 0.0:
	set(next):
		value = next
		queue_redraw()
var maximum := 1.0:
	set(next):
		maximum = next
		queue_redraw()
var accent := V.CYAN

func _init() -> void:
	custom_minimum_size = Vector2(80, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_style_box(V.panel_style(V.INK, V.LINE, 0), Rect2(Vector2.ZERO, size))
	var cells := 16
	var gap := 3.0
	var width := (size.x - 12 - gap * (cells - 1)) / cells
	var ratio := clampf(value / maxf(1.0, maximum), 0.0, 1.0)
	for i in range(cells):
		var cell := Rect2(6 + i * (width + gap), 5, width, size.y - 10)
		draw_rect(cell, V.SURFACE_ELEVATED)
		var filled := clampf(ratio * cells - i, 0.0, 1.0)
		if filled > 0:
			cell.size.x *= filled
			draw_rect(cell, accent)
			draw_line(cell.position, cell.position + Vector2(cell.size.x, 0), accent.lightened(0.3))

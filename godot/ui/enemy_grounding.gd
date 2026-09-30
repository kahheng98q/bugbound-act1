extends Control
## Soft world-space footprint below the independent actor; no gameplay state.
func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var floor_point := Vector2(size.x * 0.5, size.y * 0.90)
	draw_set_transform(floor_point, 0, Vector2(1.0, 0.20))
	for layer in range(12, 0, -1):
		draw_circle(Vector2.ZERO, size.x * (0.20 + layer * 0.009), Color(0.015, 0.022, 0.04, 0.025))
	for foot in [-0.13, 0.13]:
		for layer in range(6, 0, -1):
			draw_circle(Vector2(size.x * foot, 0), size.x * (0.045 + layer * 0.005), Color(0.008, 0.012, 0.025, 0.07))
	draw_set_transform(Vector2.ZERO)

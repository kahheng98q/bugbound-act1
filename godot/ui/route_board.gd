extends Control
## Decorative connections; locations remain native buttons.
var locations: Array = []
var current_tier := 0
var visited: Array = []

func point(node: Dictionary) -> Vector2:
	return Vector2(112 + node.tier * 224, 190 + ((node.lane - 0.5) * 190 if node.kind != "boss" else 0))

func _draw() -> void:
	for node in locations:
		for next_node in locations:
			if next_node.tier != node.tier + 1: continue
			var active: bool = node.id in visited and (next_node.id in visited or next_node.tier == current_tier)
			draw_line(point(node), point(next_node), Color("e7b94c") if active else Color("30424b"), 2, true)

extends Control
## Decorative connections; locations remain native buttons.
const TIER_WIDTH := 190
const BOARD_WIDTH := 2160
const BOARD_HEIGHT := 324
const BOARD_HEIGHT_WITH_SECRET := 460
const NODE_SIZE := Vector2(164, 124)
const NODE_OFFSET := NODE_SIZE * 0.5
const TIER_LABEL_Y := 290
const TIER_LABEL_Y_WITH_SECRET := 430

var locations: Array = []
var current_tier := 0
var visited: Array = []

func point(node: Dictionary) -> Vector2:
	return Vector2(90 + node.tier * TIER_WIDTH, 82 + node.lane * 136 if node.kind != "boss" else 150)

func _draw() -> void:
	for node in locations:
		for next_node in locations:
			if next_node.tier != node.tier + 1: continue
			var active: bool = node.id in visited and (next_node.id in visited or next_node.tier == current_tier)
			draw_line(point(node), point(next_node), Color("e7b94c") if active else Color("30424b"), 2, true)

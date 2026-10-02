extends Control
## Decorative connections; locations remain native buttons.
const BugboundTheme = preload("res://ui/bugbound_theme.gd")
const TIER_WIDTH := 190
const BOARD_WIDTH := 2160
const BOARD_HEIGHT := 310
const BOARD_HEIGHT_WITH_SECRET := 460
const NODE_SIZE := Vector2(164, 124)
const NODE_OFFSET := NODE_SIZE * 0.5
const TIER_LABEL_Y := 282
const TIER_LABEL_Y_WITH_SECRET := 430

var locations: Array = []
var current_tier := 0
var visited: Array = []
## Optional marker for the last completed node; kept independent from routing state.
var current_id: String = ""

func point(node: Dictionary) -> Vector2:
	return Vector2(90 + node.tier * TIER_WIDTH, 82 + node.lane * 136 if node.kind != "boss" else 150)

func _draw() -> void:
	var board_height := BOARD_HEIGHT_WITH_SECRET if size.y > BOARD_HEIGHT + 20 else BOARD_HEIGHT
	# A restrained navy field gives the route depth without competing with node cards.
	draw_rect(Rect2(0, 0, BOARD_WIDTH, board_height), BugboundTheme.INK)
	for x in range(0, BOARD_WIDTH + 1, 32):
		draw_line(Vector2(x, 0), Vector2(x, board_height), Color(BugboundTheme.LINE, 0.10), 1.0)
	for y in range(0, board_height + 1, 32):
		draw_line(Vector2(0, y), Vector2(BOARD_WIDTH, y), Color(BugboundTheme.LINE, 0.10), 1.0)
	# Tier rails and a quiet scanner band keep the current route leg legible.
	for tier in range(0, int(float(BOARD_WIDTH) / TIER_WIDTH) + 1):
		var rail_x := 90.0 + tier * TIER_WIDTH
		draw_line(Vector2(rail_x, 20), Vector2(rail_x, board_height - 34), Color(BugboundTheme.CYAN, 0.08), 1.0)
	var scanner_x := 90.0 + current_tier * TIER_WIDTH
	draw_rect(Rect2(scanner_x - TIER_WIDTH * 0.5, 18, TIER_WIDTH, board_height - 52), Color(BugboundTheme.CYAN, 0.035))
	draw_line(Vector2(scanner_x - TIER_WIDTH * 0.5, TIER_LABEL_Y - 2), Vector2(scanner_x + TIER_WIDTH * 0.5, TIER_LABEL_Y - 2), Color(BugboundTheme.CYAN, 0.55), 2.0)
	for node in locations:
		for next_node in locations:
			if next_node.tier != node.tier + 1: continue
			var source := point(node)
			var target := point(next_node)
			var active: bool = node.id in visited and (next_node.id in visited or next_node.tier == current_tier)
			var completed: bool = node.id in visited and next_node.id in visited
			var channel_color := BugboundTheme.CYAN if completed else (BugboundTheme.ACID if active else Color(BugboundTheme.MUTED_TEXT, 0.65))
			var left := source + Vector2(NODE_SIZE.x * 0.5, 0)
			var right := target - Vector2(NODE_SIZE.x * 0.5, 0)
			var bend_x := (left.x + right.x) * 0.5
			# Route around card bodies so labels and controls stay visually clean.
			var points := PackedVector2Array([left, Vector2(bend_x, left.y), Vector2(bend_x, right.y), right])
			for segment in range(points.size() - 1):
				draw_line(points[segment], points[segment + 1], channel_color, 3.0 if active else 2.0, true)
			if active:
				draw_circle(right, 3.0, channel_color)
	if not current_id.is_empty():
		for node in locations:
			if node.id == current_id:
				var bounds := Rect2(point(node) - NODE_OFFSET - Vector2(3, 3), NODE_SIZE + Vector2(6, 6))
				draw_rect(bounds, Color(BugboundTheme.ACID, 0.45), false, 2.0)
				break

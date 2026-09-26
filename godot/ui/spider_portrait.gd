extends TextureRect
## Lightweight procedural Spider Debugger portrait with the same feedback interface as BeePortrait.
var idle_time := 0.0
var attack_time := -1.0

func _init() -> void:
	texture = null
	queue_redraw()

func _process(delta: float) -> void:
	idle_time += delta
	if attack_time >= 0.0:
		attack_time += delta
		if attack_time >= 0.45: attack_time = -1.0
	queue_redraw()

func attack() -> void:
	attack_time = 0.0
	queue_redraw()

func restore_pose(pose: Vector2) -> void:
	idle_time = pose.x
	attack_time = pose.y
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var bob := sin(idle_time * 3.0) * 2.0
	var lunge := 10.0 * (1.0 - minf(1.0, attack_time / 0.25)) if attack_time >= 0.0 else 0.0
	center += Vector2(lunge, bob)
	var ink := Color("101b22")
	var body := Color("6f78a8")
	var accent := Color("75cbb0")
	var web := Color(0.75, 0.85, 0.88, 0.55)
	for radius: float in [0.42, 0.31, 0.20]:
		for i in range(8):
			var a := TAU * float(i) / 8.0
			var p1: Vector2 = center + Vector2(cos(a), sin(a)) * minf(size.x, size.y) * radius
			var p2: Vector2 = center + Vector2(cos(a + TAU / 8.0), sin(a + TAU / 8.0)) * minf(size.x, size.y) * radius
			draw_line(p1, p2, web, 1.5)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		draw_line(center, center + Vector2(cos(a), sin(a)) * minf(size.x, size.y) * 0.44, web, 1.2)
	for side in [-1.0, 1.0]:
		for row in range(4):
			var y := -22.0 + row * 14.0
			var joint := center + Vector2(side * 22.0, y)
			var tip := center + Vector2(side * (43.0 + row * 2.0), y + (-10.0 if row < 2 else 10.0))
			draw_line(center + Vector2(side * 11.0, y * 0.55), joint, ink, 5.0, true)
			draw_line(joint, tip, ink, 5.0, true)
	draw_circle(center + Vector2(0, 11), 23, ink)
	draw_circle(center + Vector2(0, 11), 18, body)
	draw_circle(center + Vector2(0, -15), 17, ink)
	draw_circle(center + Vector2(0, -15), 13, body)
	for x in [-7.0, 0.0, 7.0]:
		draw_circle(center + Vector2(x, -18), 2.6, accent)
	draw_line(center + Vector2(-10, 7), center + Vector2(10, 15), accent, 3.0, true)
	draw_line(center + Vector2(-10, 15), center + Vector2(10, 7), accent, 3.0, true)

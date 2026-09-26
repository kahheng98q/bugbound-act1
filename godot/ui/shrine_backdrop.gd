extends Control
## Original Blender artwork, presentation only. No input capture or gameplay RNG.
const PLATES: Array[Texture2D] = [
	preload("res://assets/environments/corrupted-shrine/background.png"),
	preload("res://assets/environments/corrupted-shrine/midground.png"),
	preload("res://assets/environments/corrupted-shrine/foreground.png"),
]
@export var motion_enabled := true
var pointer := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	resized.connect(queue_redraw)
	queue_redraw()

func _process(delta: float) -> void:
	var target := Vector2.ZERO
	if motion_enabled and size.x > 0.0 and size.y > 0.0:
		var mouse := get_local_mouse_position()
		if Rect2(Vector2.ZERO, size).has_point(mouse):
			target = (mouse / size - Vector2(0.5, 0.5)) * 2.0
	var next := pointer.lerp(target, 1.0 - exp(-delta * 4.0))
	if next.distance_squared_to(pointer) > 0.000001:
		pointer = next
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	# Cover without stretching; overscan exceeds every layer's motion at supported sizes.
	var source := Vector2(1440, 900)
	var scale_factor := maxf(size.x / source.x, size.y / source.y) * 1.04
	var dimensions := source * scale_factor
	for index in range(PLATES.size()):
		var travel: float = [1.0, 3.0, 5.0][index] if motion_enabled else 0.0
		var origin := (size - dimensions) * 0.5 + pointer * travel
		draw_texture_rect(PLATES[index], Rect2(origin, dimensions), false)
	# Keep the environment visible but subordinate to cards, health and intent.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.028, 0.05, 0.25))
	# Quiet the controls/card zone without altering any existing UI layout.
	var top := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 90), Vector2(0, 90)])
	draw_polygon(top, PackedColorArray([Color(0.025,0.045,0.06,0.8), Color(0.025,0.045,0.06,0.8), Color(0.025,0.045,0.06,0), Color(0.025,0.045,0.06,0)]))
	var bottom := PackedVector2Array([Vector2(0,size.y*.38),Vector2(size.x,size.y*.38),size,Vector2(0,size.y)])
	draw_polygon(bottom, PackedColorArray([Color(0.025,0.045,0.06,0.2),Color(0.025,0.045,0.06,0.2),Color(0.025,0.045,0.06,0.94),Color(0.025,0.045,0.06,0.94)]))
